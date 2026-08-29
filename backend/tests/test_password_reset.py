from __future__ import annotations

import re

from conftest import register as _register
from fastapi.testclient import TestClient


def _extract_dev_token(caplog) -> str:  # type: ignore[no-untyped-def]
    for record in caplog.records:
        match = re.search(r"dev token \(valid 30 min\): (\S+)", record.message)
        if match:
            return match.group(1)
    raise AssertionError("No dev reset token was logged")


def test_forgot_password_logs_a_token_for_a_known_email(client: TestClient, caplog) -> None:  # type: ignore[no-untyped-def]
    _register(client)
    with caplog.at_level("WARNING"):
        response = client.post("/auth/forgot-password", json={"email": "dr.test@example.com"})
    assert response.status_code == 204
    assert _extract_dev_token(caplog)


def test_forgot_password_is_silent_for_an_unknown_email(client: TestClient, caplog) -> None:  # type: ignore[no-untyped-def]
    """Same 204, no token logged — never confirm or deny an account exists."""
    with caplog.at_level("WARNING"):
        response = client.post("/auth/forgot-password", json={"email": "nobody@example.com"})
    assert response.status_code == 204
    assert caplog.records == []


def test_reset_password_with_valid_token_then_login(client: TestClient, caplog) -> None:  # type: ignore[no-untyped-def]
    _register(client)
    with caplog.at_level("WARNING"):
        client.post("/auth/forgot-password", json={"email": "dr.test@example.com"})
    token = _extract_dev_token(caplog)

    response = client.post(
        "/auth/reset-password", json={"token": token, "new_password": "brand-new-password-1"}
    )
    assert response.status_code == 204

    old_login = client.post(
        "/auth/login",
        json={"email": "dr.test@example.com", "password": "correct-horse-battery"},
    )
    assert old_login.status_code == 401

    new_login = client.post(
        "/auth/login",
        json={"email": "dr.test@example.com", "password": "brand-new-password-1"},
    )
    assert new_login.status_code == 200


def test_reset_password_token_is_single_use(client: TestClient, caplog) -> None:  # type: ignore[no-untyped-def]
    _register(client)
    with caplog.at_level("WARNING"):
        client.post("/auth/forgot-password", json={"email": "dr.test@example.com"})
    token = _extract_dev_token(caplog)

    first = client.post(
        "/auth/reset-password", json={"token": token, "new_password": "brand-new-password-1"}
    )
    assert first.status_code == 204

    second = client.post(
        "/auth/reset-password", json={"token": token, "new_password": "another-password-2"}
    )
    assert second.status_code == 400


def test_reset_password_rejects_a_garbage_token(client: TestClient) -> None:
    response = client.post(
        "/auth/reset-password", json={"token": "not-a-real-token", "new_password": "whatever123"}
    )
    assert response.status_code == 400
