from pydantic import BaseModel, Field
from typing import Optional
from datetime import date, datetime
from decimal import Decimal
import uuid


# ── Membership Plans ──────────────────────────────────────────────────────────
class GymMembershipPlanCreate(BaseModel):
    name: str
    price: Decimal
    duration_days: int
    is_active: bool = True


class GymMembershipPlanUpdate(BaseModel):
    name: Optional[str] = None
    price: Optional[Decimal] = None
    duration_days: Optional[int] = None
    is_active: Optional[bool] = None


class GymMembershipPlanOut(GymMembershipPlanCreate):
    id: uuid.UUID
    tenant_id: uuid.UUID
    created_at: datetime


# ── Members ───────────────────────────────────────────────────────────────────
class GymMemberCreate(BaseModel):
    first_name: str
    last_name: str
    email: Optional[str] = None
    phone: Optional[str] = None
    id_number: Optional[str] = None
    photo_url: Optional[str] = None
    notes: Optional[str] = None
    # FASE 25 — Ley 172-13: marca cuándo el cliente dio su consentimiento.
    consent_granted_at: Optional[datetime] = None


class GymMemberUpdate(BaseModel):
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    email: Optional[str] = None
    phone: Optional[str] = None
    id_number: Optional[str] = None
    notes: Optional[str] = None
    consent_granted_at: Optional[datetime] = None
    status: Optional[str] = None


class GymMemberOut(GymMemberCreate):
    id: uuid.UUID
    tenant_id: uuid.UUID
    status: str
    membership_expires_at: Optional[date] = None
    created_at: datetime


# ── Membership Payments ───────────────────────────────────────────────────────
class GymPaymentCreate(BaseModel):
    member_id: uuid.UUID
    plan_id: Optional[uuid.UUID] = None
    amount: Decimal
    payment_method: str = "cash"
    valid_from: date
    valid_until: date
    notes: Optional[str] = None


class GymPaymentOut(GymPaymentCreate):
    id: uuid.UUID
    tenant_id: uuid.UUID
    paid_at: datetime


# ── Check-ins ─────────────────────────────────────────────────────────────────
class GymCheckinCreate(BaseModel):
    member_id: uuid.UUID
    notes: Optional[str] = None


class GymCheckinOut(BaseModel):
    model_config = {"extra": "allow"}

    id: uuid.UUID
    tenant_id: uuid.UUID
    member_id: uuid.UUID
    checked_in_at: datetime
    notes: Optional[str] = None
    gym_members: Optional[dict] = None


# ── Products ──────────────────────────────────────────────────────────────────
class GymProductCreate(BaseModel):
    name: str
    sku: Optional[str] = None
    category: str = "general"
    price: Decimal
    stock_quantity: int = 0
    stock_alert_threshold: int = 5
    image_url: Optional[str] = None


class GymProductUpdate(BaseModel):
    name: Optional[str] = None
    sku: Optional[str] = None
    category: Optional[str] = None
    price: Optional[Decimal] = None
    stock_quantity: Optional[int] = None
    stock_alert_threshold: Optional[int] = None
    image_url: Optional[str] = None


class GymProductOut(GymProductCreate):
    id: uuid.UUID
    tenant_id: uuid.UUID
    is_active: bool
    created_at: datetime


# ── Sales ─────────────────────────────────────────────────────────────────────
class SaleItemCreate(BaseModel):
    product_id: uuid.UUID
    quantity: int = 1
    unit_price: Decimal


class GymSaleCreate(BaseModel):
    member_id: Optional[uuid.UUID] = None
    payment_method: str = "cash"
    notes: Optional[str] = None
    items: list[SaleItemCreate] = Field(min_length=1)


class GymSaleOut(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    member_id: Optional[uuid.UUID] = None
    total: Decimal
    payment_method: str
    sold_at: datetime
    notes: Optional[str] = None


# ── Dashboard KPIs ────────────────────────────────────────────────────────────
class GymDashboardKpisOut(BaseModel):
    active_members_count: int
    monthly_revenue: Decimal
    upcoming_expirations_count: int
    checkins_today: int


# ── Churn / Revenue Recovery ──────────────────────────────────────────────────
class GymChurnMemberOut(BaseModel):
    member_id: uuid.UUID
    first_name: str
    last_name: str
    membership_expires_at: Optional[date] = None
    last_checkin_at: Optional[datetime] = None
    days_since_last_checkin: Optional[int] = None
    days_until_expiry: Optional[int] = None
    risk_level: str  # 'alto' | 'medio'
    reasons: list[str]


class GymChurnMetricPoint(BaseModel):
    month: str  # 'YYYY-MM'
    churned: int
    active_end: int
    churn_rate: float  # 0-100


class GymChurnOverview(BaseModel):
    at_risk: list[GymChurnMemberOut]
    at_risk_count: int
    active_members_count: int
    churn_rate_6m: float
    months: list[GymChurnMetricPoint]


# ── Employees ─────────────────────────────────────────────────────────────────
class GymEmployeeCreate(BaseModel):
    first_name: str
    last_name: str
    role: str = "entrenador"
    phone: Optional[str] = None
    email: Optional[str] = None


class GymEmployeeUpdate(BaseModel):
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    role: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[str] = None
    is_active: Optional[bool] = None


class GymEmployeeOut(GymEmployeeCreate):
    id: uuid.UUID
    tenant_id: uuid.UUID
    is_active: bool
    created_at: datetime
    updated_at: datetime


# ── Gym Settings ──────────────────────────────────────────────────────────────
class GymSettingsUpdate(BaseModel):
    gym_name: Optional[str] = None
    address: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[str] = None
    website: Optional[str] = None
    capacity: Optional[int] = None
    currency: Optional[str] = None
    timezone: Optional[str] = None
    hours: Optional[dict] = None


class GymSettingsOut(GymSettingsUpdate):
    model_config = {"extra": "allow"}
    tenant_id: Optional[str] = None
    updated_at: Optional[datetime] = None

