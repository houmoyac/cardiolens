"""Per-doctor workplace logo storage — one small PNG per account, shown on
the report header. Not patient data (never contains a patient's identity),
but still not something to commit: it's the doctor's own uploaded content,
kept in a gitignored local directory the same way the SQLite account DB is.
"""

from __future__ import annotations

import os
from pathlib import Path

import cv2
import numpy as np

LOGOS_DIR = Path(os.environ.get("CARDIOLENS_LOGOS_DIR", "user_logos"))

# Report headers are small — no reason to store or serve anything bigger
# than this, whatever resolution a phone photo of a logo comes in at.
MAX_DIMENSION_PX = 512


class InvalidLogoError(Exception):
    pass


def _logo_path(user_id: int) -> Path:
    return LOGOS_DIR / f"{user_id}.png"


def has_logo(user_id: int) -> bool:
    return _logo_path(user_id).exists()


def save_logo(user_id: int, raw_bytes: bytes) -> None:
    array = np.frombuffer(raw_bytes, dtype=np.uint8)
    image = cv2.imdecode(array, cv2.IMREAD_UNCHANGED)
    if image is None:
        raise InvalidLogoError("Fichier image invalide.")

    height, width = image.shape[:2]
    scale = MAX_DIMENSION_PX / max(height, width)
    if scale < 1:
        image = cv2.resize(
            image,
            (round(width * scale), round(height * scale)),
            interpolation=cv2.INTER_AREA,
        )

    LOGOS_DIR.mkdir(parents=True, exist_ok=True)
    cv2.imwrite(str(_logo_path(user_id)), image)


def load_logo_bytes(user_id: int) -> bytes | None:
    path = _logo_path(user_id)
    if not path.exists():
        return None
    return path.read_bytes()


def delete_logo(user_id: int) -> None:
    _logo_path(user_id).unlink(missing_ok=True)
