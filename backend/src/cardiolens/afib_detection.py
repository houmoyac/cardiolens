from __future__ import annotations

from pathlib import Path
from typing import Any

import numpy as np
from joblib import load
from numpy.typing import NDArray

from cardiolens.afib_features import HrvFeatureError, extract_hrv_features, features_to_vector

MODEL_PATH = Path(__file__).parent / "models" / "afib_model.joblib"

# See scripts/train_afib_model.py's module docstring for the full caveat:
# trained on only 48 confirmed-AFIB PTB-XL records — a directional signal
# that RR-irregularity features work for this, not a validated
# clinical-grade model. Never presented as a diagnosis (see api.py): always
# AlertSource.AI, always carries `confidence`, always the literal
# "à vérifier" framing already established for the AI section.
_MODEL_CACHE: dict[str, Any] | None = None


def _load_model() -> dict[str, Any]:
    global _MODEL_CACHE
    if _MODEL_CACHE is None:
        if not MODEL_PATH.exists():
            raise RuntimeError(
                f"Modèle AFib introuvable ({MODEL_PATH}) — lancer "
                "scripts/train_afib_model.py pour le générer."
            )
        _MODEL_CACHE = load(MODEL_PATH)
    return _MODEL_CACHE


def predict_afib_probability(signal: NDArray[np.float64], sampling_rate: int) -> float | None:
    """Returns the model's estimated probability (0-1) that this signal
    shows atrial fibrillation, or None if too few beats were detected to
    compute the underlying HRV features (silently skipping AI detection
    is correct here — the rule engine's own beat-count check already
    surfaces that failure to the physician; this must not raise a second,
    confusing error for the same root cause).
    """
    try:
        features = extract_hrv_features(signal, sampling_rate)
    except HrvFeatureError:
        return None

    model = _load_model()
    x = features_to_vector(features).reshape(1, -1)
    x_scaled = model["scaler"].transform(x)
    probability = model["classifier"].predict_proba(x_scaled)[0, 1]
    return float(probability)
