import uuid
from datetime import datetime

from pydantic import BaseModel, Field
from sqlalchemy import DateTime, Double, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


# --------------------------------------------------------------------------- #
# SQLAlchemy ORM model                                                         #
# --------------------------------------------------------------------------- #

class TelemetryRecord(Base):
    __tablename__ = "telemetry"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    device_id: Mapped[str] = mapped_column(Text, nullable=False)
    value: Mapped[float] = mapped_column(Double, nullable=False)
    timestamp: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=datetime.utcnow
    )


# --------------------------------------------------------------------------- #
# Pydantic schemas                                                             #
# --------------------------------------------------------------------------- #

class TelemetryCreate(BaseModel):
    device_id: str = Field(..., description="Unique identifier for the source device")
    value: float = Field(..., description="Sensor reading value")
    timestamp: datetime = Field(..., description="ISO-8601 timestamp of the reading")


class TelemetryResponse(BaseModel):
    id: uuid.UUID
    device_id: str
    value: float
    timestamp: datetime
    created_at: datetime

    model_config = {"from_attributes": True}
