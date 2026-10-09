from pydantic import BaseModel, UUID4
from typing import Optional, List, Any
from datetime import datetime, date
import uuid


# ── Services ──────────────────────────────────────────────────────────────────

class SalonServiceBase(BaseModel):
    name: str
    description: Optional[str] = None
    category: str = "general"
    duration_minutes: int = 30
    price: float = 0.0
    is_active: bool = True


class SalonServiceCreate(SalonServiceBase):
    pass


class SalonServiceUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    category: Optional[str] = None
    duration_minutes: Optional[int] = None
    price: Optional[float] = None
    is_active: Optional[bool] = None


class SalonServiceOut(SalonServiceBase):
    id: uuid.UUID
    tenant_id: uuid.UUID
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


# ── Employees ─────────────────────────────────────────────────────────────────

class SalonEmployeeBase(BaseModel):
    first_name: str
    last_name: str
    phone: Optional[str] = None
    email: Optional[str] = None
    specialties: List[str] = []
    commission_rate: float = 0.0
    color: str = "#3ECF8E"
    is_active: bool = True


class SalonEmployeeCreate(SalonEmployeeBase):
    resource_id: Optional[uuid.UUID] = None


class SalonEmployeeUpdate(BaseModel):
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[str] = None
    specialties: Optional[List[str]] = None
    commission_rate: Optional[float] = None
    color: Optional[str] = None
    is_active: Optional[bool] = None


class SalonEmployeeOut(SalonEmployeeBase):
    id: uuid.UUID
    tenant_id: uuid.UUID
    resource_id: Optional[uuid.UUID]
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


# ── Clients ───────────────────────────────────────────────────────────────────

class SalonClientBase(BaseModel):
    first_name: str
    last_name: str
    phone: Optional[str] = None
    email: Optional[str] = None
    birthdate: Optional[date] = None
    notes: Optional[str] = None
    preferences: Optional[Any] = {}
    # FASE 25 — Ley 172-13: marca cuándo el cliente dio su consentimiento.
    consent_granted_at: Optional[datetime] = None


class SalonClientCreate(SalonClientBase):
    pass


class SalonClientUpdate(BaseModel):
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[str] = None
    birthdate: Optional[date] = None
    notes: Optional[str] = None
    preferences: Optional[Any] = None
    consent_granted_at: Optional[datetime] = None


class SalonClientOut(SalonClientBase):
    id: uuid.UUID
    tenant_id: uuid.UUID
    last_visit_date: Optional[date]
    total_visits: int
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


# ── Appointments (shared_agenda wrapper) ─────────────────────────────────────

class SalonAppointmentCreate(BaseModel):
    resource_id: uuid.UUID        # employee's agenda resource
    client_id: Optional[uuid.UUID] = None
    client_name: Optional[str] = None
    start_time: datetime
    end_time: datetime
    service_ids: List[uuid.UUID] = []
    notes: Optional[str] = None


class SalonAppointmentUpdate(BaseModel):
    status: Optional[str] = None
    notes: Optional[str] = None
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None


class SalonAppointmentOut(BaseModel):
    id: uuid.UUID
    resource_id: uuid.UUID
    client_id: Optional[uuid.UUID]
    client_name: Optional[str]
    start_time: datetime
    end_time: datetime
    status: str
    notes: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True


# ── Products (POS) ────────────────────────────────────────────────────────────

class SalonProductCreate(BaseModel):
    name: str
    sku: Optional[str] = None
    category: str = "general"
    price: float = 0.0
    stock_quantity: int = 0
    stock_alert_threshold: int = 5
    image_url: Optional[str] = None


class SalonProductUpdate(BaseModel):
    name: Optional[str] = None
    sku: Optional[str] = None
    category: Optional[str] = None
    price: Optional[float] = None
    stock_quantity: Optional[int] = None
    stock_alert_threshold: Optional[int] = None
    image_url: Optional[str] = None
    is_active: Optional[bool] = None


class SalonProductOut(SalonProductCreate):
    id: uuid.UUID
    tenant_id: uuid.UUID
    is_active: bool
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


# ── Sales (POS) ───────────────────────────────────────────────────────────────

class SalonSaleItemCreate(BaseModel):
    product_id: uuid.UUID
    quantity: int = 1
    unit_price: float = 0.0


class SalonSaleCreate(BaseModel):
    client_id: Optional[uuid.UUID] = None
    employee_id: Optional[uuid.UUID] = None     # estilista responsable → comisión
    payment_method: str = "cash"
    notes: Optional[str] = None
    items: List[SalonSaleItemCreate] = []


class SalonSaleOut(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    client_id: Optional[uuid.UUID]
    employee_id: Optional[uuid.UUID]
    total: float
    commission_amount: float
    payment_method: str
    sold_at: datetime
    notes: Optional[str]

    class Config:
        from_attributes = True


# ── Commissions ───────────────────────────────────────────────────────────────

class SalonCommissionOut(BaseModel):
    id: uuid.UUID
    sale_id: uuid.UUID
    employee_id: uuid.UUID
    amount: float
    rate: float
    created_at: datetime
    employee_name: Optional[str] = None         # nombre del estilista (join manual)


class SalonCommissionSummaryOut(BaseModel):
    employee_id: uuid.UUID
    employee_name: str
    sales_count: int
    total_sales: float
    total_commission: float


# ── Waitlist (lista de espera) ────────────────────────────────────────────────

class WaitlistEntryCreate(BaseModel):
    client_id: Optional[uuid.UUID] = None
    client_name: Optional[str] = None
    phone: Optional[str] = None
    service_name: Optional[str] = None
    notes: Optional[str] = None


class WaitlistEntryUpdate(BaseModel):
    status: Optional[str] = None
    notes: Optional[str] = None


class WaitlistEntryOut(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    client_id: Optional[uuid.UUID] = None
    client_name: str
    phone: Optional[str] = None
    service_name: Optional[str] = None
    notes: Optional[str] = None
    status: str
    created_at: datetime

    class Config:
        from_attributes = True
