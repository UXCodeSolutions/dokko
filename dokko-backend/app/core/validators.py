from fastapi import HTTPException
from app.core.supabase_client import supabase_admin

def assert_belongs_to_tenant(table: str, record_id: str, tenant_id: str, label: str = "Recurso"):
    """Lanza 404 si el registro no existe o no pertenece al tenant actual."""
    if not record_id:
        return
    res = supabase_admin.table(table).select("id").eq("id", str(record_id)).eq("tenant_id", tenant_id).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail=f"{label} no encontrado o no pertenece a este negocio.")
