from __future__ import annotations

import logging
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

import numpy as np
from fastapi import Depends, FastAPI, HTTPException, UploadFile
from fastapi.responses import Response
from pydantic import BaseModel
from sqlmodel import Session, select

from cardiolens.afib_detection import predict_afib_probability
from cardiolens.auth import (
    consume_password_reset_token,
    create_access_token,
    create_password_reset_token,
    get_current_user,
    get_current_user_optional,
    hash_password,
    verify_password,
)
from cardiolens.auth_models import (
    ForgotPasswordRequest,
    ResetPasswordRequest,
    Token,
    User,
    UserLogin,
    UserPasswordChange,
    UserProfileUpdate,
    UserPublic,
    UserRegister,
)
from cardiolens.case_models import AnalysisRecord, AnalysisRecordPublic, to_public
from cardiolens.db import get_session, init_db
from cardiolens.logo_storage import (
    InvalidLogoError,
    delete_logo,
    has_logo,
    load_logo_bytes,
    save_logo,
)
from cardiolens.models import AlertSeverity, AlertSource, ClinicalAlert, ECGMeasurements
from cardiolens.rules import ESC_DEFAULT, evaluate_rules
from cardiolens.signal_processing import ECGProcessingError, compute_electrical_axis, measure_ecg

# Not tuned beyond the classifier's own balanced-class default (0.5) — see
# scripts/train_afib_model.py's docstring for why this shouldn't be read as
# a clinically validated cutoff.
AFIB_ALERT_THRESHOLD = 0.5

logger = logging.getLogger("cardiolens.auth")

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


def _to_public(user: User) -> UserPublic:
    return UserPublic(
        id=user.id,  # type: ignore[arg-type]
        email=user.email,
        first_name=user.first_name,
        last_name=user.last_name,
        workplace=user.workplace,
        has_logo=has_logo(user.id),  # type: ignore[arg-type]
    )


@app.post("/auth/register", response_model=UserPublic, status_code=201)
def register(payload: UserRegister, session: Session = Depends(get_session)) -> UserPublic:
    existing = session.exec(select(User).where(User.email == payload.email)).first()
    if existing is not None:
        raise HTTPException(status_code=409, detail="Un compte existe déjà avec cet email.")

    user = User(
        email=payload.email,
        first_name=payload.first_name,
        last_name=payload.last_name,
        workplace=payload.workplace,
        hashed_password=hash_password(payload.password),
    )
    session.add(user)
    session.commit()
    session.refresh(user)
    return _to_public(user)


@app.post("/auth/login", response_model=Token)
def login(payload: UserLogin, session: Session = Depends(get_session)) -> Token:
    user = session.exec(select(User).where(User.email == payload.email)).first()
    if user is None or not verify_password(payload.password, user.hashed_password):
        raise HTTPException(status_code=401, detail="Email ou mot de passe incorrect.")

    return Token(access_token=create_access_token(user.id))  # type: ignore[arg-type]


@app.get("/auth/me", response_model=UserPublic)
def me(current_user: User = Depends(get_current_user)) -> UserPublic:
    return _to_public(current_user)


@app.patch("/auth/me", response_model=UserPublic)
def update_profile(
    payload: UserProfileUpdate,
    current_user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> UserPublic:
    current_user.workplace = payload.workplace
    session.add(current_user)
    session.commit()
    session.refresh(current_user)
    return _to_public(current_user)


@app.post("/auth/me/password", status_code=204)
def change_password(
    payload: UserPasswordChange,
    current_user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> None:
    if not verify_password(payload.current_password, current_user.hashed_password):
        raise HTTPException(status_code=401, detail="Mot de passe actuel incorrect.")
    current_user.hashed_password = hash_password(payload.new_password)
    session.add(current_user)
    session.commit()


@app.post("/auth/forgot-password", status_code=204)
def forgot_password(
    payload: ForgotPasswordRequest, session: Session = Depends(get_session)
) -> None:
    """Always returns 204, whether or not the email is registered — never
    let this endpoint leak which emails have an account.

    DEV-ONLY LIMITATION: no email provider is wired up yet, so the reset
    link is logged instead of sent (see ARCHITECTURE.md). A real
    deployment MUST replace this with an actual email send before this
    flow is usable outside development."""
    user = session.exec(select(User).where(User.email == payload.email)).first()
    if user is not None:
        raw_token = create_password_reset_token(user.id, session)  # type: ignore[arg-type]
        logger.warning(
            "Password reset requested for %s — dev token (valid 30 min): %s",
            user.email,
            raw_token,
        )


@app.post("/auth/reset-password", status_code=204)
def reset_password(
    payload: ResetPasswordRequest, session: Session = Depends(get_session)
) -> None:
    user = consume_password_reset_token(payload.token, session)
    if user is None:
        raise HTTPException(
            status_code=400, detail="Lien de réinitialisation invalide ou expiré."
        )
    user.hashed_password = hash_password(payload.new_password)
    session.add(user)
    session.commit()


@app.post("/auth/me/logo", response_model=UserPublic)
async def upload_logo(
    file: UploadFile, current_user: User = Depends(get_current_user)
) -> UserPublic:
    raw = await file.read()
    try:
        save_logo(current_user.id, raw)  # type: ignore[arg-type]
    except InvalidLogoError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    return _to_public(current_user)


@app.get("/auth/me/logo")
def get_logo(current_user: User = Depends(get_current_user)) -> Response:
    data = load_logo_bytes(current_user.id)  # type: ignore[arg-type]
    if data is None:
        raise HTTPException(status_code=404, detail="Aucun logo enregistré.")
    return Response(content=data, media_type="image/png")


@app.delete("/auth/me/logo", status_code=204)
def remove_logo(current_user: User = Depends(get_current_user)) -> None:
    delete_logo(current_user.id)  # type: ignore[arg-type]


class AnalyzeRequest(BaseModel):
    signal: list[float]
    sampling_rate: int
    sex: str | None = None
    # Optional: only used to label a saved history entry when the caller is
    # authenticated (see analyze()). A caller with no use for history (the
    # Streamlit tool, an unauthenticated request) can omit these.
    patient_label: str | None = None
    date_label: str | None = None
    # Optional: the electrical axis is computed only when BOTH are given —
    # a single lead (the required `signal` above) cannot yield it. Neither
    # affects any other measurement; `signal` alone still drives everything
    # else, unchanged, whether or not these are present.
    lead_i: list[float] | None = None
    lead_avf: list[float] | None = None


class AnalyzeResponse(BaseModel):
    measurements: ECGMeasurements
    alerts: list[ClinicalAlert]
    saved_case_id: int | None = None
    """Set when the caller was authenticated — the record's id in their
    analysis history (see /cases). None for an unauthenticated call: never
    silently save something the caller can't attribute to a doctor."""


@app.post("/analyze", response_model=AnalyzeResponse)
def analyze(
    request: AnalyzeRequest,
    current_user: User | None = Depends(get_current_user_optional),
    session: Session = Depends(get_session),
) -> AnalyzeResponse:
    signal = np.asarray(request.signal, dtype=np.float64)
    try:
        measurements = measure_ecg(signal, sampling_rate=request.sampling_rate)
    except ECGProcessingError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc

    if request.lead_i is not None and request.lead_avf is not None:
        axis_deg = compute_electrical_axis(
            np.asarray(request.lead_i, dtype=np.float64),
            np.asarray(request.lead_avf, dtype=np.float64),
            sampling_rate=request.sampling_rate,
        )
        # None (leads too noisy to delineate) is a legitimate outcome, not
        # an error — the rest of the analysis must not fail because of it.
        measurements = measurements.model_copy(update={"electrical_axis_deg": axis_deg})

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

    saved_case_id = None
    if current_user is not None:
        record = AnalysisRecord(
            user_id=current_user.id,
            patient_label=request.patient_label or "ECG",
            date_label=request.date_label or "",
            measurements_json=measurements.model_dump_json(),
            alerts_json=f"[{','.join(a.model_dump_json() for a in alerts)}]",
        )
        session.add(record)
        session.commit()
        session.refresh(record)
        saved_case_id = record.id

    return AnalyzeResponse(measurements=measurements, alerts=alerts, saved_case_id=saved_case_id)


@app.get("/cases", response_model=list[AnalysisRecordPublic])
def list_cases(
    current_user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> list[AnalysisRecordPublic]:
    records = session.exec(
        select(AnalysisRecord)
        .where(AnalysisRecord.user_id == current_user.id)
        .order_by(AnalysisRecord.created_at.desc())  # type: ignore[attr-defined]
    ).all()
    return [to_public(r) for r in records]


@app.get("/cases/{case_id}", response_model=AnalysisRecordPublic)
def get_case(
    case_id: int,
    current_user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> AnalysisRecordPublic:
    record = session.get(AnalysisRecord, case_id)
    if record is None or record.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Analyse introuvable.")
    return to_public(record)


@app.delete("/cases/{case_id}", status_code=204)
def delete_case(
    case_id: int,
    current_user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> None:
    record = session.get(AnalysisRecord, case_id)
    if record is None or record.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Analyse introuvable.")
    session.delete(record)
    session.commit()


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}
