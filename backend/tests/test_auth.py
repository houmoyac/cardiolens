from __future__ import annotations

from conftest import login_token as _login_token
from conftest import register as _register
from fastapi.testclient import TestClient


def test_register_creates_a_user(client: TestClient) -> None:
    body = _register(client)
    assert body["email"] == "dr.test@example.com"
    assert body["first_name"] == "Test"
    assert body["last_name"] == "Dupont"
    assert body["has_logo"] is False
    assert body["has_avatar"] is False
    assert "password" not in body
    assert "hashed_password" not in body


def test_register_rejects_duplicate_email(client: TestClient) -> None:
    _register(client)
    response = client.post(
        "/auth/register",
        json={
            "email": "dr.test@example.com",
            "first_name": "Other",
            "last_name": "Martin",
            "password": "whatever123",
        },
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
    token = _login_token(client)

    response = client.get("/auth/me", headers={"Authorization": f"Bearer {token}"})

    assert response.status_code == 200
    assert response.json()["email"] == "dr.test@example.com"


def test_me_rejects_a_garbage_token(client: TestClient) -> None:
    response = client.get("/auth/me", headers={"Authorization": "Bearer not-a-real-token"})
    assert response.status_code == 401


def test_register_accepts_an_optional_workplace(client: TestClient) -> None:
    response = client.post(
        "/auth/register",
        json={
            "email": "dr.workplace@example.com",
            "first_name": "Test",
            "last_name": "Dupont",
            "password": "correct-horse-battery",
            "workplace": "Cabinet Saint-Michel",
        },
    )
    assert response.status_code == 201, response.text
    assert response.json()["workplace"] == "Cabinet Saint-Michel"


def test_register_without_workplace_leaves_it_null(client: TestClient) -> None:
    body = _register(client)
    assert body["workplace"] is None
    assert body["professional_title"] is None


def test_register_accepts_an_optional_professional_title(client: TestClient) -> None:
    response = client.post(
        "/auth/register",
        json={
            "email": "dr.title@example.com",
            "first_name": "Test",
            "last_name": "Dupont",
            "password": "correct-horse-battery",
            "professional_title": "Maître assistant",
        },
    )
    assert response.status_code == 201, response.text
    assert response.json()["professional_title"] == "Maître assistant"


def test_update_profile_sets_the_workplace(client: TestClient) -> None:
    _register(client)
    token = _login_token(client)

    response = client.patch(
        "/auth/me",
        json={"workplace": "Hôpital Nord"},
        headers={"Authorization": f"Bearer {token}"},
    )

    assert response.status_code == 200
    assert response.json()["workplace"] == "Hôpital Nord"

    # And it sticks — /auth/me reflects the update, not just the PATCH response.
    me_response = client.get("/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert me_response.json()["workplace"] == "Hôpital Nord"


def test_update_profile_sets_the_professional_title(client: TestClient) -> None:
    _register(client)
    token = _login_token(client)

    response = client.patch(
        "/auth/me",
        json={"professional_title": "Professeur"},
        headers={"Authorization": f"Bearer {token}"},
    )

    assert response.status_code == 200
    assert response.json()["professional_title"] == "Professeur"


def test_update_profile_requires_authentication(client: TestClient) -> None:
    response = client.patch("/auth/me", json={"workplace": "Hôpital Nord"})
    assert response.status_code == 401


def _tiny_png_bytes() -> bytes:
    # A 1x1 white PNG — enough to exercise decode/resize/save without
    # depending on a real image file on disk.
    import cv2
    import numpy as np

    image = np.full((1, 1, 3), 255, dtype=np.uint8)
    ok, encoded = cv2.imencode(".png", image)
    assert ok
    return encoded.tobytes()


def test_upload_logo_marks_has_logo_true(client: TestClient) -> None:
    _register(client)
    token = _login_token(client)

    response = client.post(
        "/auth/me/logo",
        files={"file": ("logo.png", _tiny_png_bytes(), "image/png")},
        headers={"Authorization": f"Bearer {token}"},
    )

    assert response.status_code == 200, response.text
    assert response.json()["has_logo"] is True


def test_get_logo_returns_the_uploaded_image(client: TestClient) -> None:
    _register(client)
    token = _login_token(client)
    client.post(
        "/auth/me/logo",
        files={"file": ("logo.png", _tiny_png_bytes(), "image/png")},
        headers={"Authorization": f"Bearer {token}"},
    )

    response = client.get("/auth/me/logo", headers={"Authorization": f"Bearer {token}"})

    assert response.status_code == 200
    assert response.headers["content-type"] == "image/png"
    assert len(response.content) > 0


def test_get_logo_404s_when_nothing_uploaded(client: TestClient) -> None:
    _register(client)
    token = _login_token(client)

    response = client.get("/auth/me/logo", headers={"Authorization": f"Bearer {token}"})

    assert response.status_code == 404


def test_upload_logo_rejects_a_non_image_file(client: TestClient) -> None:
    _register(client)
    token = _login_token(client)

    response = client.post(
        "/auth/me/logo",
        files={"file": ("not-an-image.txt", b"hello world", "text/plain")},
        headers={"Authorization": f"Bearer {token}"},
    )

    assert response.status_code == 422


def test_delete_logo_removes_it(client: TestClient) -> None:
    _register(client)
    token = _login_token(client)
    client.post(
        "/auth/me/logo",
        files={"file": ("logo.png", _tiny_png_bytes(), "image/png")},
        headers={"Authorization": f"Bearer {token}"},
    )

    delete_response = client.delete(
        "/auth/me/logo", headers={"Authorization": f"Bearer {token}"}
    )
    assert delete_response.status_code == 204

    get_response = client.get("/auth/me/logo", headers={"Authorization": f"Bearer {token}"})
    assert get_response.status_code == 404


def test_change_password_then_login_with_new_password(client: TestClient) -> None:
    _register(client)
    token = _login_token(client)

    response = client.post(
        "/auth/me/password",
        json={"current_password": "correct-horse-battery", "new_password": "new-password-123"},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 204

    old_login = client.post(
        "/auth/login",
        json={"email": "dr.test@example.com", "password": "correct-horse-battery"},
    )
    assert old_login.status_code == 401

    new_login = client.post(
        "/auth/login",
        json={"email": "dr.test@example.com", "password": "new-password-123"},
    )
    assert new_login.status_code == 200


def test_change_password_rejects_wrong_current_password(client: TestClient) -> None:
    _register(client)
    token = _login_token(client)

    response = client.post(
        "/auth/me/password",
        json={"current_password": "not-the-right-one", "new_password": "new-password-123"},
        headers={"Authorization": f"Bearer {token}"},
    )

    assert response.status_code == 401


def test_change_password_requires_authentication(client: TestClient) -> None:
    response = client.post(
        "/auth/me/password",
        json={"current_password": "whatever", "new_password": "new-password-123"},
    )
    assert response.status_code == 401


def test_logo_endpoints_require_authentication(client: TestClient) -> None:
    assert client.get("/auth/me/logo").status_code == 401
    assert client.delete("/auth/me/logo").status_code == 401
    assert (
        client.post(
            "/auth/me/logo", files={"file": ("logo.png", _tiny_png_bytes(), "image/png")}
        ).status_code
        == 401
    )
