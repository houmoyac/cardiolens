from __future__ import annotations

from enum import StrEnum

from pydantic import BaseModel


class AlertSource(StrEnum):
    """Where a clinical alert comes from — kept explicit end-to-end so a
    physician always knows whether they are looking at a direct measurement
    or an algorithmic prediction."""

    RULE = "rule"
    AI = "ai"


class AlertSeverity(StrEnum):
    INFO = "info"
    WARNING = "warning"


class ClinicalAlert(BaseModel):
    code: str
    message: str
    source: AlertSource
    severity: AlertSeverity
    confidence: float | None = None
    """Set only for AI-sourced alerts (0-1). Rule-based alerts are never
    scored — they are either triggered or not, from a measured value."""


class ECGMeasurements(BaseModel):
    heart_rate_bpm: float
    pr_interval_ms: float
    qrs_duration_ms: float
    qt_interval_ms: float
    qtc_ms: float
    rr_interval_ms: float
    electrical_axis_deg: float | None = None
    """None until multi-lead (I, aVF) input is wired in — never fabricate 0°."""
