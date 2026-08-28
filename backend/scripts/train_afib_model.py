#!/usr/bin/env python3
"""Trains the atrial fibrillation screening model from the MIT-BIH Atrial
Fibrillation Database (AFDB, PhysioNet, Open Data Commons Attribution
License v1.0 — physionet.org/content/afdb/1.0.0/).

Run with: uv run --group train python scripts/train_afib_model.py

Why AFDB instead of PTB-XL: PTB-XL (used in an earlier version of this
script) only has 48 confirmed-AFIB records total — too few for a
trustworthy estimate of real-world performance. AFDB has 25 real patients,
each with ~10 hours of continuous ECG and rhythm annotated over time
(AFIB vs. normal sinus vs. other), giving far more independent examples.

METHODOLOGY NOTE — read before trusting the printed metrics:
Windows from the same patient are highly correlated (same physiology,
same recording conditions). Evaluating with a random window-level split
would leak patient identity between train and test and overstate
performance. This script splits by PATIENT (record) instead — each fold's
test set is entirely held-out patients the model never saw in training,
which is the methodologically honest way to estimate real-world
generalization. Still a modest sample (25 patients): treat the reported
numbers as a solid proof-of-concept signal, not a clinical validation.
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
import wfdb
from joblib import dump
from numpy.typing import NDArray
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import confusion_matrix, roc_auc_score
from sklearn.model_selection import GroupKFold
from sklearn.preprocessing import StandardScaler

from cardiolens.afib_features import HrvFeatureError, extract_hrv_features, features_to_vector

AFDB_VERSION = "1.0.0"
MODEL_PATH = Path(__file__).parent.parent / "src" / "cardiolens" / "models" / "afib_model.joblib"
WINDOW_SECONDS = 30
MAX_WINDOWS_PER_SEGMENT = 15  # caps how much one very long segment can dominate
RELEVANT_LABELS = {"(N": 0, "(AFIB": 1}  # ignore other rhythms (AFL, J, ...): not our target
RANDOM_SEED = 42


def _record_ids() -> list[str]:
    import urllib.request

    url = f"https://physionet.org/files/afdb/{AFDB_VERSION}/RECORDS"
    with urllib.request.urlopen(url) as response:  # noqa: S310 — fixed, trusted PhysioNet URL
        return [line.decode().strip() for line in response if line.strip()]


def _windows_for_record(
    record_id: str,
) -> list[tuple[NDArray[np.float64], int, int]]:
    """Returns (signal_window, sampling_rate, label) for every clean,
    single-rhythm window extractable from one AFDB record."""
    try:
        record = wfdb.rdrecord(record_id, pn_dir=f"afdb/{AFDB_VERSION}")
        ann = wfdb.rdann(record_id, "atr", pn_dir=f"afdb/{AFDB_VERSION}")
    except Exception as exc:  # noqa: BLE001 — some AFDB records have no signal file
        print(f"  skipping record {record_id}: {exc}")
        return []

    signal = record.p_signal[:, 0]
    fs = record.fs
    window_len = WINDOW_SECONDS * fs

    boundaries = list(ann.sample) + [len(signal)]
    windows: list[tuple[NDArray[np.float64], int, int]] = []

    for i, note in enumerate(ann.aux_note):
        if note not in RELEVANT_LABELS:
            continue
        label = RELEVANT_LABELS[note]
        start, end = boundaries[i], boundaries[i + 1]

        n_windows = min((end - start) // window_len, MAX_WINDOWS_PER_SEGMENT)
        for w in range(n_windows):
            w_start = start + w * window_len
            windows.append((signal[w_start : w_start + window_len], fs, label))

    return windows


def build_dataset() -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    features: list[np.ndarray] = []
    labels: list[int] = []
    groups: list[str] = []  # record_id — used for patient-level splitting

    for record_id in _record_ids():
        windows = _windows_for_record(record_id)
        n_ok = 0
        for signal, fs, label in windows:
            try:
                feats = extract_hrv_features(signal, fs)
            except HrvFeatureError:
                continue
            features.append(features_to_vector(feats))
            labels.append(label)
            groups.append(record_id)
            n_ok += 1
        print(f"  record {record_id}: {n_ok} usable windows / {len(windows)} extracted")

    return np.array(features), np.array(labels), np.array(groups)


def evaluate_patient_level_cv(X: np.ndarray, y: np.ndarray, groups: np.ndarray) -> None:
    n_patients = len(set(groups))
    n_splits = min(5, n_patients)
    gkf = GroupKFold(n_splits=n_splits)
    aucs, sens, spec = [], [], []

    for train_idx, test_idx in gkf.split(X, y, groups):
        scaler = StandardScaler().fit(X[train_idx])
        clf = LogisticRegression(class_weight="balanced", max_iter=1000)
        clf.fit(scaler.transform(X[train_idx]), y[train_idx])

        y_prob = clf.predict_proba(scaler.transform(X[test_idx]))[:, 1]
        y_pred = (y_prob >= 0.5).astype(int)
        tn, fp, fn, tp = confusion_matrix(y[test_idx], y_pred, labels=[0, 1]).ravel()

        aucs.append(roc_auc_score(y[test_idx], y_prob))
        sens.append(tp / (tp + fn) if (tp + fn) > 0 else float("nan"))
        spec.append(tn / (tn + fp) if (tn + fp) > 0 else float("nan"))

    print(
        f"\nPatient-level cross-validated AUC:         "
        f"{np.mean(aucs):.3f} (+/- {np.std(aucs):.3f})"
    )
    print(f"Patient-level cross-validated sensitivity: {np.mean(sens):.3f}")
    print(f"Patient-level cross-validated specificity: {np.mean(spec):.3f}")
    print(
        "\n(Held-out patients in every fold — see module docstring for why "
        "this matters more than the raw score.)"
    )


def train_final_model(X: np.ndarray, y: np.ndarray) -> None:
    scaler = StandardScaler().fit(X)
    clf = LogisticRegression(class_weight="balanced", max_iter=1000)
    clf.fit(scaler.transform(X), y)

    MODEL_PATH.parent.mkdir(parents=True, exist_ok=True)
    dump({"scaler": scaler, "classifier": clf, "trained_on_n": len(y)}, MODEL_PATH)
    print(f"\nSaved model to {MODEL_PATH}")


if __name__ == "__main__":
    print("Fetching AFDB and extracting windows (this takes a few minutes)...")
    X, y, groups = build_dataset()

    print(
        f"\nDataset: {len(y)} windows from {len(set(groups))} patients, "
        f"{y.sum()} AFIB, {len(y) - y.sum()} normal\n"
    )
    evaluate_patient_level_cv(X, y, groups)
    train_final_model(X, y)
