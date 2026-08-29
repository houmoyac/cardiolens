"""Persisted analysis history — one row per /analyze call made while
logged in. Not the source of truth for the measurements/alerts schema
(that's cardiolens.models); this just archives a JSON snapshot of what was
computed and shown at the time, tied to the doctor who ran it."""

from __future__ import annotations

import json
from datetime import UTC, datetime

from pydantic import BaseModel
from sqlmodel import Field, SQLModel

from cardiolens.models import ClinicalAlert, ECGMeasurements


class AnalysisRecord(SQLModel, table=True):
    id: int | None = Field(default=None, primary_key=True)
    user_id: int = Field(foreign_key="user.id", index=True)
    patient_label: str
    date_label: str
    measurements_json: str
    alerts_json: str
    created_at: datetime = Field(default_factory=lambda: datetime.now(UTC))


class AnalysisRecordPublic(BaseModel):
    id: int
    patient_label: str
    date_label: str
    measurements: ECGMeasurements
    alerts: list[ClinicalAlert]
    created_at: datetime


def to_public(record: AnalysisRecord) -> AnalysisRecordPublic:
    return AnalysisRecordPublic(
        id=record.id,  # type: ignore[arg-type]
        patient_label=record.patient_label,
        date_label=record.date_label,
        measurements=ECGMeasurements.model_validate_json(record.measurements_json),
        alerts=[ClinicalAlert.model_validate(a) for a in json.loads(record.alerts_json)],
        created_at=record.created_at,
    )
