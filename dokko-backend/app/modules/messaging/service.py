"""Lógica de negocio de mensajería (FASE 28, piloto salón).

- `schedule_message`: crea un mensaje `ready` listo para enviarse.
- `schedule_salon_reminder / _feedback`: hooks específicos de salón.
- `schedule_waitlist_notification`: avisa al primer cliente en lista de espera.
- `materialize_due`: agrupa los mensajes `ready` vencidos en un lote (bandeja).
- `confirm_batch / cancel_batch`: el personal confirma o descarta el lote.
"""
from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone

from app.core.supabase_client import supabase_admin
from app.modules.messaging.provider import normalize_phone
from app.modules.messaging.templates import render, default_template

VALID_MODULES = ("salon", "gym", "realestate")

DEFAULT_SETTINGS = {
    "reminders_enabled": True,
    "reminder_hours_before": 24,
    "feedback_enabled": False,
    "feedback_url": "",
}


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _json(value):
    """Serializa valores no-JSON para Supabase (UUID, datetime)."""
    if isinstance(value, (uuid.UUID, datetime)):
        return str(value)
    return value


# ── Settings ─────────────────────────────────────────────────────────────────

def get_settings(tenant_id: str, module: str) -> dict:
    if module not in VALID_MODULES:
        module = "salon"
    res = (
        supabase_admin.table("messaging_settings")
        .select("data")
        .eq("tenant_id", tenant_id)
        .eq("module", module)
        .execute()
    )
    data = res.data[0]["data"] if res.data else {}
    return {**DEFAULT_SETTINGS, **(data or {})}


def save_settings(tenant_id: str, module: str, data: dict) -> dict:
    if module not in VALID_MODULES:
        module = "salon"
    existing = (
        supabase_admin.table("messaging_settings")
        .select("id")
        .eq("tenant_id", tenant_id)
        .eq("module", module)
        .execute()
    )
    payload = {
        "tenant_id": tenant_id,
        "module": module,
        "data": {**DEFAULT_SETTINGS, **(data or {})},
        "updated_at": _now(),
    }
    if existing.data:
        supabase_admin.table("messaging_settings").update(payload).eq(
            "id", existing.data[0]["id"]
        ).execute()
    else:
        supabase_admin.table("messaging_settings").insert(payload).execute()
    return payload["data"]


# ── Templates ────────────────────────────────────────────────────────────────

def _tenant_template(tenant_id: str, module: str, key: str) -> dict | None:
    res = (
        supabase_admin.table("messaging_templates")
        .select("label, body, is_active")
        .eq("tenant_id", tenant_id)
        .eq("module", module)
        .eq("key", key)
        .execute()
    )
    if not res.data:
        return None
    row = res.data[0]
    return row if row.get("is_active", True) else None


def _resolve_template(tenant_id: str, module: str, key: str) -> dict | None:
    tpl = _tenant_template(tenant_id, module, key)
    if tpl:
        return tpl
    return default_template(module, key)


def resolve_templates(tenant_id: str, module: str) -> list[dict]:
    """Combina los defaults con las sobreescrituras por tenant."""
    merged: dict[str, dict] = {}

    def upsert(tpl: dict, key: str, source: str) -> None:
        if tpl:
            merged[key] = {"key": key, "source": source, **tpl}

    for key, tpl in _all_defaults_for(module).items():
        upsert(tpl, key, "default")

    res = (
        supabase_admin.table("messaging_templates")
        .select("key, label, body, is_active")
        .eq("tenant_id", tenant_id)
        .eq("module", module)
        .execute()
    )
    for row in res.data or []:
        upsert(
            {"label": row["label"], "body": row["body"], "is_active": row["is_active"]},
            row["key"],
            "tenant",
        )
    return list(merged.values())


def _all_defaults_for(module: str) -> dict:
    from app.modules.messaging.templates import DEFAULT_TEMPLATES

    return DEFAULT_TEMPLATES.get(module, {})


def save_template(tenant_id: str, module: str, key: str, label: str, body: str) -> dict:
    lowercase_module = module if module in VALID_MODULES else "salon"
    existing = (
        supabase_admin.table("messaging_templates")
        .select("id")
        .eq("tenant_id", tenant_id)
        .eq("module", lowercase_module)
        .eq("key", key)
        .execute()
    )
    payload = {
        "tenant_id": tenant_id,
        "module": lowercase_module,
        "key": key,
        "label": label,
        "body": body,
        "updated_at": _now(),
    }
    if existing.data:
        supabase_admin.table("messaging_templates").update(payload).eq(
            "id", existing.data[0]["id"]
        ).execute()
    else:
        supabase_admin.table("messaging_templates").insert(payload).execute()
    return payload


# ── Programación de mensajes ─────────────────────────────────────────────────

def schedule_message(
    tenant_id: str,
    module: str,
    template_key: str,
    recipient_name: str,
    phone: str | None,
    params: dict,
    source: str,
    reference_id: str | None = None,
    scheduled_for: datetime | None = None,
) -> dict | None:
    """Crea un mensaje `ready`. Devuelve None si no hay teléfono/plantilla válidos."""
    digits = normalize_phone(phone)
    if digits is None:
        return None

    tpl = _resolve_template(tenant_id, module, template_key)
    if tpl is None or not tpl.get("is_active", True):
        return None

    body = render(tpl["body"], params)
    due = (scheduled_for or datetime.now(timezone.utc)).isoformat()
    row = {
        "tenant_id": tenant_id,
        "module": module if module in VALID_MODULES else "salon",
        "template_key": template_key,
        "recipient_name": recipient_name,
        "phone": digits,
        "body": body,
        "source": source,
        "reference_id": _json(reference_id) if reference_id else None,
        "scheduled_for": due,
        "status": "ready",
    }
    res = supabase_admin.table("outbound_messages").insert(row).execute()
    return res.data[0] if res.data else None


def cancel_messages_for_reference(
    tenant_id: str, module: str, reference_id: str, reason_status: str = "cancelled"
) -> int:
    """Cancela recordatorios pendientes de una cita (p.ej. reprogramación/cancelación)."""
    res = (
        supabase_admin.table("outbound_messages")
        .update({"status": reason_status, "updated_at": _now()})
        .eq("tenant_id", tenant_id)
        .eq("module", module)
        .eq("reference_id", reference_id)
        .in_("status", ["ready", "pending"])
        .execute()
    )
    return len(res.data or [])


def _business_name(tenant_id: str) -> str:
    res = (
        supabase_admin.table("tenants")
        .select("name")
        .eq("id", tenant_id)
        .single()
        .execute()
    )
    return (res.data or {}).get("name", "tu negocio de confianza")


def _client_reminder_allowed(client: dict | None, settings: dict) -> bool:
    if not settings.get("reminders_enabled", True):
        return False
    if client is None:
        return False
    # Ley 172-13: solo recordamos a clientes con consentimiento individual.
    if not client.get("consent_granted_at"):
        return False
    return True


def schedule_salon_reminder(
    appointment: dict, client: dict | None, tenant_id: str, business: str
) -> dict | None:
    """Programa el recordatorio −hours para una cita del salón."""
    settings = get_settings(tenant_id, "salon")
    if not _client_reminder_allowed(client, settings):
        return None

    hours = int(settings.get("reminder_hours_before") or 24)
    start = datetime.fromisoformat(appointment["start_time"])
    due = start - timedelta(hours=hours)

    params = {
        "client": (client.get("first_name") if client else None) or appointment.get("client_name", "cliente"),
        "business": business,
        "date": start.strftime("%d/%m/%Y"),
        "time": start.strftime("%I:%M %p"),
    }
    return schedule_message(
        tenant_id=tenant_id,
        module="salon",
        template_key="salon.reminder",
        recipient_name=params["client"],
        phone=client.get("phone") if client else None,
        params=params,
        source="reminder",
        reference_id=appointment["id"],
        scheduled_for=due,
    )


def schedule_salon_feedback(
    appointment: dict, client: dict | None, tenant_id: str, business: str
) -> dict | None:
    """Programa la petición de feedback post-servicio (solo si hay URL configurada)."""
    settings = get_settings(tenant_id, "salon")
    if not settings.get("feedback_enabled"):
        return None
    link = (settings.get("feedback_url") or "").strip()
    if not link:
        return None
    if client is None or not client.get("consent_granted_at"):
        return None

    params = {
        "client": client.get("first_name") or "cliente",
        "business": business,
        "link": link,
    }
    return schedule_message(
        tenant_id=tenant_id,
        module="salon",
        template_key="salon.feedback",
        recipient_name=params["client"],
        phone=client.get("phone") if client else None,
        params=params,
        source="feedback",
        reference_id=appointment["id"],
    )


def schedule_waitlist_notification(tenant_id: str, business: str) -> dict | None:
    """Avisa al primer cliente en espera y lo marca como 'notified'."""
    res = (
        supabase_admin.table("salon_waitlist")
        .select("*")
        .eq("tenant_id", tenant_id)
        .eq("status", "waiting")
        .order("created_at")
        .limit(1)
        .execute()
    )
    if not res.data:
        return None
    entry = res.data[0]

    name = entry.get("client_name") or "cliente"
    msg = schedule_message(
        tenant_id=tenant_id,
        module="salon",
        template_key="salon.waitlist_slot",
        recipient_name=name,
        phone=entry.get("phone"),
        params={"client": name, "business": business},
        source="waitlist",
        reference_id=entry.get("id"),
    )
    if msg is not None:
        supabase_admin.table("salon_waitlist").update({"status": "notified"}).eq(
            "id", _json(entry["id"])
        ).execute()
    return msg


# ── Bandeja / lotes ──────────────────────────────────────────────────────────

def _batch_with_messages(batch: dict, tenant_id: str) -> dict:
    msgs = (
        supabase_admin.table("outbound_messages")
        .select("*")
        .eq("batch_id", _json(batch["id"]))
        .order("scheduled_for")
        .execute()
    )
    return {**batch, "messages": msgs.data or []}


def materialize_due(tenant_id: str, module: str) -> list[dict]:
    """Agrupa los mensajes `ready` vencidos en un lote pendiente (si existen)."""
    now = _now()
    due = (
        supabase_admin.table("outbound_messages")
        .select("*")
        .eq("tenant_id", tenant_id)
        .eq("module", module)
        .eq("status", "ready")
        .lte("scheduled_for", now)
        .order("scheduled_for")
        .limit(200)
        .execute()
    )
    due_rows = due.data or []
    if due_rows:
        batch_res = (
            supabase_admin.table("message_batches")
            .insert({"tenant_id": tenant_id, "module": module, "status": "pending"})
            .execute()
        )
        batch_id = _json(batch_res.data[0]["id"])
        supabase_admin.table("outbound_messages").update(
            {"batch_id": batch_id, "status": "pending", "updated_at": _now()}
        ).eq("tenant_id", tenant_id).eq("module", module).in_(
            "id", [_json(r["id"]) for r in due_rows]
        ).execute()

    batches = (
        supabase_admin.table("message_batches")
        .select("*")
        .eq("tenant_id", tenant_id)
        .eq("module", module)
        .eq("status", "pending")
        .order("created_at")
        .execute()
    )
    return [_batch_with_messages(b, tenant_id) for b in batches.data or []]


def confirm_batch(tenant_id: str, batch_id: str) -> int:
    batch = (
        supabase_admin.table("message_batches").select("*").eq("id", batch_id).execute()
    )
    if not batch.data:
        return -1
    supabase_admin.table("message_batches").update(
        {"status": "confirmed", "confirmed_at": _now()}
    ).eq("id", batch_id).execute()
    msgs = (
        supabase_admin.table("outbound_messages")
        .update({"status": "sent", "sent_at": _now(), "updated_at": _now()})
        .eq("batch_id", batch_id)
        .in_("status", ["pending", "ready"])
        .execute()
    )
    return len(msgs.data or [])


def cancel_batch(tenant_id: str, batch_id: str) -> int:
    batch = (
        supabase_admin.table("message_batches").select("*").eq("id", batch_id).execute()
    )
    if not batch.data:
        return -1
    supabase_admin.table("message_batches").update({"status": "cancelled"}).eq(
        "id", batch_id
    ).execute()
    msgs = (
        supabase_admin.table("outbound_messages")
        .update({"status": "cancelled", "updated_at": _now()})
        .eq("batch_id", batch_id)
        .in_("status", ["pending", "ready"])
        .execute()
    )
    return len(msgs.data or [])


def list_history(tenant_id: str, module: str, limit: int = 50) -> list[dict]:
    res = (
        supabase_admin.table("outbound_messages")
        .select("*")
        .eq("tenant_id", tenant_id)
        .eq("module", module)
        .in_("status", ["sent", "cancelled"])
        .order("updated_at", desc=True)
        .limit(limit)
        .execute()
    )
    return res.data or []