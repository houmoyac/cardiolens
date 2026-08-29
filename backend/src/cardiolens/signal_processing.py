from __future__ import annotations

import neurokit2 as nk
import numpy as np
from numpy.typing import NDArray

from cardiolens.models import ECGMeasurements

# Outside this range a computed heart rate is far more likely to be a beat
# detection artifact (double-counted or missed beats) than a real, if
# extreme, rhythm — bounded generously beyond clinical thresholds precisely
# so it never masks a real (if severe) bradycardia/tachycardia, only
# artifacts nothing sane accounts for.
MIN_PLAUSIBLE_HEART_RATE_BPM = 20.0
MAX_PLAUSIBLE_HEART_RATE_BPM = 300.0


class ECGProcessingError(RuntimeError):
    """Raised when the signal is too short, too noisy, or otherwise cannot
    be reliably delineated. Never silently return a partial/fabricated
    measurement — a clinician relying on this needs to know it failed."""


def measure_ecg(signal: NDArray[np.float64], sampling_rate: int) -> ECGMeasurements:
    """Extract standard measurements from a single-lead ECG signal.

    Electrical axis is always left unset here — it requires the
    frontal-plane leads (I, aVF), not a single lead. See
    compute_electrical_axis(), called separately by the API layer only
    when both leads are actually provided.
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

    if not (MIN_PLAUSIBLE_HEART_RATE_BPM <= heart_rate_bpm <= MAX_PLAUSIBLE_HEART_RATE_BPM):
        raise ECGProcessingError(
            f"Fréquence cardiaque calculée ({heart_rate_bpm:.0f} bpm) hors de toute plage "
            "physiologiquement plausible — probable erreur de détection des battements, "
            "pas une mesure fiable."
        )

    # Coefficient of variation of RR intervals — a coarse, well-established
    # screening signal for rhythm irregularity (e.g. possible atrial
    # fibrillation), computed from R-peaks alone so it doesn't depend on the
    # noisier P/QRS/T delineation. Not a diagnosis: a flag to correlate.
    rr_variability_pct = (
        float(np.std(rr_intervals_ms) / mean_rr_ms * 100.0) if len(rr_intervals_ms) >= 3 else 0.0
    )

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

    rr_s = mean_rr_ms / 1000.0
    qtc_bazett_ms = qt_interval_ms / np.sqrt(rr_s)
    qtc_fridericia_ms = qt_interval_ms / np.cbrt(rr_s)

    return ECGMeasurements(
        heart_rate_bpm=heart_rate_bpm,
        pr_interval_ms=pr_interval_ms,
        qrs_duration_ms=qrs_duration_ms,
        qt_interval_ms=qt_interval_ms,
        qtc_ms=qtc_bazett_ms,
        qtc_fridericia_ms=qtc_fridericia_ms,
        rr_interval_ms=mean_rr_ms,
        rr_variability_pct=rr_variability_pct,
    )


def compute_electrical_axis(
    lead_i: NDArray[np.float64], lead_avf: NDArray[np.float64], sampling_rate: int
) -> float | None:
    """Frontal-plane QRS axis from leads I and aVF (the standard two-lead
    hexaxial method) — angle = atan2(net_aVF, net_I), with lead I at 0° and
    aVF at +90° by convention.

    Net QRS deflection per beat is approximated as R-peak minus S-peak
    amplitude (the same simplification used for manual axis estimation) —
    Q is small enough in most leads for this to be the standard shorthand,
    not a fabricated shortcut. Returns None (never a fabricated angle) if
    either lead can't be reliably delineated — same failure posture as the
    rest of this module."""
    net_i = _median_net_qrs_amplitude(lead_i, sampling_rate)
    net_avf = _median_net_qrs_amplitude(lead_avf, sampling_rate)
    if net_i is None or net_avf is None:
        return None
    if net_i == 0.0 and net_avf == 0.0:
        return None  # atan2(0, 0) is mathematically 0 but physiologically meaningless here

    return float(np.degrees(np.arctan2(net_avf, net_i)))


def _median_net_qrs_amplitude(
    lead: NDArray[np.float64], sampling_rate: int
) -> float | None:
    try:
        cleaned = nk.ecg_clean(lead, sampling_rate=sampling_rate)
        _, r_info = nk.ecg_peaks(cleaned, sampling_rate=sampling_rate)
        r_peaks = np.asarray(r_info["ECG_R_Peaks"])
        if len(r_peaks) < 3:
            return None
        _, waves = nk.ecg_delineate(cleaned, r_peaks, sampling_rate=sampling_rate, method="peak")
    except Exception:  # noqa: BLE001 — neurokit2 raises broad/varied errors on bad signals
        return None

    s_peaks = np.asarray(waves.get("ECG_S_Peaks", []), dtype=float)
    n = min(len(r_peaks), len(s_peaks))
    if n < 3:
        return None

    valid = ~np.isnan(s_peaks[:n])
    r_idx = r_peaks[:n][valid].astype(int)
    s_idx = s_peaks[:n][valid].astype(int)
    if len(r_idx) < 3:
        return None

    net_amplitudes = cleaned[r_idx] - cleaned[s_idx]
    return float(np.median(net_amplitudes))


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
