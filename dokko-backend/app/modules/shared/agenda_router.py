from fastapi import APIRouter, Depends, HTTPException, status
from typing import List, Optional
from datetime import date, datetime
from app.core.auth import get_current_tenant_id
from app.core.supabase_client import supabase_admin
from app.core.validators import assert_belongs_to_tenant
from postgrest.exceptions import APIError
from .agenda_schemas import (
    AgendaResourceCreate, AgendaResourceUpdate, AgendaResourceOut,
    AgendaAvailabilityCreate, AgendaAvailabilityOut,
    AgendaExceptionCreate, AgendaExceptionOut,
    AgendaAppointmentCreate, AgendaAppointmentUpdate, AgendaAppointmentOut
)

router = APIRouter()

# ═══════════════════════════════════════════════════════
# Resources
# ═══════════════════════════════════════════════════════

@router.get("/resources", response_model=List[AgendaResourceOut])
def get_resources(tenant_id: str = Depends(get_current_tenant_id), module: Optional[str] = None):
    query = supabase_admin.table("shared_agenda_resources").select("*").eq("tenant_id", tenant_id)
    res = query.execute()
    return res.data

@router.post("/resources", response_model=AgendaResourceOut)
def create_resource(body: AgendaResourceCreate, tenant_id: str = Depends(get_current_tenant_id)):
    data = body.model_dump(exclude_none=True)
    res = supabase_admin.table("shared_agenda_resources").insert({
        "tenant_id": tenant_id,
        **data
    }).execute()
    return res.data[0]

# ═══════════════════════════════════════════════════════
# Availability
# ═══════════════════════════════════════════════════════

@router.get("/resources/{resource_id}/availability", response_model=List[AgendaAvailabilityOut])
def get_availability(resource_id: str, tenant_id: str = Depends(get_current_tenant_id)):
    res = supabase_admin.table("shared_agenda_availability")\
        .select("*")\
        .eq("tenant_id", tenant_id)\
        .eq("resource_id", resource_id)\
        .execute()
    return res.data

@router.post("/availability", response_model=AgendaAvailabilityOut)
def set_availability(body: AgendaAvailabilityCreate, tenant_id: str = Depends(get_current_tenant_id)):
    # Upsert logic based on unique (resource_id, day_of_week)
    data = body.model_dump()
    data['start_time'] = data['start_time'].strftime("%H:%M:%S")
    data['end_time'] = data['end_time'].strftime("%H:%M:%S")
    
    # Check if exists
    existing = supabase_admin.table("shared_agenda_availability")\
        .select("id")\
        .eq("tenant_id", tenant_id)\
        .eq("resource_id", data["resource_id"])\
        .eq("day_of_week", data["day_of_week"])\
        .execute()
    
    if existing.data:
        res = supabase_admin.table("shared_agenda_availability")\
            .update({"start_time": data["start_time"], "end_time": data["end_time"]})\
            .eq("id", existing.data[0]["id"])\
            .execute()
    else:
        res = supabase_admin.table("shared_agenda_availability")\
            .insert({"tenant_id": tenant_id, **data})\
            .execute()
            
    return res.data[0]

# ═══════════════════════════════════════════════════════
# Appointments
# ═══════════════════════════════════════════════════════

@router.get("/appointments", response_model=List[AgendaAppointmentOut])
def get_appointments(
    start_date: str,
    end_date: str,
    resource_id: Optional[str] = None,
    tenant_id: str = Depends(get_current_tenant_id)
):
    query = supabase_admin.table("shared_agenda_appointments")\
        .select("*")\
        .eq("tenant_id", tenant_id)\
        .gte("start_time", start_date)\
        .lte("end_time", end_date)
        
    if resource_id:
        query = query.eq("resource_id", resource_id)
        
    res = query.execute()
    return res.data

@router.post("/appointments", response_model=AgendaAppointmentOut)
def create_appointment(body: AgendaAppointmentCreate, tenant_id: str = Depends(get_current_tenant_id)):
    assert_belongs_to_tenant("shared_agenda_resources", str(body.resource_id), tenant_id, "Recurso")
    data = body.model_dump(exclude_none=True)
    data['start_time'] = data['start_time'].isoformat()
    data['end_time'] = data['end_time'].isoformat()
    
    try:
        res = supabase_admin.table("shared_agenda_appointments").insert({
            "tenant_id": tenant_id,
            **data
        }).execute()
        return res.data[0]
    except APIError as e:
        if "DOBLE_BOOKING" in str(e):
            raise HTTPException(status_code=409, detail="El recurso ya tiene una cita en ese horario.")
        raise e

@router.patch("/appointments/{id}", response_model=AgendaAppointmentOut)
def update_appointment(id: str, body: AgendaAppointmentUpdate, tenant_id: str = Depends(get_current_tenant_id)):
    data = body.model_dump(exclude_none=True)
    if 'start_time' in data:
        data['start_time'] = data['start_time'].isoformat()
    if 'end_time' in data:
        data['end_time'] = data['end_time'].isoformat()
        
    data["updated_at"] = datetime.utcnow().isoformat()
    
    try:
        res = supabase_admin.table("shared_agenda_appointments")\
            .update(data)\
            .eq("tenant_id", tenant_id)\
            .eq("id", id)\
            .execute()
            
        if not res.data:
            raise HTTPException(status_code=404, detail="Cita no encontrada")
            
        return res.data[0]
    except APIError as e:
        if "DOBLE_BOOKING" in str(e):
            raise HTTPException(status_code=409, detail="El recurso ya tiene una cita en ese horario.")
        raise e

@router.delete("/appointments/{id}")
def delete_appointment(id: str, tenant_id: str = Depends(get_current_tenant_id)):
    res = supabase_admin.table("shared_agenda_appointments")\
        .delete()\
        .eq("tenant_id", tenant_id)\
        .eq("id", id)\
        .execute()
        
    if not res.data:
        raise HTTPException(status_code=404, detail="Cita no encontrada")
        
    return {"message": "Cita eliminada correctamente"}
