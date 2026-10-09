from fastapi import APIRouter, Depends, HTTPException
from typing import List, Optional
from datetime import datetime, timezone
from app.core.auth import get_current_tenant_id
from app.core.supabase_client import supabase_admin
from app.core.validators import assert_belongs_to_tenant
from .schemas import (
    RealEstateAgentCreate, RealEstateAgentUpdate, RealEstateAgentOut,
    RealEstatePropertyCreate, RealEstatePropertyUpdate, RealEstatePropertyOut,
    RealEstateLeadCreate, RealEstateLeadUpdate, RealEstateLeadOut,
    RealEstateDossierCreate, RealEstateDossierOut,
    RealEstateCommissionCreate, RealEstateCommissionUpdate, RealEstateCommissionOut
)

router = APIRouter()

# ═══════════════════════════════════════════════════════
# Agents
# ═══════════════════════════════════════════════════════

@router.get("/agents", response_model=List[RealEstateAgentOut])
def get_agents(tenant_id: str = Depends(get_current_tenant_id)):
    res = supabase_admin.table("realestate_agents").select("*").eq("tenant_id", tenant_id).execute()
    return res.data

@router.post("/agents", response_model=RealEstateAgentOut)
def create_agent(body: RealEstateAgentCreate, tenant_id: str = Depends(get_current_tenant_id)):
    data = body.model_dump(exclude_none=True)
    if 'commission_rate' in data:
        data['commission_rate'] = float(data['commission_rate'])
    res = supabase_admin.table("realestate_agents").insert({"tenant_id": tenant_id, **data}).execute()
    return res.data[0]

@router.patch("/agents/{id}", response_model=RealEstateAgentOut)
def update_agent(id: str, body: RealEstateAgentUpdate, tenant_id: str = Depends(get_current_tenant_id)):
    data = body.model_dump(exclude_none=True)
    if 'commission_rate' in data:
        data['commission_rate'] = float(data['commission_rate'])
    data['updated_at'] = datetime.utcnow().isoformat()
    res = supabase_admin.table("realestate_agents").update(data).eq("tenant_id", tenant_id).eq("id", id).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Agent not found")
    return res.data[0]

# ═══════════════════════════════════════════════════════
# Properties
# ═══════════════════════════════════════════════════════

@router.get("/properties", response_model=List[RealEstatePropertyOut])
def get_properties(status: Optional[str] = None, tenant_id: str = Depends(get_current_tenant_id)):
    query = supabase_admin.table("realestate_properties").select("*").eq("tenant_id", tenant_id)
    if status:
        query = query.eq("status", status)
    res = query.execute()
    return res.data

@router.post("/properties", response_model=RealEstatePropertyOut)
def create_property(body: RealEstatePropertyCreate, tenant_id: str = Depends(get_current_tenant_id)):
    assert_belongs_to_tenant("realestate_agents", str(body.assigned_agent_id) if body.assigned_agent_id else None, tenant_id, "Agente")
    data = body.model_dump(exclude_none=True)
    # Convert decimals to floats for supabase json serialization
    decimal_fields = ['price_sale', 'price_rent', 'hoa_fee', 'property_tax', 'bathrooms', 'square_meters_built', 'square_meters_land', 'latitude', 'longitude']
    for f in decimal_fields:
        if f in data and data[f] is not None:
            data[f] = float(data[f])
            
    res = supabase_admin.table("realestate_properties").insert({"tenant_id": tenant_id, **data}).execute()
    return res.data[0]

@router.patch("/properties/{id}", response_model=RealEstatePropertyOut)
def update_property(id: str, body: RealEstatePropertyUpdate, tenant_id: str = Depends(get_current_tenant_id)):
    data = body.model_dump(exclude_none=True)
    decimal_fields = ['price_sale', 'price_rent', 'hoa_fee', 'property_tax', 'bathrooms', 'square_meters_built', 'square_meters_land', 'latitude', 'longitude']
    for f in decimal_fields:
        if f in data and data[f] is not None:
            data[f] = float(data[f])
            
    data['updated_at'] = datetime.utcnow().isoformat()
    res = supabase_admin.table("realestate_properties").update(data).eq("tenant_id", tenant_id).eq("id", id).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Property not found")
    return res.data[0]

@router.delete("/properties/{id}")
def delete_property(id: str, tenant_id: str = Depends(get_current_tenant_id)):
    res = supabase_admin.table("realestate_properties").delete().eq("tenant_id", tenant_id).eq("id", id).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Property not found")
    return {"message": "Deleted"}

# ═══════════════════════════════════════════════════════
# Leads
# ═══════════════════════════════════════════════════════

@router.get("/leads", response_model=List[RealEstateLeadOut])
def get_leads(status: Optional[str] = None, tenant_id: str = Depends(get_current_tenant_id)):
    query = supabase_admin.table("realestate_leads").select("*").eq("tenant_id", tenant_id)
    if status:
        query = query.eq("status", status)
    res = query.execute()
    return res.data

@router.post("/leads", response_model=RealEstateLeadOut)
def create_lead(body: RealEstateLeadCreate, tenant_id: str = Depends(get_current_tenant_id)):
    assert_belongs_to_tenant("realestate_agents", str(body.assigned_agent_id) if body.assigned_agent_id else None, tenant_id, "Agente")
    assert_belongs_to_tenant("realestate_properties", str(body.interested_property_id) if body.interested_property_id else None, tenant_id, "Propiedad")
    data = body.model_dump(exclude_none=True)
    if 'budget_min' in data: data['budget_min'] = float(data['budget_min'])
    if 'budget_max' in data: data['budget_max'] = float(data['budget_max'])
    if 'consent_granted_at' in data:
        data['consent_granted_at'] = data['consent_granted_at'].isoformat()
    res = supabase_admin.table("realestate_leads").insert({"tenant_id": tenant_id, **data}).execute()
    return res.data[0]

@router.patch("/leads/{id}", response_model=RealEstateLeadOut)
def update_lead(id: str, body: RealEstateLeadUpdate, tenant_id: str = Depends(get_current_tenant_id)):
    data = body.model_dump(exclude_none=True)
    if 'budget_min' in data: data['budget_min'] = float(data['budget_min'])
    if 'budget_max' in data: data['budget_max'] = float(data['budget_max'])
    if 'consent_granted_at' in data:
        data['consent_granted_at'] = data['consent_granted_at'].isoformat()
    data['updated_at'] = datetime.utcnow().isoformat()
    res = supabase_admin.table("realestate_leads").update(data).eq("tenant_id", tenant_id).eq("id", id).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Lead not found")
    return res.data[0]

@router.delete("/leads/{id}")
def delete_lead(id: str, tenant_id: str = Depends(get_current_tenant_id)):
    # FASE 25 — Ley 172-13: antes de borrar, desvincular dossiers/comisiones (FK) y auditar.
    supabase_admin.table("realestate_dossiers").update({"lead_id": None})\
        .eq("lead_id", id).eq("tenant_id", tenant_id).execute()
    supabase_admin.table("realestate_commissions").update({"lead_id": None})\
        .eq("lead_id", id).eq("tenant_id", tenant_id).execute()
    try:
        supabase_admin.table("audit_log").insert({
            "tenant_id": tenant_id,
            "action": "data_erasure_lead",
            "entity": "realestate_lead",
            "entity_id": id,
            "metadata": {"law": "Ley 172-13", "scope": "full_erasure"},
        }).execute()
    except Exception:
        pass
    res = supabase_admin.table("realestate_leads").delete().eq("tenant_id", tenant_id).eq("id", id).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Lead not found")
    return {"message": "Deleted"}


@router.get("/leads/{id}/export-data")
def export_lead_data(id: str, tenant_id: str = Depends(get_current_tenant_id)):
    """Exportación de datos personales (Ley 172-13) de un lead."""
    lead = supabase_admin.table("realestate_leads")\
        .select("*")\
        .eq("id", id)\
        .eq("tenant_id", tenant_id)\
        .single()\
        .execute()
    if not lead.data:
        raise HTTPException(status_code=404, detail="Lead not found")

    dossiers = supabase_admin.table("realestate_dossiers")\
        .select("*")\
        .eq("lead_id", id)\
        .eq("tenant_id", tenant_id)\
        .execute()
    payload = {
        "law": "Ley 172-13 (Protección de Datos Personales)",
        "exported_at": datetime.now(timezone.utc).isoformat(),
        "tenant_id": tenant_id,
        "personal_data": lead.data,
        "consent_granted_at": lead.data.get("consent_granted_at"),
        "dossiers": dossiers.data or [],
    }
    try:
        supabase_admin.table("audit_log").insert({
            "tenant_id": tenant_id,
            "action": "data_export_lead",
            "entity": "realestate_lead",
            "entity_id": id,
            "metadata": {"law": "Ley 172-13", "pii": True},
        }).execute()
    except Exception:
        pass
    return payload

# ═══════════════════════════════════════════════════════
# Commissions
# ═══════════════════════════════════════════════════════

@router.get("/commissions", response_model=List[RealEstateCommissionOut])
def get_commissions(tenant_id: str = Depends(get_current_tenant_id)):
    res = supabase_admin.table("realestate_commissions").select("*").eq("tenant_id", tenant_id).execute()
    return res.data

@router.post("/commissions", response_model=RealEstateCommissionOut)
def create_commission(body: RealEstateCommissionCreate, tenant_id: str = Depends(get_current_tenant_id)):
    assert_belongs_to_tenant("realestate_properties", str(body.property_id) if body.property_id else None, tenant_id, "Propiedad")
    assert_belongs_to_tenant("realestate_agents", str(body.agent_id) if body.agent_id else None, tenant_id, "Agente")
    assert_belongs_to_tenant("realestate_leads", str(body.lead_id) if body.lead_id else None, tenant_id, "Lead")
    data = body.model_dump(exclude_none=True)
    data['amount'] = float(data['amount'])
    if 'closed_at' in data and data['closed_at']:
        data['closed_at'] = data['closed_at'].isoformat()
    res = supabase_admin.table("realestate_commissions").insert({"tenant_id": tenant_id, **data}).execute()
    return res.data[0]
