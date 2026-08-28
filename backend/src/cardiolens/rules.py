from __future__ import annotations

from dataclasses import dataclass

from cardiolens.models import AlertSeverity, AlertSource, ClinicalAlert, ECGMeasurements


@dataclass(frozen=True)
class GuidelineThresholds:
    """Clinical thresholds for one guideline profile (ESC, AHA, ...).

    Kept as plain, swappable data rather than hardcoded in the rule logic so
    a new region/guideline is a new profile, not a code change.
    """

    name: str
    bradycardia_bpm: float = 60.0
    tachycardia_bpm: float = 100.0
    pr_short_ms: float = 120.0
    pr_long_ms: float = 200.0
    qrs_wide_ms: float = 120.0
    qtc_long_male_ms: float = 450.0
    qtc_long_female_ms: float = 460.0
    qtc_short_ms: float = 340.0
    axis_left_deg: float = -30.0
    axis_right_deg: float = 90.0


ESC_DEFAULT = GuidelineThresholds(name="ESC")


def evaluate_rules(
    measurements: ECGMeasurements,
    thresholds: GuidelineThresholds = ESC_DEFAULT,
    sex: str | None = None,
) -> list[ClinicalAlert]:
    """Apply threshold-based clinical rules to a set of measurements.

    Every alert traces back to a measured value and a published threshold —
    nothing here is learned or inferred, which is the point: this layer must
    stay fully explainable to the validating physician.
    """
    alerts: list[ClinicalAlert] = []

    if measurements.heart_rate_bpm < thresholds.bradycardia_bpm:
        alerts.append(
            ClinicalAlert(
                code="bradycardia",
                message=(
                    f"Bradycardie ({measurements.heart_rate_bpm:.0f} bpm, "
                    f"seuil < {thresholds.bradycardia_bpm:.0f} bpm)"
                ),
                source=AlertSource.RULE,
                severity=AlertSeverity.WARNING,
            )
        )
    elif measurements.heart_rate_bpm > thresholds.tachycardia_bpm:
        alerts.append(
            ClinicalAlert(
                code="tachycardia",
                message=(
                    f"Tachycardie ({measurements.heart_rate_bpm:.0f} bpm, "
                    f"seuil > {thresholds.tachycardia_bpm:.0f} bpm)"
                ),
                source=AlertSource.RULE,
                severity=AlertSeverity.WARNING,
            )
        )

    if measurements.pr_interval_ms > thresholds.pr_long_ms:
        alerts.append(
            ClinicalAlert(
                code="pr_prolonged",
                message=(
                    f"PR allongé ({measurements.pr_interval_ms:.0f} ms), "
                    "évoquant un bloc AV du 1er degré"
                ),
                source=AlertSource.RULE,
                severity=AlertSeverity.WARNING,
            )
        )
    elif measurements.pr_interval_ms < thresholds.pr_short_ms:
        alerts.append(
            ClinicalAlert(
                code="pr_short",
                message=(
                    f"PR court ({measurements.pr_interval_ms:.0f} ms), "
                    "à corréler avec une pré-excitation"
                ),
                source=AlertSource.RULE,
                severity=AlertSeverity.WARNING,
            )
        )

    if measurements.qrs_duration_ms > thresholds.qrs_wide_ms:
        alerts.append(
            ClinicalAlert(
                code="qrs_wide",
                message=(
                    f"QRS élargi ({measurements.qrs_duration_ms:.0f} ms), "
                    "évoquant un bloc de branche"
                ),
                source=AlertSource.RULE,
                severity=AlertSeverity.WARNING,
            )
        )

    qtc_threshold = thresholds.qtc_long_female_ms if sex == "F" else thresholds.qtc_long_male_ms
    if measurements.qtc_ms > qtc_threshold:
        alerts.append(
            ClinicalAlert(
                code="qtc_prolonged",
                message=(
                    f"QTc allongé ({measurements.qtc_ms:.0f} ms, seuil > {qtc_threshold:.0f} ms) "
                    "— à interpréter selon le contexte clinique et les traitements en cours"
                ),
                source=AlertSource.RULE,
                severity=AlertSeverity.WARNING,
            )
        )
    elif measurements.qtc_ms < thresholds.qtc_short_ms:
        alerts.append(
            ClinicalAlert(
                code="qtc_short",
                message=(
                    f"QTc court ({measurements.qtc_ms:.0f} ms, "
                    f"seuil < {thresholds.qtc_short_ms:.0f} ms) — évoquant un syndrome "
                    "du QT court, à corréler cliniquement"
                ),
                source=AlertSource.RULE,
                severity=AlertSeverity.WARNING,
            )
        )

    if measurements.electrical_axis_deg is not None:
        if measurements.electrical_axis_deg < thresholds.axis_left_deg:
            alerts.append(
                ClinicalAlert(
                    code="left_axis_deviation",
                    message=f"Déviation axiale gauche ({measurements.electrical_axis_deg:.0f}°)",
                    source=AlertSource.RULE,
                    severity=AlertSeverity.INFO,
                )
            )
        elif measurements.electrical_axis_deg > thresholds.axis_right_deg:
            alerts.append(
                ClinicalAlert(
                    code="right_axis_deviation",
                    message=f"Déviation axiale droite ({measurements.electrical_axis_deg:.0f}°)",
                    source=AlertSource.RULE,
                    severity=AlertSeverity.INFO,
                )
            )

    if not alerts:
        alerts.append(
            ClinicalAlert(
                code="within_normal_limits",
                message="Fréquence, PR, QRS, QTc et axe dans les normes",
                source=AlertSource.RULE,
                severity=AlertSeverity.INFO,
            )
        )

    return alerts
