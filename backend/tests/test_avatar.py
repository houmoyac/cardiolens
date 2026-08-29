from __future__ import annotations

from conftest import login_token as _login_token
from conftest import register as _register
from fastapi.testclient import TestClient


def _tiny_png_bytes() -> bytes:
    import cv2
    import numpy as np

    image = np.full((1, 1, 3), 255, dtype=np.uint8)
    ok, encoded = cv2.imencode(".png", image)
    assert ok
    return encoded.tobytes()


def test_upload_avatar_marks_has_avatar_true(client: TestClient) -> None:
    _register(client)
    token = _login_token(client)

    response = client.post(
        "/auth/me/avatar",
        files={"file": ("avatar.png", _tiny_png_bytes(), "image/png")},
        headers={"Authorization": f"Bearer {token}"},
    )

    assert response.status_code == 200, response.text
    assert response.json()["has_avatar"] is True


def test_get_avatar_returns_the_uploaded_image(client: TestClient) -> None:
    _register(client)
    token = _login_token(client)
    client.post(
        "/auth/me/avatar",
        files={"file": ("avatar.png", _tiny_png_bytes(), "image/png")},
        headers={"Authorization": f"Bearer {token}"},
    )

    response = client.get("/auth/me/avatar", headers={"Authorization": f"Bearer {token}"})

    assert response.status_code == 200
    assert response.headers["content-type"] == "image/png"
    assert len(response.content) > 0


def test_get_avatar_404s_when_nothing_uploaded(client: TestClient) -> None:
    _register(client)
    token = _login_token(client)

    response = client.get("/auth/me/avatar", headers={"Authorization": f"Bearer {token}"})

    assert response.status_code == 404


def test_upload_avatar_rejects_a_non_image_file(client: TestClient) -> None:
    _register(client)
    token = _login_token(client)

    response = client.post(
        "/auth/me/avatar",
        files={"file": ("not-an-image.txt", b"hello world", "text/plain")},
        headers={"Authorization": f"Bearer {token}"},
    )

    assert response.status_code == 422


def test_delete_avatar_removes_it(client: TestClient) -> None:
    _register(client)
    token = _login_token(client)
    client.post(
        "/auth/me/avatar",
        files={"file": ("avatar.png", _tiny_png_bytes(), "image/png")},
        headers={"Authorization": f"Bearer {token}"},
    )

    delete_response = client.delete(
        "/auth/me/avatar", headers={"Authorization": f"Bearer {token}"}
    )
    assert delete_response.status_code == 204

    get_response = client.get("/auth/me/avatar", headers={"Authorization": f"Bearer {token}"})
    assert get_response.status_code == 404


def test_avatar_endpoints_require_authentication(client: TestClient) -> None:
    assert client.get("/auth/me/avatar").status_code == 401
    assert client.delete("/auth/me/avatar").status_code == 401
    assert (
        client.post(
            "/auth/me/avatar", files={"file": ("avatar.png", _tiny_png_bytes(), "image/png")}
        ).status_code
        == 401
    )


def test_avatar_and_logo_are_independent(client: TestClient) -> None:
    """Uploading one must never affect the other — different people
    conceptually (the doctor vs. their workplace)."""
    _register(client)
    token = _login_token(client)

    client.post(
        "/auth/me/avatar",
        files={"file": ("avatar.png", _tiny_png_bytes(), "image/png")},
        headers={"Authorization": f"Bearer {token}"},
    )

    me = client.get("/auth/me", headers={"Authorization": f"Bearer {token}"}).json()
    assert me["has_avatar"] is True
    assert me["has_logo"] is False
