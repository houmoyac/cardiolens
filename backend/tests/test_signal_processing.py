from __future__ import annotations

import neurokit2 as nk
import numpy as np
import pytest

from cardiolens.signal_processing import ECGProcessingError, measure_ecg


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


def test_measure_ecg_rejects_too_short_signal() -> None:
    sampling_rate = 500
    signal = np.asarray(
        nk.ecg_simulate(duration=1, sampling_rate=sampling_rate, heart_rate=75, random_state=1)
    )

    with pytest.raises(ECGProcessingError):
        measure_ecg(signal, sampling_rate=sampling_rate)
