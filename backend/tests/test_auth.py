from __future__ import annotations

import os
import tempfile
from collections.abc import Generator

import pytest
from fastapi.testclient import TestClient
from sqlmodel import SQLModel, create_engine

import cardiolens.db as db_module

# Importing the app here (not lazily inside a fixture) matters: it's what
# registers the User table on SQLModel.metadata before isolated_db's
# create_all() runs below — importing it later left the fixture creating
# tables for a metadata that didn't know about User yet.
from cardiolens.api import app


@pytest.fixture(autouse=True)
def isolated_db() -> Generator[None, None, None]:
    """Each test gets its own throwaway SQLite file — never share state
    between tests (a leftover user from one test must not silently make
    another test's "duplicate email" or "wrong password" assertion pass
    or fail for the wrong reason)."""
    with tempfile.TemporaryDirectory() as tmp_dir:
        db_path = os.path.join(tmp_dir, "test.db")
        test_engine = create_engine(
            f"sqlite:///{db_path}", connect_args={"check_same_thread": False}
        )
        SQLModel.metadata.create_all(test_engine)
        original_engine = db_module.engine
        db_module.engine = test_engine
        try:
            yield
        finally:
            db_module.engine = original_engine
            test_engine.dispose()


@pytest.fixture
def client() -> TestClient:
    return TestClient(app)


def _register(client: TestClient, email: str = "dr.test@example.com") -> dict:
    response = client.post(
        "/auth/register",
        json={"email": email, "full_name": "Dr. Test", "password": "correct-horse-battery"},
    )
    assert response.status_code == 201, response.text
    return response.json()


def test_register_creates_a_user(client: TestClient) -> None:
    body = _register(client)
    assert body["email"] == "dr.test@example.com"
    assert body["full_name"] == "Dr. Test"
    assert "password" not in body
    assert "hashed_password" not in body


def test_register_rejects_duplicate_email(client: TestClient) -> None:
    _register(client)
    response = client.post(
        "/auth/register",
        json={"email": "dr.test@example.com", "full_name": "Dr. Other", "password": "whatever123"},
    )
    assert response.status_code == 409


def test_login_with_correct_password_returns_a_token(client: TestClient) -> None:
    _register(client)
    response = client.post(
        "/auth/login",
        json={"email": "dr.test@example.com", "password": "correct-horse-battery"},
    )
    assert response.status_code == 200
    body = response.json()
    assert body["token_type"] == "bearer"
    assert len(body["access_token"]) > 20


def test_login_with_wrong_password_is_rejected(client: TestClient) -> None:
    _register(client)
    response = client.post(
        "/auth/login",
        json={"email": "dr.test@example.com", "password": "not-the-right-password"},
    )
    assert response.status_code == 401


def test_login_with_unknown_email_is_rejected(client: TestClient) -> None:
    response = client.post(
        "/auth/login",
        json={"email": "nobody@example.com", "password": "whatever123"},
    )
    assert response.status_code == 401


def test_me_requires_a_valid_token(client: TestClient) -> None:
    response = client.get("/auth/me")
    assert response.status_code == 401


def test_me_returns_the_logged_in_user(client: TestClient) -> None:
    _register(client)
    login_response = client.post(
        "/auth/login",
        json={"email": "dr.test@example.com", "password": "correct-horse-battery"},
    )
    token = login_response.json()["access_token"]

    response = client.get("/auth/me", headers={"Authorization": f"Bearer {token}"})

    assert response.status_code == 200
    assert response.json()["email"] == "dr.test@example.com"


def test_me_rejects_a_garbage_token(client: TestClient) -> None:
    response = client.get("/auth/me", headers={"Authorization": "Bearer not-a-real-token"})
    assert response.status_code == 401
