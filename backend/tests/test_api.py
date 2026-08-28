from __future__ import annotations

import neurokit2 as nk
from fastapi.testclient import TestClient

from cardiolens.api import app

client = TestClient(app)


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
