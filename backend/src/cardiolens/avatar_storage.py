"""Per-doctor personal profile photo storage — mirrors logo_storage.py
(same reasoning: doctor's own uploaded content, gitignored local
directory) but keyed separately since a workplace logo and a personal
photo are conceptually different and a doctor may set either, both, or
neither.
"""

from __future__ import annotations

import os
from pathlib import Path

import cv2
import numpy as np

AVATARS_DIR = Path(os.environ.get("CARDIOLENS_AVATARS_DIR", "user_avatars"))

MAX_DIMENSION_PX = 512


class InvalidAvatarError(Exception):
    pass


def _avatar_path(user_id: int) -> Path:
    return AVATARS_DIR / f"{user_id}.png"


def has_avatar(user_id: int) -> bool:
    return _avatar_path(user_id).exists()


def save_avatar(user_id: int, raw_bytes: bytes) -> None:
    array = np.frombuffer(raw_bytes, dtype=np.uint8)
    image = cv2.imdecode(array, cv2.IMREAD_UNCHANGED)
    if image is None:
        raise InvalidAvatarError("Fichier image invalide.")

    height, width = image.shape[:2]
    scale = MAX_DIMENSION_PX / max(height, width)
    if scale < 1:
        image = cv2.resize(
            image,
            (round(width * scale), round(height * scale)),
            interpolation=cv2.INTER_AREA,
        )

    AVATARS_DIR.mkdir(parents=True, exist_ok=True)
    cv2.imwrite(str(_avatar_path(user_id)), image)


def load_avatar_bytes(user_id: int) -> bytes | None:
    path = _avatar_path(user_id)
    if not path.exists():
        return None
    return path.read_bytes()


def delete_avatar(user_id: int) -> None:
    _avatar_path(user_id).unlink(missing_ok=True)
