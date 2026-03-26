import os
from collections.abc import AsyncGenerator

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase

DATABASE_URL = os.environ["DATABASE_URL"]  # e.g. postgresql+asyncpg://user:pass@host/db

engine = create_async_engine(DATABASE_URL, echo=False)
AsyncSessionLocal = async_sessionmaker(engine, expire_on_commit=False)


class Base(DeclarativeBase):
    pass


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with AsyncSessionLocal() as session:
        yield session


async def init_db() -> None:
    """Create tables on startup if they don't exist."""
    async with engine.begin() as conn:
        await conn.execute(text("""
            CREATE TABLE IF NOT EXISTS telemetry (
                id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                device_id   TEXT NOT NULL,
                value       DOUBLE PRECISION NOT NULL,
                timestamp   TIMESTAMPTZ NOT NULL,
                created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
            )
        """))
