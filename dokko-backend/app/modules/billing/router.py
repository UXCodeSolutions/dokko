"""
FASE 24 — Facturación y ciclo de vida del tenant.

Configuración almacenada de forma tolerante vía `tenants.brand_config` (JSONB):
  brand_config.grace_days            -> días de gracia (default 7)
  brand_config.suspended_at          -> marca de suspensión automática
  brand_config.suspension_reason     -> motivo de suspensión
El estado del negocio sigue viviendo en `tenants.status` (CHECK 'active'|'suspended'|'cancelled').

- Revisión de suspensiones automática (current_period_end + gracia).
- Notificaciones de pagos vencidos para super-admins.
- Estado de cuenta read-only para cada tenant.
"""
from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel

from app.core.auth import get_current_tenant_id, get_current_user
from app.core.supabase_client import supabase_admin

router = APIRouter()

DEFAULT_GRACE_DAYS = 7


# ── Helpers ───────────────────────────────────────────────────────────────────

def _is_super_admin(user: dict) -> bool:
    return bool(user.get("app_metadata", {}).get("is_super_admin", False))


def _resolve_own_tenant(user: dict) -> str:
    tenant_id = user.get("app_metadata", {}).get("tenant_id")
    if not tenant_id:
        raise HTTPException(status_code=403, detail="El usuario no pertenece a ningún tenant.")
    return tenant_id


def _parse_ts(raw) -> datetime:
    return datetime.fromisoformat(str(raw).replace("Z", "+00:00"))


def _grace_days(tenant: dict) -> int:
    bc = tenant.get("brand_config") or {}
    g = bc.get("grace_days")
    if isinstance(g, (int, float)) and int(g) > 0:
        return int(g)
    return DEFAULT_GRACE_DAYS


def _active_subscriptions(tenant_id: str) -> List[dict]:
    res = supabase_admin.table("subscriptions") \
        .select("*") \
        .eq("tenant_id", tenant_id) \
        .eq("status", "active") \
        .execute()
    return res.data or []


# ── Schemas ───────────────────────────────────────────────────────────────────

class GraceUpdateRequest(BaseModel):
    tenant_id: str
    grace_days: int


# ── Endpoints ─────────────────────────────────────────────────────────────────

@router.post("/suspension-check")
def run_suspension_check(user: dict = Depends(get_current_user)):
    """
    Revisa suscripciones vencidas.

    - Super-admin: revisa TODOS los tenants.
    - Usuario de tenant: revisa solo su propio tenant.

    Un tenant activo con suscripción 'active' vencida más allá de su gracia se
    suspende automáticamente (status → 'suspended'). Los tenants sin suscripción
    NO se tocan (estado de prueba/onboarding).
    """
    now = datetime.now(timezone.utc)

    if _is_super_admin(user):
        res = supabase_admin.table("tenants") \
            .select("id, name, status, brand_config") \
            .execute()
        tenants = res.data or []
    else:
        res = supabase_admin.table("tenants") \
            .select("id, name, status, brand_config") \
            .eq("id", _resolve_own_tenant(user)) \
            .execute()
        tenants = res.data or []

    suspended: List[dict] = []
    for tenant in tenants:
        if tenant.get("status") != "active":
            continue
        grace = tenant.get("grace_days") or _grace_days(tenant)
        worst: Optional[dict] = None
        for sub in _active_subscriptions(tenant["id"]):
            end_raw = sub.get("current_period_end")
            if not end_raw:
                continue
            end = _parse_ts(end_raw)
            if end <= now and (now - end).days > grace:
                worst = sub
        if worst is None:
            continue
        brand_config = dict(tenant.get("brand_config") or {})
        brand_config["suspended_at"] = now.isoformat()
        brand_config["suspension_reason"] = "Pago vencido más allá del periodo de gracia."
        supabase_admin.table("tenants").update({
            "status": "suspended",
            "brand_config": brand_config,
        }).eq("id", tenant["id"]).execute()
        suspended.append({"tenant_id": tenant["id"], "name": tenant.get("name")})

    return {
        "checked": len(tenants),
        "suspended": len(suspended),
        "details": suspended,
    }


@router.get("/overdue")
def list_overdue(user: dict = Depends(get_current_user)):
    """Notificaciones de pagos vencidos (solo super-admin)."""
    if not _is_super_admin(user):
        raise HTTPException(status_code=403, detail="Acceso restringido a super-admins.")

    now = datetime.now(timezone.utc)
    tenants = supabase_admin.table("tenants") \
        .select("id, name, status, brand_config, account_owners(email)") \
        .execute()
    overdue: List[dict] = []

    for tenant in tenants.data or []:
        subs = supabase_admin.table("subscriptions") \
            .select("current_period_end, status") \
            .eq("tenant_id", tenant["id"]) \
            .execute()
        for sub in subs.data or []:
            if sub.get("status") != "active" or not sub.get("current_period_end"):
                continue
            end = _parse_ts(sub["current_period_end"])
            if end < now:
                days = (now - end).days
                grace = tenant.get("grace_days") or _grace_days(tenant)
                overdue.append({
                    "tenant_id": tenant["id"],
                    "tenant_name": tenant.get("name"),
                    "owner_email": (tenant.get("account_owners") or {}).get("email"),
                    "current_period_end": sub["current_period_end"],
                    "days_overdue": days,
                    "grace_days": grace,
                    "in_grace": days <= grace,
                    "status": tenant.get("status"),
                })

    overdue.sort(key=lambda r: r["days_overdue"], reverse=True)
    return overdue


@router.put("/grace")
def set_grace_days(
    body: GraceUpdateRequest,
    user: dict = Depends(get_current_user),
):
    """Configura los días de gracia de un tenant (solo super-admin)."""
    if not _is_super_admin(user):
        raise HTTPException(status_code=403, detail="Acceso restringido a super-admins.")
    if not 0 <= body.grace_days <= 60:
        raise HTTPException(status_code=400, detail="La gracia debe estar entre 0 y 60 días.")

    tenant = supabase_admin.table("tenants") \
        .select("brand_config") \
        .eq("id", body.tenant_id) \
        .maybe_single() \
        .execute()
    if tenant is None or not tenant.data:
        raise HTTPException(status_code=404, detail="Tenant no encontrado.")

    brand_config = dict(tenant.data.get("brand_config") or {})
    brand_config["grace_days"] = body.grace_days
    res = supabase_admin.table("tenants") \
        .update({"brand_config": brand_config}) \
        .eq("id", body.tenant_id) \
        .execute()
    return res.data[0]


@router.post("/apply-retention")
def apply_retention(user: dict = Depends(get_current_user)):
    """
    FASE 25 — Ley 172-13: elimina registros personales SIN consentimiento cuando
    superan el periodo de retención configurado (tenants.retention_days, default 90).
    Los registros con consentimiento se conservan. Diseñado para ejecución agendada.
    """
    if not _is_super_admin(user):
        raise HTTPException(status_code=403, detail="Acceso restringido a super-admins.")

    now = datetime.now(timezone.utc)
    tenants = supabase_admin.table("tenants") \
        .select("id, name, retention_days") \
        .execute()
    erased: List[dict] = []

    for tenant in tenants.data or []:
        retention = tenant.get("retention_days") or 90
        cutoff = (now - timedelta(days=retention)).isoformat()
        for table in ("gym_members", "realestate_leads", "salon_clients"):
            res = supabase_admin.table(table) \
                .select("id") \
                .eq("tenant_id", tenant["id"]) \
                .is_("consent_granted_at", "null") \
                .lt("created_at", cutoff) \
                .execute()
            ids = [r["id"] for r in (res.data or [])]
            if not ids:
                continue
            if table == "gym_members":
                supabase_admin.table("gym_sales").update({"member_id": None}).in_("member_id", ids).execute()
            elif table == "realestate_leads":
                supabase_admin.table("realestate_dossiers").update({"lead_id": None}).in_("lead_id", ids).execute()
                supabase_admin.table("realestate_commissions").update({"lead_id": None}).in_("lead_id", ids).execute()
            elif table == "salon_clients":
                supabase_admin.table("shared_agenda_appointments").update({"client_id": None}).in_("client_id", ids).execute()
            supabase_admin.table(table).delete().in_("id", ids).execute()
            erased.append({"tenant": tenant.get("name"), "table": table, "erased": len(ids)})

    return {"retention_policy": "Ley 172-13", "erased_total": len(erased), "details": erased}


@router.get("/statement")
def billing_statement(tenant_id: str = Depends(get_current_tenant_id)):
    """Estado de cuenta read-only del tenant autenticado."""
    tenant = supabase_admin.table("tenants") \
        .select("id, name, status, brand_config, created_at") \
        .eq("id", tenant_id) \
        .maybe_single() \
        .execute()
    if tenant is None or not tenant.data:
        raise HTTPException(status_code=404, detail="Tenant no encontrado.")

    subs = supabase_admin.table("subscriptions") \
        .select("*") \
        .eq("tenant_id", tenant_id) \
        .order("created_at", desc=True) \
        .execute()
    payments = supabase_admin.table("payments") \
        .select("id, amount, status, created_at") \
        .eq("tenant_id", tenant_id) \
        .order("created_at", desc=True) \
        .limit(12) \
        .execute()

    # Join manual con subscription_plans (la relación no está en el schema cache)
    plan_ids = {s.get("plan_id") for s in (subs.data or []) if s.get("plan_id")}
    plans: dict = {}
    if plan_ids:
        for pid in plan_ids:
            row = supabase_admin.table("subscription_plans") \
                .select("id, name, base_price, interval") \
                .eq("id", pid) \
                .maybe_single() \
                .execute()
            if row is not None and row.data:
                plans[pid] = row.data
    sub_rows = []
    for s in subs.data or []:
        s = dict(s)
        s["plan"] = plans.get(s.get("plan_id"))
        sub_rows.append(s)

    now = datetime.now(timezone.utc)
    active_sub = next((s for s in sub_rows if s.get("status") == "active"), None)

    brand_config = tenant.data.get("brand_config") or {}
    statement = {
        "tenant": {
            **tenant.data,
            "suspended_at": brand_config.get("suspended_at"),
            "suspension_reason": brand_config.get("suspension_reason"),
        },
        "grace_days": tenant.data.get("grace_days") or _grace_days(tenant.data),
        "subscriptions": sub_rows,
        "payments": payments.data or [],
    }

    if active_sub and active_sub.get("current_period_end"):
        end = _parse_ts(active_sub["current_period_end"])
        days = (now - end).days
        statement["current_period_end"] = active_sub["current_period_end"]
        statement["days_overdue"] = max(0, days)
        statement["in_grace"] = 0 < days <= (tenant.data.get("grace_days") or _grace_days(tenant.data))
        statement["is_current"] = end >= now

    return statement