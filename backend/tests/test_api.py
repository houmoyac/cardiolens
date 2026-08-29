from __future__ import annotations

from pathlib import Path

import neurokit2 as nk
import numpy as np
from fastapi.testclient import TestClient

from cardiolens.api import app

client = TestClient(app)
SAMPLE_DIR = Path(__file__).parent.parent / "src" / "cardiolens" / "sample_ecgs"


def test_health() -> None:
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_analyze_returns_measurements_and_alerts() -> None:
    sampling_rate = 500
    signal = nk.ecg_simulate(
        duration=10,
        sampling_rate=sampling_rate,
        heart_rate=75,
        method="ecgsyn",
        random_state=42,
    )

    response = client.post(
        "/analyze",
        json={"signal": list(signal), "sampling_rate": sampling_rate, "sex": "M"},
    )

    assert response.status_code == 200
    body = response.json()
    assert "measurements" in body
    assert "alerts" in body
    assert body["measurements"]["heart_rate_bpm"] > 0


def test_analyze_rejects_unprocessable_signal() -> None:
    response = client.post(
        "/analyze",
        json={"signal": [0.0] * 2500, "sampling_rate": 500},
    )

    assert response.status_code == 422


def test_analyze_does_not_flag_real_normal_recording_as_afib() -> None:
    signal = np.loadtxt(SAMPLE_DIR / "sample_normal_ecg.csv", delimiter=",").ravel()

    response = client.post(
        "/analyze",
        json={"signal": signal.tolist(), "sampling_rate": 500, "sex": "M"},
    )

    assert response.status_code == 200
    ai_alerts = [a for a in response.json()["alerts"] if a["source"] == "ai"]
    assert ai_alerts == []


def test_analyze_without_lead_i_avf_leaves_axis_null() -> None:
    sampling_rate = 500
    signal = nk.ecg_simulate(
        duration=10, sampling_rate=sampling_rate, heart_rate=75, method="ecgsyn", random_state=42
    )

    response = client.post(
        "/analyze", json={"signal": list(signal), "sampling_rate": sampling_rate}
    )

    assert response.status_code == 200
    assert response.json()["measurements"]["electrical_axis_deg"] is None


def test_analyze_with_lead_i_avf_computes_axis() -> None:
    sampling_rate = 500
    signal = nk.ecg_simulate(
        duration=10, sampling_rate=sampling_rate, heart_rate=75, method="ecgsyn", random_state=42
    )
    signal_list = list(signal)

    response = client.post(
        "/analyze",
        json={
            "signal": signal_list,
            "sampling_rate": sampling_rate,
            "lead_i": signal_list,
            "lead_avf": signal_list,
        },
    )

    assert response.status_code == 200
    axis = response.json()["measurements"]["electrical_axis_deg"]
    assert axis is not None
    assert abs(axis - 45.0) < 5.0


def test_ai_alerts_always_carry_a_confidence_score() -> None:
    """Structural guarantee, not a specific prediction: any AI-sourced
    alert the API ever returns must be scored — never presented with the
    same unscored certainty as a rule-based alert."""
    sampling_rate = 500
    signal = nk.ecg_simulate(
        duration=10, sampling_rate=sampling_rate, heart_rate=90, method="ecgsyn", random_state=7
    )

    response = client.post(
        "/analyze",
        json={"signal": list(signal), "sampling_rate": sampling_rate},
    )

    assert response.status_code == 200
    for alert in response.json()["alerts"]:
        if alert["source"] == "ai":
            assert alert["confidence"] is not None
