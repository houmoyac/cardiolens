from __future__ import annotations

import neurokit2 as nk
import numpy as np
from numpy.typing import NDArray

from cardiolens.models import ECGMeasurements


class ECGProcessingError(RuntimeError):
    """Raised when the signal is too short, too noisy, or otherwise cannot
    be reliably delineated. Never silently return a partial/fabricated
    measurement — a clinician relying on this needs to know it failed."""


def measure_ecg(signal: NDArray[np.float64], sampling_rate: int) -> ECGMeasurements:
    """Extract standard measurements from a single-lead ECG signal.

    Electrical axis is left unset here — it requires the frontal-plane leads
    (I, aVF), not a single lead, and is wired in once multi-lead input lands.
    """
    try:
        cleaned = nk.ecg_clean(signal, sampling_rate=sampling_rate)
        _, r_info = nk.ecg_peaks(cleaned, sampling_rate=sampling_rate)
        r_peaks = np.asarray(r_info["ECG_R_Peaks"])
        if len(r_peaks) < 3:
            raise ECGProcessingError(
                "Signal trop court ou de trop mauvaise qualité pour détecter un rythme."
            )

        # "peak" delineation (Q/S peaks rather than DWT-estimated onset/offset
        # points) was empirically far more stable on real PTB-XL signals —
        # DWT onset/offset detection drifted enough per-beat to report
        # implausibly wide QRS on textbook-normal recordings.
        _, waves = nk.ecg_delineate(cleaned, r_peaks, sampling_rate=sampling_rate, method="peak")
    except ECGProcessingError:
        raise
    except Exception as exc:  # neurokit2 raises broad/varied errors on bad signals
        raise ECGProcessingError(f"Échec de l'analyse du signal : {exc}") from exc

    rr_intervals_ms = np.diff(r_peaks) / sampling_rate * 1000.0
    mean_rr_ms = float(np.nanmean(rr_intervals_ms))
    heart_rate_bpm = 60_000.0 / mean_rr_ms

    pr_interval_ms = _robust_interval_ms(
        waves, "ECG_P_Onsets", "ECG_Q_Peaks", sampling_rate, min_ms=80.0, max_ms=300.0
    )
    qrs_duration_ms = _robust_interval_ms(
        waves, "ECG_Q_Peaks", "ECG_S_Peaks", sampling_rate, min_ms=40.0, max_ms=200.0
    )
    qt_interval_ms = _robust_interval_ms(
        waves, "ECG_Q_Peaks", "ECG_T_Offsets", sampling_rate, min_ms=200.0, max_ms=600.0
    )

    if pr_interval_ms is None or qrs_duration_ms is None or qt_interval_ms is None:
        raise ECGProcessingError(
            "Impossible de délinéer de façon fiable les ondes P/QRS/T sur ce tracé."
        )

    qtc_ms = qt_interval_ms / np.sqrt(mean_rr_ms / 1000.0)  # Bazett

    return ECGMeasurements(
        heart_rate_bpm=heart_rate_bpm,
        pr_interval_ms=pr_interval_ms,
        qrs_duration_ms=qrs_duration_ms,
        qt_interval_ms=qt_interval_ms,
        qtc_ms=qtc_ms,
        rr_interval_ms=mean_rr_ms,
    )


def _robust_interval_ms(
    waves: dict[str, list[float]],
    start_key: str,
    end_key: str,
    sampling_rate: int,
    min_ms: float,
    max_ms: float,
) -> float | None:
    """Aggregate a per-beat interval, rejecting physiologically implausible
    beats before combining. Per-beat P/QRS onset-offset delineation is noisy
    on real signals — a handful of misdetected beats must not silently drag
    the reported measurement outside plausible range. Median, not mean, for
    the same reason: robust to the outliers that remain."""
    starts = np.asarray(waves.get(start_key, []), dtype=float)
    ends = np.asarray(waves.get(end_key, []), dtype=float)
    if starts.size == 0 or ends.size == 0:
        return None

    n = min(len(starts), len(ends))
    diffs_ms = (ends[:n] - starts[:n]) / sampling_rate * 1000.0
    diffs_ms = diffs_ms[~np.isnan(diffs_ms)]
    diffs_ms = diffs_ms[(diffs_ms >= min_ms) & (diffs_ms <= max_ms)]
    if diffs_ms.size < 3:
        return None

    return float(np.median(diffs_ms))
