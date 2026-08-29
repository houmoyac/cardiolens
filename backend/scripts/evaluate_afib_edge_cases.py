#!/usr/bin/env python3
"""Evaluates the AFib model specifically on windows near a rhythm
TRANSITION versus windows well within a STABLE, unchanging segment — a
real, data-grounded proxy for paroxysmal-like ambiguity.

Why this proxy, not a "paroxysmal AFib" dataset: no such labeled dataset
is available under a license this project can use (see ARCHITECTURE.md on
why e-cardiogram.com was rejected). AFDB's multi-hour continuous
recordings DO contain genuine within-patient N<->AFIB transitions, though
— the segment's first and last extracted windows (closest in time to a
rhythm change) are the ones most likely to contain transitional beats,
which is exactly the kind of ambiguity a paroxysmal episode's onset/offset
would produce. This is not equivalent to a real paroxysmal-AFib
validation, but it is a genuine, honestly-labeled edge case the model has
never been separately checked against before.

Uses the same patient-level GroupKFold protocol as train_afib_model.py:
each fold evaluates only on held-out patients the fold's model never
trained on, split into "transition" vs. "stable" windows for reporting.

Run with: uv run --group train python scripts/evaluate_afib_edge_cases.py
"""

from __future__ import annotations

import numpy as np
import wfdb
from numpy.typing import NDArray
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import roc_auc_score
from sklearn.model_selection import GroupKFold
from sklearn.preprocessing import StandardScaler

from cardiolens.afib_features import HrvFeatureError, extract_hrv_features, features_to_vector

AFDB_VERSION = "1.0.0"
WINDOW_SECONDS = 30
MAX_WINDOWS_PER_SEGMENT = 15
RELEVANT_LABELS = {"(N": 0, "(AFIB": 1}
RANDOM_SEED = 42


def _record_ids() -> list[str]:
    import urllib.request

    url = f"https://physionet.org/files/afdb/{AFDB_VERSION}/RECORDS"
    with urllib.request.urlopen(url) as response:  # noqa: S310 — fixed, trusted PhysioNet URL
        return [line.decode().strip() for line in response if line.strip()]


def _windows_for_record(
    record_id: str,
) -> list[tuple[NDArray[np.float64], int, int, bool]]:
    """Same extraction as train_afib_model.py, plus a `near_transition`
    flag: True for a segment's first or last extracted window (adjacent in
    time to a different-labeled segment), False for windows strictly
    within a stable run."""
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
    windows: list[tuple[NDArray[np.float64], int, int, bool]] = []

    for i, note in enumerate(ann.aux_note):
        if note not in RELEVANT_LABELS:
            continue
        label = RELEVANT_LABELS[note]
        start, end = boundaries[i], boundaries[i + 1]

        n_windows = min((end - start) // window_len, MAX_WINDOWS_PER_SEGMENT)
        for w in range(n_windows):
            near_transition = n_windows > 1 and (w == 0 or w == n_windows - 1)
            w_start = start + w * window_len
            windows.append(
                (signal[w_start : w_start + window_len], fs, label, near_transition)
            )

    return windows


def build_dataset() -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    features: list[np.ndarray] = []
    labels: list[int] = []
    groups: list[str] = []
    near_transition: list[bool] = []

    for record_id in _record_ids():
        for signal, fs, label, transition in _windows_for_record(record_id):
            try:
                feats = extract_hrv_features(signal, fs)
            except HrvFeatureError:
                continue
            features.append(features_to_vector(feats))
            labels.append(label)
            groups.append(record_id)
            near_transition.append(transition)

    return np.array(features), np.array(labels), np.array(groups), np.array(near_transition)


def _report(y_true: np.ndarray, y_pred: np.ndarray, y_prob: np.ndarray, name: str) -> None:
    if len(y_true) == 0 or len(set(y_true.tolist())) < 2:
        print(f"  {name}: not enough windows/classes to score ({len(y_true)} windows)")
        return
    accuracy = float(np.mean(y_true == y_pred))
    auc = roc_auc_score(y_true, y_prob)
    print(f"  {name}: n={len(y_true)}, accuracy={accuracy:.3f}, AUC={auc:.3f}")


def main() -> None:
    print("Fetching AFDB and extracting windows (this takes a few minutes)...")
    X, y, groups, near_transition = build_dataset()
    print(
        f"\nDataset: {len(y)} windows from {len(set(groups))} patients "
        f"({int(near_transition.sum())} near a rhythm transition, "
        f"{int((~near_transition).sum())} in a stable run)\n"
    )

    n_splits = min(5, len(set(groups)))
    gkf = GroupKFold(n_splits=n_splits)

    all_true_transition: list[int] = []
    all_pred_transition: list[int] = []
    all_prob_transition: list[float] = []
    all_true_stable: list[int] = []
    all_pred_stable: list[int] = []
    all_prob_stable: list[float] = []

    for train_idx, test_idx in gkf.split(X, y, groups):
        scaler = StandardScaler().fit(X[train_idx])
        clf = LogisticRegression(class_weight="balanced", max_iter=1000)
        clf.fit(scaler.transform(X[train_idx]), y[train_idx])

        y_prob = clf.predict_proba(scaler.transform(X[test_idx]))[:, 1]
        y_pred = (y_prob >= 0.5).astype(int)
        transition_mask = near_transition[test_idx]

        all_true_transition.extend(y[test_idx][transition_mask])
        all_pred_transition.extend(y_pred[transition_mask])
        all_prob_transition.extend(y_prob[transition_mask])
        all_true_stable.extend(y[test_idx][~transition_mask])
        all_pred_stable.extend(y_pred[~transition_mask])
        all_prob_stable.extend(y_prob[~transition_mask])

    print("Patient-level held-out performance, split by window position:")
    _report(
        np.array(all_true_stable),
        np.array(all_pred_stable),
        np.array(all_prob_stable),
        "Stable windows (well within a rhythm segment)",
    )
    _report(
        np.array(all_true_transition),
        np.array(all_pred_transition),
        np.array(all_prob_transition),
        "Transition windows (segment's first/last window)",
    )
    print(
        "\nA meaningfully lower accuracy/AUC on transition windows would "
        "indicate the model struggles specifically near rhythm changes — "
        "exactly the paroxysmal-like case this was meant to probe."
    )


if __name__ == "__main__":
    main()
