from __future__ import annotations

from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

import numpy as np
from fastapi import Depends, FastAPI, HTTPException
from pydantic import BaseModel
from sqlmodel import Session, select

from cardiolens.afib_detection import predict_afib_probability
from cardiolens.auth import create_access_token, get_current_user, hash_password, verify_password
from cardiolens.auth_models import Token, User, UserLogin, UserPublic, UserRegister
from cardiolens.db import get_session, init_db
from cardiolens.models import AlertSeverity, AlertSource, ClinicalAlert, ECGMeasurements
from cardiolens.rules import ESC_DEFAULT, evaluate_rules
from cardiolens.signal_processing import ECGProcessingError, measure_ecg

# Not tuned beyond the classifier's own balanced-class default (0.5) — see
# scripts/train_afib_model.py's docstring for why this shouldn't be read as
# a clinically validated cutoff.
AFIB_ALERT_THRESHOLD = 0.5

@asynccontextmanager
async def _lifespan(_app: FastAPI) -> AsyncIterator[None]:
    init_db()
    yield


app = FastAPI(
    title="CardioLens API",
    version="0.1.0",
    description=(
        "Aide à l'interprétation ECG (mesures + règles cliniques). "
        "Ne remplace pas le jugement médical."
    ),
    lifespan=_lifespan,
)


@app.post("/auth/register", response_model=UserPublic, status_code=201)
def register(payload: UserRegister, session: Session = Depends(get_session)) -> User:
    existing = session.exec(select(User).where(User.email == payload.email)).first()
    if existing is not None:
        raise HTTPException(status_code=409, detail="Un compte existe déjà avec cet email.")

    user = User(
        email=payload.email,
        full_name=payload.full_name,
        hashed_password=hash_password(payload.password),
    )
    session.add(user)
    session.commit()
    session.refresh(user)
    return user


@app.post("/auth/login", response_model=Token)
def login(payload: UserLogin, session: Session = Depends(get_session)) -> Token:
    user = session.exec(select(User).where(User.email == payload.email)).first()
    if user is None or not verify_password(payload.password, user.hashed_password):
        raise HTTPException(status_code=401, detail="Email ou mot de passe incorrect.")

    return Token(access_token=create_access_token(user.id))  # type: ignore[arg-type]


@app.get("/auth/me", response_model=UserPublic)
def me(current_user: User = Depends(get_current_user)) -> User:
    return current_user


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
