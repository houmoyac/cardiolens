from __future__ import annotations

from cardiolens.models import AlertSource, ECGMeasurements
from cardiolens.rules import ESC_DEFAULT, evaluate_rules

NORMAL = ECGMeasurements(
    heart_rate_bpm=75,
    pr_interval_ms=160,
    qrs_duration_ms=90,
    qt_interval_ms=380,
    qtc_ms=420,
    qtc_fridericia_ms=410,
    rr_interval_ms=800,
    electrical_axis_deg=30,
)


def test_normal_ecg_has_no_warning_alerts() -> None:
    alerts = evaluate_rules(NORMAL, ESC_DEFAULT)
    assert all(a.code == "within_normal_limits" for a in alerts)


def test_bradycardia_detected_below_threshold() -> None:
    m = NORMAL.model_copy(update={"heart_rate_bpm": 45})
    alerts = evaluate_rules(m, ESC_DEFAULT)
    assert any(a.code == "bradycardia" for a in alerts)
    assert not any(a.code == "tachycardia" for a in alerts)


def test_tachycardia_detected_above_threshold() -> None:
    m = NORMAL.model_copy(update={"heart_rate_bpm": 130})
    alerts = evaluate_rules(m, ESC_DEFAULT)
    assert any(a.code == "tachycardia" for a in alerts)


def test_pr_prolonged_detected() -> None:
    m = NORMAL.model_copy(update={"pr_interval_ms": 240})
    alerts = evaluate_rules(m, ESC_DEFAULT)
    assert any(a.code == "pr_prolonged" for a in alerts)


def test_qrs_wide_detected() -> None:
    m = NORMAL.model_copy(update={"qrs_duration_ms": 150})
    alerts = evaluate_rules(m, ESC_DEFAULT)
    assert any(a.code == "qrs_wide" for a in alerts)


def test_qtc_prolonged_uses_sex_specific_threshold() -> None:
    m = NORMAL.model_copy(update={"qtc_ms": 455})
    alerts_male = evaluate_rules(m, ESC_DEFAULT, sex="M")
    alerts_female = evaluate_rules(m, ESC_DEFAULT, sex="F")
    assert any(a.code == "qtc_prolonged" for a in alerts_male)
    assert not any(a.code == "qtc_prolonged" for a in alerts_female)


def test_qtc_short_detected() -> None:
    m = NORMAL.model_copy(update={"qtc_ms": 320})
    alerts = evaluate_rules(m, ESC_DEFAULT, sex="M")
    assert any(a.code == "qtc_short" for a in alerts)
    assert not any(a.code == "qtc_prolonged" for a in alerts)


def test_axis_deviation_skipped_when_unmeasured() -> None:
    m = NORMAL.model_copy(update={"electrical_axis_deg": None})
    alerts = evaluate_rules(m, ESC_DEFAULT)
    assert not any(a.code.endswith("axis_deviation") for a in alerts)


def test_all_rule_alerts_come_from_direct_measurement() -> None:
    m = NORMAL.model_copy(update={"pr_interval_ms": 240, "qrs_duration_ms": 150})
    alerts = evaluate_rules(m, ESC_DEFAULT)
    assert all(a.source == AlertSource.RULE for a in alerts)
    assert all(a.confidence is None for a in alerts)
    assert all(a.message for a in alerts)
