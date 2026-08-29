from __future__ import annotations

from pathlib import Path

import neurokit2 as nk
import numpy as np
import pytest

from cardiolens.rules import ESC_DEFAULT, evaluate_rules
from cardiolens.signal_processing import ECGProcessingError, compute_electrical_axis, measure_ecg

SAMPLE_DIR = Path(__file__).parent.parent / "src" / "cardiolens" / "sample_ecgs"


def test_measure_ecg_on_simulated_normal_rhythm() -> None:
    sampling_rate = 500
    signal = nk.ecg_simulate(
        duration=10,
        sampling_rate=sampling_rate,
        heart_rate=75,
        method="ecgsyn",
        random_state=42,
    )

    measurements = measure_ecg(np.asarray(signal), sampling_rate=sampling_rate)

    assert 65 <= measurements.heart_rate_bpm <= 85
    assert 80 <= measurements.pr_interval_ms <= 220
    assert 60 <= measurements.qrs_duration_ms <= 160
    assert 300 <= measurements.qtc_ms <= 500
    assert measurements.electrical_axis_deg is None


def test_measure_ecg_rejects_flat_signal() -> None:
    sampling_rate = 500
    signal = np.zeros(sampling_rate * 5)

    with pytest.raises(ECGProcessingError):
        measure_ecg(signal, sampling_rate=sampling_rate)


def test_measure_ecg_on_real_normal_ptbxl_recording() -> None:
    """Regression test on a real, anonymized, publicly labeled 'NORM'
    PTB-XL recording — synthetic signals alone hid real-signal delineation
    problems (see git history) that this catches."""
    signal = np.loadtxt(SAMPLE_DIR / "sample_normal_ecg.csv", delimiter=",").ravel()

    measurements = measure_ecg(signal, sampling_rate=500)
    alerts = evaluate_rules(measurements, ESC_DEFAULT, sex="M")

    assert all(a.code == "within_normal_limits" for a in alerts)


def test_measure_ecg_on_real_bradycardia_ptbxl_recording() -> None:
    signal = np.loadtxt(SAMPLE_DIR / "sample_bradycardia_ecg.csv", delimiter=",").ravel()

    measurements = measure_ecg(signal, sampling_rate=500)
    alerts = evaluate_rules(measurements, ESC_DEFAULT, sex="M")

    assert any(a.code == "bradycardia" for a in alerts)


def test_measure_ecg_rejects_too_short_signal() -> None:
    sampling_rate = 500
    signal = np.asarray(
        nk.ecg_simulate(duration=1, sampling_rate=sampling_rate, heart_rate=75, random_state=1)
    )

    with pytest.raises(ECGProcessingError):
        measure_ecg(signal, sampling_rate=sampling_rate)


def test_compute_electrical_axis_identical_leads_gives_45_degrees() -> None:
    """atan2(net, net) = 45° exactly, for any equal, nonzero net — a
    verifiable sanity check on the angle math and delineation pipeline
    without needing a real physically-paired lead I/aVF recording."""
    sampling_rate = 500
    signal = np.asarray(
        nk.ecg_simulate(
            duration=10, sampling_rate=sampling_rate, heart_rate=75, method="ecgsyn",
            random_state=42,
        )
    )

    axis = compute_electrical_axis(signal, signal, sampling_rate=sampling_rate)

    assert axis is not None
    assert abs(axis - 45.0) < 5.0


def test_compute_electrical_axis_returns_none_for_undelineable_lead() -> None:
    sampling_rate = 500
    signal = np.asarray(
        nk.ecg_simulate(
            duration=10, sampling_rate=sampling_rate, heart_rate=75, method="ecgsyn",
            random_state=42,
        )
    )
    flat = np.zeros(sampling_rate * 10)

    assert compute_electrical_axis(signal, flat, sampling_rate=sampling_rate) is None
    assert compute_electrical_axis(flat, flat, sampling_rate=sampling_rate) is None
