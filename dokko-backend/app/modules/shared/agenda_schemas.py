from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime, date, time


# ── Resources ─────────────────────────────────────────────────────────────────
class AgendaResourceCreate(BaseModel):
    name: str
    type: str  # 'employee', 'room', etc
    reference_id: Optional[str] = None
    is_active: Optional[bool] = True

class AgendaResourceUpdate(BaseModel):
    name: Optional[str] = None
    type: Optional[str] = None
    reference_id: Optional[str] = None
    is_active: Optional[bool] = None

class AgendaResourceOut(AgendaResourceCreate):
    id: str
    tenant_id: str
    created_at: datetime
    updated_at: datetime


# ── Availability ──────────────────────────────────────────────────────────────
class AgendaAvailabilityCreate(BaseModel):
    resource_id: str
    day_of_week: int
    start_time: time
    end_time: time

class AgendaAvailabilityOut(AgendaAvailabilityCreate):
    id: str
    tenant_id: str


# ── Exceptions ────────────────────────────────────────────────────────────────
class AgendaExceptionCreate(BaseModel):
    resource_id: str
    date: date
    is_working: bool
    start_time: Optional[time] = None
    end_time: Optional[time] = None
    notes: Optional[str] = None

class AgendaExceptionOut(AgendaExceptionCreate):
    id: str
    tenant_id: str


# ── Appointments ──────────────────────────────────────────────────────────────
class AgendaAppointmentCreate(BaseModel):
    resource_id: str
    client_name: Optional[str] = None
    client_id: Optional[str] = None
    start_time: datetime
    end_time: datetime
    status: Optional[str] = "scheduled"
    module_reference: Optional[str] = None
    notes: Optional[str] = None

class AgendaAppointmentUpdate(BaseModel):
    resource_id: Optional[str] = None
    client_name: Optional[str] = None
    client_id: Optional[str] = None
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None
    status: Optional[str] = None
    module_reference: Optional[str] = None
    notes: Optional[str] = None

class AgendaAppointmentOut(AgendaAppointmentCreate):
    id: str
    tenant_id: str
    created_at: datetime
    updated_at: datetime
