from __future__ import annotations

import neurokit2 as nk
from conftest import login_token as _login_token
from conftest import register as _register
from fastapi.testclient import TestClient


def _valid_signal(sampling_rate: int = 500) -> list[float]:
    signal = nk.ecg_simulate(
        duration=10, sampling_rate=sampling_rate, heart_rate=75, method="ecgsyn", random_state=42
    )
    return list(signal)


def test_analyze_without_auth_does_not_save_a_case(client: TestClient) -> None:
    response = client.post(
        "/analyze",
        json={"signal": _valid_signal(), "sampling_rate": 500},
    )
    assert response.status_code == 200
    assert response.json()["saved_case_id"] is None


def test_analyze_with_auth_saves_a_case(client: TestClient) -> None:
    _register(client)
    token = _login_token(client)

    response = client.post(
        "/analyze",
        json={
            "signal": _valid_signal(),
            "sampling_rate": 500,
            "patient_label": "Patient #A-9001",
            "date_label": "Aujourd'hui",
        },
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 200
    case_id = response.json()["saved_case_id"]
    assert case_id is not None

    cases_response = client.get("/cases", headers={"Authorization": f"Bearer {token}"})
    assert cases_response.status_code == 200
    cases = cases_response.json()
    assert len(cases) == 1
    assert cases[0]["id"] == case_id
    assert cases[0]["patient_label"] == "Patient #A-9001"
    assert cases[0]["date_label"] == "Aujourd'hui"
    assert cases[0]["measurements"]["heart_rate_bpm"] > 0
    assert isinstance(cases[0]["alerts"], list)


def test_list_cases_requires_authentication(client: TestClient) -> None:
    response = client.get("/cases")
    assert response.status_code == 401


def test_get_case_by_id(client: TestClient) -> None:
    _register(client)
    token = _login_token(client)
    analyze_response = client.post(
        "/analyze",
        json={"signal": _valid_signal(), "sampling_rate": 500},
        headers={"Authorization": f"Bearer {token}"},
    )
    case_id = analyze_response.json()["saved_case_id"]

    response = client.get(f"/cases/{case_id}", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 200
    assert response.json()["id"] == case_id


def test_get_case_404s_for_unknown_id(client: TestClient) -> None:
    _register(client)
    token = _login_token(client)

    response = client.get("/cases/999999", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 404


def test_get_case_404s_when_not_owned_by_caller(client: TestClient) -> None:
    """A second doctor must never be able to read the first one's cases
    just by guessing an id — ownership, not just authentication."""
    _register(client, email="dr.one@example.com")
    token_one = _login_token(client, email="dr.one@example.com")
    analyze_response = client.post(
        "/analyze",
        json={"signal": _valid_signal(), "sampling_rate": 500},
        headers={"Authorization": f"Bearer {token_one}"},
    )
    case_id = analyze_response.json()["saved_case_id"]

    _register(client, email="dr.two@example.com")
    token_two = _login_token(client, email="dr.two@example.com")

    response = client.get(f"/cases/{case_id}", headers={"Authorization": f"Bearer {token_two}"})
    assert response.status_code == 404


def test_delete_case_removes_it(client: TestClient) -> None:
    _register(client)
    token = _login_token(client)
    analyze_response = client.post(
        "/analyze",
        json={"signal": _valid_signal(), "sampling_rate": 500},
        headers={"Authorization": f"Bearer {token}"},
    )
    case_id = analyze_response.json()["saved_case_id"]

    delete_response = client.delete(
        f"/cases/{case_id}", headers={"Authorization": f"Bearer {token}"}
    )
    assert delete_response.status_code == 204

    get_response = client.get(f"/cases/{case_id}", headers={"Authorization": f"Bearer {token}"})
    assert get_response.status_code == 404


def test_delete_case_requires_ownership(client: TestClient) -> None:
    _register(client, email="dr.one@example.com")
    token_one = _login_token(client, email="dr.one@example.com")
    analyze_response = client.post(
        "/analyze",
        json={"signal": _valid_signal(), "sampling_rate": 500},
        headers={"Authorization": f"Bearer {token_one}"},
    )
    case_id = analyze_response.json()["saved_case_id"]

    _register(client, email="dr.two@example.com")
    token_two = _login_token(client, email="dr.two@example.com")

    response = client.delete(
        f"/cases/{case_id}", headers={"Authorization": f"Bearer {token_two}"}
    )
    assert response.status_code == 404
