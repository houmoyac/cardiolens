#!/usr/bin/env python3
"""Trains the atrial fibrillation screening model from PTB-XL.

Run with: uv run --group train python scripts/train_afib_model.py

IMPORTANT LIMITATION — read before trusting the printed metrics:
PTB-XL has only 48 records with a 100%-confidence AFIB label (it's a
general-population dataset, not an arrhythmia-focused one). The reported
cross-validated AUC/sensitivity/specificity below are computed on this
small, "confirmed-diagnosis-only" sample — real-world performance on
ambiguous or paroxysmal cases is almost certainly lower. This is a
proof-of-concept signal that RR-irregularity features separate confirmed
AFIB from confirmed normal sinus rhythm (consistent with the published
HRV/AFib-detection literature), not a validated clinical-grade model. See
ARCHITECTURE.md for how this is presented to the physician (explicit
confidence score, "à vérifier" — never as a diagnosis).
"""

from __future__ import annotations

import random
from pathlib import Path

import numpy as np
import wfdb
from joblib import dump
from numpy.typing import NDArray
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import confusion_matrix, roc_auc_score
from sklearn.model_selection import StratifiedKFold
from sklearn.preprocessing import StandardScaler

from cardiolens.afib_features import HrvFeatureError, extract_hrv_features, features_to_vector

PTBXL_VERSION = "1.0.3"
MODEL_PATH = Path(__file__).parent.parent / "src" / "cardiolens" / "models" / "afib_model.joblib"
N_NORM_SAMPLES = 150
RANDOM_SEED = 42


def _fetch_ptbxl_metadata(tmp_dir: Path) -> tuple[list[dict], list[dict]]:
    import csv
    import urllib.request
    from ast import literal_eval

    csv_path = tmp_dir / "ptbxl_database.csv"
    if not csv_path.exists():
        url = f"https://physionet.org/files/ptb-xl/{PTBXL_VERSION}/ptbxl_database.csv"
        urllib.request.urlretrieve(url, csv_path)  # noqa: S310 — fixed, trusted PhysioNet URL

    with csv_path.open() as f:
        rows = list(csv.DictReader(f))

    afib = [r for r in rows if literal_eval(r["scp_codes"] or "{}").get("AFIB", 0) == 100.0]
    norm = [
        r
        for r in rows
        if literal_eval(r["scp_codes"] or "{}").get("NORM", 0) >= 90
        and not r["baseline_drift"]
        and not r["static_noise"]
        and not r["burst_noise"]
    ]
    random.seed(RANDOM_SEED)
    norm_sample = random.sample(norm, N_NORM_SAMPLES)
    return afib, norm_sample


def _fetch_lead_ii(filename_hr: str) -> tuple[NDArray[np.float64], int]:
    folder, name = filename_hr.rsplit("/", 1)
    record = wfdb.rdrecord(name, pn_dir=f"ptb-xl/{PTBXL_VERSION}/{folder}")
    return record.p_signal[:, record.sig_name.index("II")], record.fs


def build_dataset(tmp_dir: Path) -> tuple[np.ndarray, np.ndarray]:
    afib_records, norm_records = _fetch_ptbxl_metadata(tmp_dir)
    print(f"AFIB records: {len(afib_records)}, NORM records: {len(norm_records)}")

    features: list[np.ndarray] = []
    labels: list[int] = []
    for records, label in [(afib_records, 1), (norm_records, 0)]:
        for r in records:
            try:
                signal, fs = _fetch_lead_ii(r["filename_hr"])
                feats = extract_hrv_features(signal, fs)
            except (HrvFeatureError, ValueError, RuntimeError) as exc:
                print(f"  skipped ecg_id={r['ecg_id']}: {exc}")
                continue
            features.append(features_to_vector(feats))
            labels.append(label)

    return np.array(features), np.array(labels)


def evaluate_cross_validated(X: np.ndarray, y: np.ndarray) -> None:
    skf = StratifiedKFold(n_splits=5, shuffle=True, random_state=RANDOM_SEED)
    aucs, sens, spec = [], [], []

    for train_idx, test_idx in skf.split(X, y):
        scaler = StandardScaler().fit(X[train_idx])
        clf = LogisticRegression(class_weight="balanced", max_iter=1000)
        clf.fit(scaler.transform(X[train_idx]), y[train_idx])

        y_prob = clf.predict_proba(scaler.transform(X[test_idx]))[:, 1]
        y_pred = (y_prob >= 0.5).astype(int)
        tn, fp, fn, tp = confusion_matrix(y[test_idx], y_pred, labels=[0, 1]).ravel()

        aucs.append(roc_auc_score(y[test_idx], y_prob))
        sens.append(tp / (tp + fn) if (tp + fn) > 0 else float("nan"))
        spec.append(tn / (tn + fp) if (tn + fp) > 0 else float("nan"))

    print(f"Cross-validated AUC:         {np.mean(aucs):.3f} (+/- {np.std(aucs):.3f})")
    print(f"Cross-validated sensitivity: {np.mean(sens):.3f}")
    print(f"Cross-validated specificity: {np.mean(spec):.3f}")
    print(
        "\n⚠ Small sample (see module docstring): treat these numbers as "
        "directional, not a validated clinical performance claim."
    )


def train_final_model(X: np.ndarray, y: np.ndarray) -> None:
    scaler = StandardScaler().fit(X)
    clf = LogisticRegression(class_weight="balanced", max_iter=1000)
    clf.fit(scaler.transform(X), y)

    MODEL_PATH.parent.mkdir(parents=True, exist_ok=True)
    dump({"scaler": scaler, "classifier": clf, "trained_on_n": len(y)}, MODEL_PATH)
    print(f"Saved model to {MODEL_PATH}")


if __name__ == "__main__":
    import tempfile

    with tempfile.TemporaryDirectory() as tmp:
        X, y = build_dataset(Path(tmp))

    print(f"\nDataset: {len(y)} examples, {y.sum()} AFIB, {len(y) - y.sum()} normal\n")
    evaluate_cross_validated(X, y)
    train_final_model(X, y)
