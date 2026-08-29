from __future__ import annotations

from datetime import UTC, datetime

from pydantic import BaseModel, EmailStr
from sqlmodel import Field, SQLModel


class User(SQLModel, table=True):
    """One doctor, one account, one device — see ARCHITECTURE.md for why
    that's the target model (not shared logins), and why a full account
    system was brought forward from "later" once a real gap showed up:
    without knowing who's signed in, a validated report can't honestly
    say who validated it."""

    id: int | None = Field(default=None, primary_key=True)
    email: str = Field(unique=True, index=True)
    first_name: str
    last_name: str
    workplace: str | None = None
    professional_title: str | None = None
    """Free text — a fixed enum couldn't cover every real title/grade
    across countries and institutions (see PROFESSIONAL_TITLE_PRESETS),
    so the mobile app offers presets plus an "Autre" free-text option,
    and the backend stores whatever comes through. Never validated
    against a closed list here — that would just reject a legitimate
    title the preset list didn't anticipate."""
    hashed_password: str
    created_at: datetime = Field(default_factory=lambda: datetime.now(UTC))


class UserRegister(BaseModel):
    email: EmailStr
    first_name: str
    last_name: str
    password: str
    workplace: str | None = None
    professional_title: str | None = None


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class UserPublic(BaseModel):
    id: int
    email: str
    first_name: str
    last_name: str
    workplace: str | None
    professional_title: str | None
    has_logo: bool


class UserProfileUpdate(BaseModel):
    workplace: str | None = None
    professional_title: str | None = None


class UserPasswordChange(BaseModel):
    current_password: str
    new_password: str


class PasswordResetToken(SQLModel, table=True):
    """Short-lived, single-use token for the "forgot password" flow.
    token_hash, not the raw token, is stored — same reasoning as hashing
    account passwords: a DB read/leak must not hand out usable tokens."""

    id: int | None = Field(default=None, primary_key=True)
    user_id: int = Field(foreign_key="user.id", index=True)
    token_hash: str = Field(index=True, unique=True)
    expires_at: datetime


class ForgotPasswordRequest(BaseModel):
    email: EmailStr


class ResetPasswordRequest(BaseModel):
    token: str
    new_password: str


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"
