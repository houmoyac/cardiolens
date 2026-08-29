from __future__ import annotations

import hashlib
import os
import secrets
from datetime import UTC, datetime, timedelta

import bcrypt
import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlmodel import Session, select

from cardiolens.auth_models import PasswordResetToken, User
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


_optional_oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login", auto_error=False)


def get_current_user_optional(
    token: str | None = Depends(_optional_oauth2_scheme),
    session: Session = Depends(get_session),
) -> User | None:
    """Same as get_current_user, but returns None instead of raising when
    no (or an invalid) token is given — for endpoints like /analyze that
    work whether or not the caller is logged in, but behave differently
    when they are (saving to that doctor's history)."""
    if token is None:
        return None
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        user_id = int(payload["sub"])
    except (jwt.PyJWTError, KeyError, ValueError):
        return None
    return session.get(User, user_id)


RESET_TOKEN_EXPIRY = timedelta(minutes=30)  # short-lived on purpose — unlike the login JWT


def _hash_reset_token(raw_token: str) -> str:
    return hashlib.sha256(raw_token.encode()).hexdigest()


def create_password_reset_token(user_id: int, session: Session) -> str:
    raw_token = secrets.token_urlsafe(32)
    session.add(
        PasswordResetToken(
            user_id=user_id,
            token_hash=_hash_reset_token(raw_token),
            expires_at=datetime.now(UTC) + RESET_TOKEN_EXPIRY,
        )
    )
    session.commit()
    return raw_token


def consume_password_reset_token(raw_token: str, session: Session) -> User | None:
    """Verifies and immediately deletes the token — single use, whether or
    not the reset that follows actually succeeds."""
    record = session.exec(
        select(PasswordResetToken).where(
            PasswordResetToken.token_hash == _hash_reset_token(raw_token)
        )
    ).first()
    if record is None:
        return None
    session.delete(record)
    session.commit()

    # SQLite has no native timezone-aware storage — SQLAlchemy round-trips
    # a tz-aware datetime as naive, so a straight comparison against
    # datetime.now(UTC) below would raise. Re-attach UTC before comparing.
    expires_at = record.expires_at
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=UTC)
    if expires_at < datetime.now(UTC):
        return None
    return session.get(User, record.user_id)
