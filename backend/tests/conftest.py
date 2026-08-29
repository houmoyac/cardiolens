from __future__ import annotations

import os
import tempfile
from collections.abc import Generator
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from sqlmodel import SQLModel, create_engine

import cardiolens.avatar_storage as avatar_storage_module
import cardiolens.db as db_module
import cardiolens.logo_storage as logo_storage_module

# Importing the app here (not lazily inside a fixture) matters: it's what
# registers the User/AnalysisRecord tables on SQLModel.metadata before
# isolated_db's create_all() runs below — importing it later left the
# fixture creating tables for a metadata that didn't know about them yet.
from cardiolens.api import app


@pytest.fixture(autouse=True)
def isolated_logo_storage(tmp_path: Path) -> Generator[None, None, None]:
    """Never write test logos/avatars into the real (gitignored, but still
    local and potentially populated) user_logos//user_avatars/ dirs."""
    original_logos_dir = logo_storage_module.LOGOS_DIR
    original_avatars_dir = avatar_storage_module.AVATARS_DIR
    logo_storage_module.LOGOS_DIR = tmp_path / "user_logos"
    avatar_storage_module.AVATARS_DIR = tmp_path / "user_avatars"
    try:
        yield
    finally:
        logo_storage_module.LOGOS_DIR = original_logos_dir
        avatar_storage_module.AVATARS_DIR = original_avatars_dir


@pytest.fixture(autouse=True)
def isolated_db() -> Generator[None, None, None]:
    """Each test gets its own throwaway SQLite file — never share state
    between tests (a leftover user/case from one test must not silently
    make another test's assertion pass or fail for the wrong reason)."""
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


def register(client: TestClient, email: str = "dr.test@example.com") -> dict:
    response = client.post(
        "/auth/register",
        json={
            "email": email,
            "first_name": "Test",
            "last_name": "Dupont",
            "password": "correct-horse-battery",
        },
    )
    assert response.status_code == 201, response.text
    return response.json()


def login_token(client: TestClient, email: str = "dr.test@example.com") -> str:
    response = client.post(
        "/auth/login",
        json={"email": email, "password": "correct-horse-battery"},
    )
    return response.json()["access_token"]  # type: ignore[no-any-return]
