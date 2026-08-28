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
    hashed_password: str
    created_at: datetime = Field(default_factory=lambda: datetime.now(UTC))


class UserRegister(BaseModel):
    email: EmailStr
    first_name: str
    last_name: str
    password: str


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class UserPublic(BaseModel):
    id: int
    email: str
    first_name: str
    last_name: str


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"
