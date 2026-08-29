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
    """Bazett-corrected QT — the formula the qtc_* clinical thresholds are
    calibrated against. Known to over-correct at high heart rates and
    under-correct at low ones; see qtc_fridericia_ms for that regime."""
    qtc_fridericia_ms: float
    """Fridericia-corrected QT — informational only, not evaluated against
    thresholds yet. More reliable than Bazett outside a normal heart rate
    range; shown so the physician can judge, not to silently override Bazett."""
    rr_interval_ms: float
    rr_variability_pct: float
    """Coefficient of variation of RR intervals (%) — a coarse screening
    signal for rhythm irregularity, not a diagnosis of any specific
    arrhythmia."""
    electrical_axis_deg: float | None = None
    """None unless the caller supplied both lead I and aVF (see
    signal_processing.compute_electrical_axis) — the mobile app doesn't
    collect multi-lead input yet, so this stays null end-to-end there
    today; never fabricate 0° in its place."""
