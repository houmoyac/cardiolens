from __future__ import annotations

import numpy as np
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

from cardiolens.afib_detection import predict_afib_probability
from cardiolens.models import AlertSeverity, AlertSource, ClinicalAlert, ECGMeasurements
from cardiolens.rules import ESC_DEFAULT, evaluate_rules
from cardiolens.signal_processing import ECGProcessingError, measure_ecg

# Not tuned beyond the classifier's own balanced-class default (0.5) — see
# scripts/train_afib_model.py's docstring for why this shouldn't be read as
# a clinically validated cutoff.
AFIB_ALERT_THRESHOLD = 0.5

app = FastAPI(
    title="CardioLens API",
    version="0.1.0",
    description=(
        "Aide à l'interprétation ECG (mesures + règles cliniques). "
        "Ne remplace pas le jugement médical."
    ),
)


class AnalyzeRequest(BaseModel):
    signal: list[float]
    sampling_rate: int
    sex: str | None = None


class AnalyzeResponse(BaseModel):
    measurements: ECGMeasurements
    alerts: list[ClinicalAlert]


@app.post("/analyze", response_model=AnalyzeResponse)
def analyze(request: AnalyzeRequest) -> AnalyzeResponse:
    signal = np.asarray(request.signal, dtype=np.float64)
    try:
        measurements = measure_ecg(signal, sampling_rate=request.sampling_rate)
    except ECGProcessingError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc

    alerts = evaluate_rules(measurements, ESC_DEFAULT, sex=request.sex)

    # The AI layer must never break the rules layer — if it fails for any
    # reason, the physician still gets the reliable rule-based alerts.
    try:
        afib_probability = predict_afib_probability(signal, request.sampling_rate)
    except Exception:  # noqa: BLE001
        afib_probability = None

    if afib_probability is not None and afib_probability >= AFIB_ALERT_THRESHOLD:
        alerts.append(
            ClinicalAlert(
                code="afib_suspected",
                message=(
                    "Suspicion de fibrillation atriale (variabilité du rythme) "
                    "— prédiction algorithmique, à corréler cliniquement"
                ),
                source=AlertSource.AI,
                severity=AlertSeverity.WARNING,
                confidence=afib_probability,
            )
        )

    return AnalyzeResponse(measurements=measurements, alerts=alerts)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}
