from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
from decimal import Decimal

# ── Agents ────────────────────────────────────────────────────────────────────
class RealEstateAgentCreate(BaseModel):
    user_id: Optional[str] = None
    first_name: str
    last_name: str
    phone: Optional[str] = None
    email: Optional[str] = None
    commission_rate: Optional[Decimal] = Decimal('0.00')
    is_active: Optional[bool] = True

class RealEstateAgentUpdate(BaseModel):
    user_id: Optional[str] = None
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[str] = None
    commission_rate: Optional[Decimal] = None
    is_active: Optional[bool] = None

class RealEstateAgentOut(RealEstateAgentCreate):
    id: str
    tenant_id: str
    created_at: datetime
    updated_at: datetime

# ── Properties ────────────────────────────────────────────────────────────────
class RealEstatePropertyCreate(BaseModel):
    title: str
    description: Optional[str] = None
    property_type: str
    operation_type: str
    status: Optional[str] = "available"
    price_sale: Optional[Decimal] = None
    price_rent: Optional[Decimal] = None
    currency: Optional[str] = "USD"
    hoa_fee: Optional[Decimal] = None
    property_tax: Optional[Decimal] = None
    bedrooms: Optional[int] = 0
    bathrooms: Optional[Decimal] = Decimal('0.0')
    parking_spots: Optional[int] = 0
    square_meters_built: Optional[Decimal] = None
    square_meters_land: Optional[Decimal] = None
    year_built: Optional[int] = None
    address: Optional[str] = None
    city: Optional[str] = None
    state: Optional[str] = None
    zip_code: Optional[str] = None
    country: Optional[str] = None
    latitude: Optional[Decimal] = None
    longitude: Optional[Decimal] = None
    images: Optional[List[str]] = []
    features: Optional[List[str]] = []
    mls_id: Optional[str] = None
    virtual_tour_url: Optional[str] = None
    assigned_agent_id: Optional[str] = None
    owner_name: Optional[str] = None
    owner_phone: Optional[str] = None

class RealEstatePropertyUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    property_type: Optional[str] = None
    operation_type: Optional[str] = None
    status: Optional[str] = None
    price_sale: Optional[Decimal] = None
    price_rent: Optional[Decimal] = None
    currency: Optional[str] = None
    hoa_fee: Optional[Decimal] = None
    property_tax: Optional[Decimal] = None
    bedrooms: Optional[int] = None
    bathrooms: Optional[Decimal] = None
    parking_spots: Optional[int] = None
    square_meters_built: Optional[Decimal] = None
    square_meters_land: Optional[Decimal] = None
    year_built: Optional[int] = None
    address: Optional[str] = None
    city: Optional[str] = None
    state: Optional[str] = None
    zip_code: Optional[str] = None
    country: Optional[str] = None
    latitude: Optional[Decimal] = None
    longitude: Optional[Decimal] = None
    images: Optional[List[str]] = None
    features: Optional[List[str]] = None
    mls_id: Optional[str] = None
    virtual_tour_url: Optional[str] = None
    assigned_agent_id: Optional[str] = None
    owner_name: Optional[str] = None
    owner_phone: Optional[str] = None

class RealEstatePropertyOut(RealEstatePropertyCreate):
    id: str
    tenant_id: str
    created_at: datetime
    updated_at: datetime

# ── Leads ─────────────────────────────────────────────────────────────────────
class RealEstateLeadCreate(BaseModel):
    first_name: str
    last_name: str
    phone: Optional[str] = None
    email: Optional[str] = None
    source: Optional[str] = None
    status: Optional[str] = "new"
    interested_in: Optional[str] = None
    budget_min: Optional[Decimal] = None
    budget_max: Optional[Decimal] = None
    preferred_cities: Optional[List[str]] = []
    min_bedrooms: Optional[int] = None
    assigned_agent_id: Optional[str] = None
    interested_property_id: Optional[str] = None
    notes: Optional[str] = None
    consent_granted_at: Optional[datetime] = None


class RealEstateLeadUpdate(BaseModel):
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[str] = None
    source: Optional[str] = None
    status: Optional[str] = None
    interested_in: Optional[str] = None
    budget_min: Optional[Decimal] = None
    budget_max: Optional[Decimal] = None
    preferred_cities: Optional[List[str]] = None
    min_bedrooms: Optional[int] = None
    assigned_agent_id: Optional[str] = None
    interested_property_id: Optional[str] = None
    notes: Optional[str] = None
    consent_granted_at: Optional[datetime] = None


class RealEstateLeadOut(RealEstateLeadCreate):
    id: str
    tenant_id: str
    created_at: datetime
    updated_at: datetime

# ── Dossiers ──────────────────────────────────────────────────────────────────
class RealEstateDossierCreate(BaseModel):
    property_id: Optional[str] = None
    lead_id: Optional[str] = None
    file_url: str

class RealEstateDossierOut(RealEstateDossierCreate):
    id: str
    tenant_id: str
    created_at: datetime

# ── Commissions ───────────────────────────────────────────────────────────────
class RealEstateCommissionCreate(BaseModel):
    property_id: str
    lead_id: Optional[str] = None
    agent_id: str
    amount: Decimal
    status: Optional[str] = "pending"
    closed_at: Optional[datetime] = None
    notes: Optional[str] = None

class RealEstateCommissionUpdate(BaseModel):
    property_id: Optional[str] = None
    lead_id: Optional[str] = None
    agent_id: Optional[str] = None
    amount: Optional[Decimal] = None
    status: Optional[str] = None
    closed_at: Optional[datetime] = None
    notes: Optional[str] = None

class RealEstateCommissionOut(RealEstateCommissionCreate):
    id: str
    tenant_id: str
    created_at: datetime
    updated_at: datetime
