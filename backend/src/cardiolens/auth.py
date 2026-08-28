from __future__ import annotations

import os
from datetime import UTC, datetime, timedelta

import bcrypt
import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlmodel import Session

from cardiolens.auth_models import User
from cardiolens.db import get_session

# Dev-only fallback — a real deployment MUST set CARDIOLENS_JWT_SECRET to
# a real secret (see ARCHITECTURE.md). Never silently ship this default
# to anything but a local/dev instance; there is no way for this module
# to enforce that itself, so it's a deployment-checklist item, not code.
JWT_SECRET = os.environ.get("CARDIOLENS_JWT_SECRET", "dev-only-insecure-secret-change-me")
JWT_ALGORITHM = "HS256"
TOKEN_EXPIRY = timedelta(days=30)  # a doctor's own phone — long-lived, not a shared kiosk

_oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")


def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()


def verify_password(password: str, hashed: str) -> bool:
    return bcrypt.checkpw(password.encode(), hashed.encode())


def create_access_token(user_id: int) -> str:
    payload = {"sub": str(user_id), "exp": datetime.now(UTC) + TOKEN_EXPIRY}
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


def get_current_user(
    token: str = Depends(_oauth2_scheme),
    session: Session = Depends(get_session),
) -> User:
    credentials_error = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Identifiants invalides ou expirés.",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        user_id = int(payload["sub"])
    except (jwt.PyJWTError, KeyError, ValueError) as exc:
        raise credentials_error from exc

    user = session.get(User, user_id)
    if user is None:
        raise credentials_error
    return user
