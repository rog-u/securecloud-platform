import logging
import os
import uuid
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, Header, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db, init_db
from app.models import TelemetryCreate, TelemetryRecord, TelemetryResponse

logger = logging.getLogger("telemetry")
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")

API_KEY = os.environ["API_KEY"]


# --------------------------------------------------------------------------- #
# Startup / shutdown                                                           #
# --------------------------------------------------------------------------- #

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Initializing database schema")
    await init_db()
    yield


app = FastAPI(
    title="Telemetry Ingestion API",
    description="Receives and serves mission sensor readings.",
    version="0.1.0",
    lifespan=lifespan,
)


# --------------------------------------------------------------------------- #
# Auth dependency                                                              #
# --------------------------------------------------------------------------- #

async def require_api_key(x_api_key: str = Header(..., alias="X-API-Key")) -> None:
    if x_api_key != API_KEY:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Invalid or missing API key",
        )


# --------------------------------------------------------------------------- #
# Routes                                                                       #
# --------------------------------------------------------------------------- #

@app.get("/health", tags=["ops"])
async def health():
    """Liveness probe — no auth required."""
    return {"status": "ok"}


@app.post(
    "/telemetry",
    response_model=TelemetryResponse,
    status_code=status.HTTP_201_CREATED,
    tags=["telemetry"],
    dependencies=[Depends(require_api_key)],
)
async def ingest(payload: TelemetryCreate, db: AsyncSession = Depends(get_db)):
    """Ingest a sensor reading."""
    record = TelemetryRecord(
        device_id=payload.device_id,
        value=payload.value,
        timestamp=payload.timestamp,
    )
    db.add(record)
    await db.commit()
    await db.refresh(record)
    logger.info("Ingested reading id=%s device=%s", record.id, record.device_id)
    return record


@app.get(
    "/telemetry/{record_id}",
    response_model=TelemetryResponse,
    tags=["telemetry"],
    dependencies=[Depends(require_api_key)],
)
async def retrieve(record_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    """Retrieve a stored reading by ID."""
    result = await db.execute(
        select(TelemetryRecord).where(TelemetryRecord.id == record_id)
    )
    record = result.scalar_one_or_none()
    if record is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Record not found")
    return record
