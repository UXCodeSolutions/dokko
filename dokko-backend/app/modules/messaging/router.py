from fastapi import APIRouter, Depends, HTTPException, Query
from app.core.auth import get_current_tenant_id
from app.core.supabase_client import supabase_admin
from . import service
from .schemas import (
    MessagingSettingsOut,
    MessagingSettingsUpdate,
    TemplateOut,
    TemplateUpdate,
    PendingOut,
    HistoryOut,
    BatchActionOut,
)

router = APIRouter(prefix="/messaging", tags=["Messaging"])


def _valid_module(module: str) -> str:
    if module not in service.VALID_MODULES:
        raise HTTPException(status_code=400, detail="Módulo no válido.")
    return module


@router.get("/settings", response_model=MessagingSettingsOut)
async def get_settings(
    module: str = Query("salon"), tenant_id: str = Depends(get_current_tenant_id)
):
    module = _valid_module(module)
    return {
        "module": module,
        "data": _fix_decimals(service.get_settings(tenant_id, module)),
    }


@router.put("/settings", response_model=MessagingSettingsOut)
async def put_settings(body: MessagingSettingsUpdate, tenant_id: str = Depends(get_current_tenant_id)):
    module = _valid_module(body.module)
    data = service.save_settings(tenant_id, module, body.data)
    return {"module": module, "data": _fix_decimals(data)}


@router.get("/templates", response_model=list[TemplateOut])
async def list_templates(
    module: str = Query("salon"), tenant_id: str = Depends(get_current_tenant_id)
):
    module = _valid_module(module)
    return service.resolve_templates(tenant_id, module)


@router.put("/templates", response_model=TemplateOut)
async def upsert_template(body: TemplateUpdate, tenant_id: str = Depends(get_current_tenant_id)):
    module = _valid_module(body.module)
    if not body.body.strip():
        raise HTTPException(status_code=400, detail="La plantilla no puede estar vacía.")
    service.save_template(
        tenant_id, module, body.key, body.label or body.key, body.body.strip()
    )
    tpl = service._tenant_template(tenant_id, module, body.key)
    return {
        "key": body.key,
        "label": tpl["label"] if tpl else body.key,
        "body": tpl["body"] if tpl else body.body.strip(),
        "source": "tenant",
        "is_active": tpl.get("is_active", True) if tpl else True,
    }


@router.get("/pending", response_model=PendingOut)
async def pending_messages(
    module: str = Query("salon"), tenant_id: str = Depends(get_current_tenant_id)
):
    """Materializa mensajes vencidos en lotes y devuelve la bandeja pendiente."""
    module = _valid_module(module)
    settings = service.get_settings(tenant_id, module)
    batches = service.materialize_due(tenant_id, module)
    return {
        "settings": {"module": module, "data": _fix_decimals(settings)},
        "batches": batches,
    }


@router.post("/batches/{batch_id}/confirm", response_model=BatchActionOut)
async def confirm_batch(batch_id: str, tenant_id: str = Depends(get_current_tenant_id)):
    batch = (
        supabase_admin.table("message_batches")
        .select("*")
        .eq("id", batch_id)
        .eq("tenant_id", tenant_id)
        .execute()
    )
    if not batch.data:
        raise HTTPException(status_code=404, detail="Lote no encontrado.")
    if batch.data[0]["status"] != "pending":
        raise HTTPException(status_code=409, detail="El lote ya fue procesado.")
    updated = service.confirm_batch(tenant_id, batch_id)
    return {"batch_id": batch_id, "action": "confirm", "updated": updated}


@router.post("/batches/{batch_id}/cancel", response_model=BatchActionOut)
async def cancel_batch(batch_id: str, tenant_id: str = Depends(get_current_tenant_id)):
    batch = (
        supabase_admin.table("message_batches")
        .select("*")
        .eq("id", batch_id)
        .eq("tenant_id", tenant_id)
        .execute()
    )
    if not batch.data:
        raise HTTPException(status_code=404, detail="Lote no encontrado.")
    if batch.data[0]["status"] != "pending":
        raise HTTPException(status_code=409, detail="El lote ya fue procesado.")
    updated = service.cancel_batch(tenant_id, batch_id)
    return {"batch_id": batch_id, "action": "cancel", "updated": updated}


@router.get("/history", response_model=HistoryOut)
async def history(
    module: str = Query("salon"),
    limit: int = Query(50, ge=1, le=200),
    tenant_id: str = Depends(get_current_tenant_id),
):
    module = _valid_module(module)
    return {"messages": service.list_history(tenant_id, module, limit)}


def _fix_decimals(data: dict) -> dict:
    """Serializa números del JSONB de settings (conservando los booleanos)."""
    return {
        k: (float(v) if isinstance(v, (int, float)) and not isinstance(v, bool) else v)
        for k, v in data.items()
    }