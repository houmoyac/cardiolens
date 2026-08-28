from __future__ import annotations

import neurokit2 as nk
import numpy as np
from numpy.typing import NDArray

# Standard HRV features from the RR-interval literature — deliberately not
# a deep-learning-on-raw-signal approach. Keeping this explainable and
# lightweight matches the project's stance throughout (see
# ARCHITECTURE.md): a physician can be told exactly what these numbers
# mean, unlike a black-box model's internals.


class HrvFeatureError(RuntimeError):
    """Raised when too few beats are detected to compute HRV features
    reliably — never return features computed from 1-2 RR intervals."""


FEATURE_NAMES = (
    "mean_rr_ms",
    "sdnn_ms",
    "rmssd_ms",
    "pnn50_pct",
    "rr_cv_pct",
    "heart_rate_bpm",
)


def extract_hrv_features(
    signal: NDArray[np.float64], sampling_rate: int
) -> dict[str, float]:
    """Extract standard RR-interval HRV features from a single-lead ECG.

    - SDNN: overall RR variability (ms).
    - RMSSD: beat-to-beat variability — the feature most specific to
      rhythm irregularity (elevated in atrial fibrillation).
    - pNN50: % of successive RR differences exceeding 50ms — another
      well-established irregularity marker.
    - rr_cv_pct: coefficient of variation — same quantity
      signal_processing.py already reports as rr_variability_pct, kept
      under its own name here since this module has its own contract.
    """
    try:
        cleaned = nk.ecg_clean(signal, sampling_rate=sampling_rate)
        _, r_info = nk.ecg_peaks(cleaned, sampling_rate=sampling_rate)
        r_peaks = np.asarray(r_info["ECG_R_Peaks"])
    except Exception as exc:
        raise HrvFeatureError(f"Détection des battements impossible : {exc}") from exc

    if len(r_peaks) < 5:
        raise HrvFeatureError(
            "Moins de 5 battements détectés — insuffisant pour calculer des "
            "features de variabilité fiables."
        )

    rr_ms = np.diff(r_peaks) / sampling_rate * 1000.0
    mean_rr = float(np.mean(rr_ms))
    if mean_rr <= 0:
        raise HrvFeatureError("Intervalle RR moyen non positif — signal invalide.")

    sdnn = float(np.std(rr_ms))
    rmssd = float(np.sqrt(np.mean(np.diff(rr_ms) ** 2)))
    pnn50 = float(np.mean(np.abs(np.diff(rr_ms)) > 50) * 100.0)
    cv = sdnn / mean_rr * 100.0

    return {
        "mean_rr_ms": mean_rr,
        "sdnn_ms": sdnn,
        "rmssd_ms": rmssd,
        "pnn50_pct": pnn50,
        "rr_cv_pct": cv,
        "heart_rate_bpm": 60_000.0 / mean_rr,
    }


def features_to_vector(features: dict[str, float]) -> NDArray[np.float64]:
    """Order features consistently for the model — training and inference
    must use the exact same order, this is the single source of truth
    for it."""
    return np.array([features[name] for name in FEATURE_NAMES], dtype=np.float64)
