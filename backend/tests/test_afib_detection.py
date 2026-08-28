from __future__ import annotations

from pathlib import Path

import neurokit2 as nk
import numpy as np
import pytest

from cardiolens.afib_detection import predict_afib_probability
from cardiolens.afib_features import HrvFeatureError, extract_hrv_features, features_to_vector

SAMPLE_DIR = Path(__file__).parent.parent / "src" / "cardiolens" / "sample_ecgs"


def test_extract_hrv_features_on_regular_simulated_rhythm() -> None:
    sampling_rate = 500
    signal = np.asarray(
        nk.ecg_simulate(
            duration=15, sampling_rate=sampling_rate, heart_rate=75, method="ecgsyn", random_state=1
        )
    )

    features = extract_hrv_features(signal, sampling_rate)

    # A regular simulated rhythm should show low RR variability — sanity
    # check that the features point the expected direction, not exact
    # values (those depend on NeuroKit2's simulator internals).
    assert features["rr_cv_pct"] < 10
    assert features["heart_rate_bpm"] == pytest.approx(75, abs=10)


def test_extract_hrv_features_rejects_too_few_beats() -> None:
    sampling_rate = 500
    signal = np.asarray(
        nk.ecg_simulate(duration=1, sampling_rate=sampling_rate, heart_rate=75, random_state=1)
    )
    with pytest.raises(HrvFeatureError):
        extract_hrv_features(signal, sampling_rate)


def test_features_to_vector_matches_feature_names_order() -> None:
    features = {
        "mean_rr_ms": 800.0,
        "sdnn_ms": 20.0,
        "rmssd_ms": 15.0,
        "pnn50_pct": 2.0,
        "rr_cv_pct": 2.5,
        "heart_rate_bpm": 75.0,
    }
    vector = features_to_vector(features)
    assert vector.tolist() == [800.0, 20.0, 15.0, 2.0, 2.5, 75.0]


def test_predict_afib_probability_on_real_normal_ptbxl_recording() -> None:
    """Sanity check on real data already validated elsewhere in the test
    suite (see test_signal_processing.py): a confirmed-normal recording
    should score low, not high, on the AFib model."""
    signal = np.loadtxt(SAMPLE_DIR / "sample_normal_ecg.csv", delimiter=",").ravel()

    probability = predict_afib_probability(signal, sampling_rate=500)

    assert probability is not None
    assert probability < 0.5


def test_predict_afib_probability_returns_none_on_too_short_signal() -> None:
    signal = np.asarray(
        nk.ecg_simulate(duration=1, sampling_rate=500, heart_rate=75, random_state=1)
    )
    assert predict_afib_probability(signal, sampling_rate=500) is None
