from __future__ import annotations

import os
from collections.abc import Generator

from sqlmodel import Session, SQLModel, create_engine

# SQLite for now — deliberately simple, matches the project's "solid
# foundation, don't over-build" stance. A real deployment (see
# ARCHITECTURE.md's deferred-deployment note) is the natural point to
# reconsider Postgres, not before.
DB_PATH = os.environ.get("CARDIOLENS_DB_PATH", "cardiolens.db")
DATABASE_URL = f"sqlite:///{DB_PATH}"

engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})


def init_db() -> None:
    SQLModel.metadata.create_all(engine)


def get_session() -> Generator[Session, None, None]:
    with Session(engine) as session:
        yield session
