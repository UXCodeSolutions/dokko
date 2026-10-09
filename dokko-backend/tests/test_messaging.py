"""FASE 28 — Tests del módulo de mensajería (piloto salón).

Parte A: unitarios (sin red): normalización de teléfono, render de plantillas y
generación del deep-link wa.me.
Parte B: integración contra Supabase (guardada por env): programar un mensaje
`ready`, materializarlo en un lote y confirmarlo; el mensaje queda `sent`.
"""
from __future__ import annotations

import base64
import json
import os
import uuid

import httpx
import pytest

from app.modules.messaging.provider import WaDeepLinkProvider, normalize_phone
from app.modules.messaging.templates import render, DEFAULT_TEMPLATES
from app.modules.messaging import service

SUPABASE_URL = os.getenv("SUPABASE_URL", "").rstrip("/")
SUPABASE_ANON_KEY = os.getenv("SUPABASE_KEY", "")


# ── Parte A: unitarios ────────────────────────────────────────────────────────

class TestPhoneNormalization:
    def test_10_digits_dr_gets_plus1(self):
        assert normalize_phone("809-555-0100") == "18095550100"

    def test_already_has_country_code(self):
        assert normalize_phone("+1 (809) 555-0100") == "18095550100"

    def test_rejects_too_short(self):
        assert normalize_phone("555-0100") is None

    def test_rejects_empty(self):
        assert normalize_phone(None) is None
        assert normalize_phone("") is None

    def test_11_or_12_digits_passthrough(self):
        assert normalize_phone("521551234567") == "521551234567"
        assert normalize_phone("521551234567890") is None


class TestRendering:
    def test_substitutes_params(self):
        out = render("Hola {{client}}! Cita {{date}} a las {{time}}.",
                     {"client": "Ana", "date": "15/09/2026", "time": "04:00 PM"})
        assert out == "Hola Ana! Cita 15/09/2026 a las 04:00 PM."

    def test_unknown_keys_are_left(self):
        out = render("Hola {{client}}! {{no_existe}}", {"client": "Ana"})
        assert "no_existe" in out

    def test_defaults_have_reminder_template(self):
        tpl = DEFAULT_TEMPLATES["salon"]["salon.reminder"]
        assert "{{client}}" in tpl["body"]
        assert "{{business}}" in tpl["body"]
        assert "{{date}}" in tpl["body"]
        assert "{{time}}" in tpl["body"]


class TestWaLink:
    def test_builds_url(self):
        provider = WaDeepLinkProvider()
        url = provider.build_link("18095550100", "Hola Ana! Te esperamos")
        assert url.startswith("https://wa.me/18095550100?text=")
        assert "%20" in url  # espacios URL-encoded


# ── Parte B: integración con Supabase ─────────────────────────────────────────

def _decode_payload(token: str) -> dict:
    payload = token.split(".")[1]
    padding = "=" * (-len(payload) % 4)
    return json.loads(base64.urlsafe_b64decode(payload + padding).decode("utf-8"))


@pytest.fixture(scope="module")
def _salon_tenant():
    if not SUPABASE_URL or not SUPABASE_ANON_KEY:
        pytest.skip("SUPABASE_URL / SUPABASE_KEY no configuradas")
    with httpx.Client(base_url=SUPABASE_URL, timeout=30.0) as client:
        res = client.post(
            "/auth/v1/token",
            params={"grant_type": "password"},
            headers={"apikey": SUPABASE_ANON_KEY},
            json={"email": "salon-admin@dokko.dev", "password": "DokkoTest1!"},
        )
        res.raise_for_status()
        token = res.json()["access_token"]
    tenant_id = _decode_payload(token)["app_metadata"]["tenant_id"]
    assert tenant_id, "El JWT de salon-admin no expone tenant_id"
    return tenant_id


def _cleanup(rows: list[dict]) -> None:
    """Borra mensajes/lotes creados durante el test."""
    from app.core.supabase_client import supabase_admin

    for row in rows:
        supabase_admin.table("outbound_messages").delete().eq("id", row["id"]).execute()
        if row.get("batch_id"):
            supabase_admin.table("message_batches").delete().eq(
                "id", row["batch_id"]
            ).execute()


def test_flujo_mensaje_lote_confirmacion(_salon_tenant):
    """Programa un mensaje manual, lo materializa en lote y lo confirma → 'sent'."""
    tenant_id = _salon_tenant
    stamp = uuid.uuid4().hex[:8]
    msg = service.schedule_message(
        tenant_id=tenant_id,
        module="salon",
        template_key="salon.reminder",
        recipient_name=f"Test {stamp}",
        phone="809-555-0100",
        params={"client": f"Test {stamp}", "business": "Salon Test"},
        source="manual",
    )
    assert msg is not None, "El mensaje debe programarse"
    created = [msg]

    try:
        batches = service.materialize_due(tenant_id, "salon")
        msg_ref = (
            service.supabase_admin.table("outbound_messages")
            .select("batch_id, status")
            .eq("id", msg["id"])
            .single()
            .execute()
        )
        batch_id = msg_ref.data.get("batch_id")
        batch = next((b for b in batches if str(b["id"]) == str(batch_id)), None)
        assert batch is not None, "El mensaje debe materializarse en un lote"
        assert any(m["id"] == msg["id"] for m in batch["messages"]), (
            "El lote debe contener el mensaje"
        )

        updated = service.confirm_batch(tenant_id, str(batch_id))
        assert updated >= 1, "La confirmación debe marcar al menos un mensaje"

        check = (
            service.supabase_admin.table("outbound_messages")
            .select("status, sent_at")
            .eq("id", msg["id"])
            .single()
            .execute()
        )
        assert check.data["status"] == "sent", "El mensaje debe quedar 'sent'"
        assert check.data.get("sent_at"), "El mensaje debe tener sent_at"
        if batch_id:
            created[0]["batch_id"] = str(batch_id)
    finally:
        _cleanup(created)


def test_consent_bloquea_recordatorio(_salon_tenant):
    """Sin consentimiento, el recordatorio de cita no se agenda (Ley 172-13)."""
    tenant_id = _salon_tenant
    client = {"first_name": "Sin", "last_name": "Consent", "phone": "809-555-0200"}
    appointment = {
        "id": str(uuid.uuid4()),
        "start_time": "2027-01-15T12:00:00+00:00",
        "client_name": "Sin Consent",
    }
    out = service.schedule_salon_reminder(
        appointment, client, tenant_id, "Salon Test"
    )
    assert out is None, "Sin consentimiento no debe generarse recordatorio"


def test_normalize_phone_used_by_schedule(_salon_tenant):
    """El teléfono guardado queda en formato wa.me (E.164 sin '+')."""
    tenant_id = _salon_tenant
    stamp = uuid.uuid4().hex[:8]
    msg = service.schedule_message(
        tenant_id=tenant_id,
        module="salon",
        template_key="salon.reminder",
        recipient_name=f"Phone {stamp}",
        phone="809-555-0300",
        params={"client": f"Phone {stamp}", "business": "Salon Test"},
        source="manual",
    )
    assert msg is not None
    created = [msg]
    try:
        assert msg["phone"] == "18095550300", "El teléfono debe normalizarse E.164"
        assert msg["status"] == "ready"
        batch = service.materialize_due(tenant_id, "salon")
        msg_ref = (
            service.supabase_admin.table("outbound_messages")
            .select("batch_id")
            .eq("id", msg["id"])
            .single()
            .execute()
        )
        batch_id = msg_ref.data.get("batch_id")
        assert any(str(b["id"]) == str(batch_id) for b in batch)
        if batch_id:
            created[0]["batch_id"] = str(batch_id)
    finally:
        _cleanup(created)