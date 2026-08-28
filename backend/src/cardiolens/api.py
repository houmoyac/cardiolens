from __future__ import annotations

import numpy as np
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

from cardiolens.models import ClinicalAlert, ECGMeasurements
from cardiolens.rules import ESC_DEFAULT, evaluate_rules
from cardiolens.signal_processing import ECGProcessingError, measure_ecg

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
    return AnalyzeResponse(measurements=measurements, alerts=alerts)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}
