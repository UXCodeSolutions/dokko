"""
FASE 26 — Tests de aislamiento RLS multi-tenant.

Para cada tabla con columna `tenant_id` (31 en total) se verifica que el JWT de un
tenant NO puede leer filas de otro tenant a través de PostgREST (RLS activo).

Se usan 2 de los tenants de prueba reales (gym-admin y salon-admin) contra Supabase.
Si la variable de entorno de Supabase no está configurada, el test se omite.
"""
from __future__ import annotations

import base64
import json
import os

import httpx
import pytest

SUPABASE_URL = os.getenv("SUPABASE_URL", "").rstrip("/")
SUPABASE_ANON_KEY = os.getenv("SUPABASE_KEY", "")

# Seleccionado desde information_schema: todas las tablas publicas con tenant_id.
TENANT_SCOPED_TABLES = [
    "audit_log",
    "gym_checkins",
    "gym_employees",
    "gym_members",
    "gym_membership_payments",
    "gym_membership_plans",
    "gym_products",
    "gym_sale_items",
    "gym_sales",
    "gym_settings",
    "gym_stock_movements",
    "message_batches",
    "messaging_settings",
    "messaging_templates",
    "outbound_messages",
    "payments",
    "realestate_agents",
    "realestate_commissions",
    "realestate_dossiers",
    "realestate_leads",
    "realestate_properties",
    "salon_appointment_services",
    "salon_clients",
    "salon_commissions",
    "salon_employees",
    "salon_products",
    "salon_sale_items",
    "salon_sales",
    "salon_services",
    "salon_waitlist",
    "shared_agenda_appointments",
    "shared_agenda_availability",
    "shared_agenda_exceptions",
    "shared_agenda_resources",
    "subscriptions",
    "tenant_users",
]

TEST_USERS = ["gym-admin@dokko.dev", "salon-admin@dokko.dev"]
TEST_PASSWORD = "DokkoTest1!"


def _decode_payload(token: str) -> dict:
    payload = token.split(".")[1]
    padding = "=" * (-len(payload) % 4)
    return json.loads(base64.urlsafe_b64decode(payload + padding).decode("utf-8"))


def _tenant_id_from_jwt(token: str) -> str:
    return _decode_payload(token)["app_metadata"]["tenant_id"]


def _build_httpx() -> httpx.Client:
    if not SUPABASE_URL or not SUPABASE_ANON_KEY:
        pytest.skip("SUPABASE_URL / SUPABASE_KEY no configuradas")
    return httpx.Client(base_url=SUPABASE_URL, timeout=30.0)


def _access_token(client: httpx.Client, email: str) -> str:
    res = client.post(
        "/auth/v1/token",
        params={"grant_type": "password"},
        headers={"apikey": SUPABASE_ANON_KEY},
        json={"email": email, "password": TEST_PASSWORD},
    )
    res.raise_for_status()
    return res.json()["access_token"]


@pytest.fixture(scope="session")
def _env():
    client = _build_httpx()
    tokens = {email: _access_token(client, email) for email in TEST_USERS}
    yield tokens, client


@pytest.mark.parametrize("table", TENANT_SCOPED_TABLES)
def test_rls_bloquea_lectura_cross_tenant(table, _env):
    tokens, client = _env
    attacker, _victim = tokens.values()
    attacker_tid = _tenant_id_from_jwt(attacker)
    victim_tid = _tenant_id_from_jwt(_victim)
    assert attacker_tid != victim_tid, "Los dos tenants de prueba deben ser distintos"

    headers = {
        "apikey": SUPABASE_ANON_KEY,
        "Authorization": f"Bearer {attacker}",
        "Accept": "application/json",
    }
    res = client.get(
        f"/rest/v1/{table}",
        params={"select": "tenant_id", "tenant_id": f"eq.{victim_tid}"},
        headers=headers,
    )
    assert res.status_code in (200, 206), (
        f"[{table}] PostgREST devolvio {res.status_code}: {res.text[:200]}"
    )
    rows = res.json()
    leaked = [
        row.get("tenant_id")
        for row in rows
        if row.get("tenant_id") == victim_tid
    ]
    assert not leaked, (
        f"[{table}] ¡RLS roto! Un usuario del tenant {attacker_tid} vio "
        f"{len(leaked)} filas del tenant {victim_tid}."
    )


def test_rls_todos_los_jwt_tienen_tenant_id(_env):
    tokens, _client = _env
    for email, token in tokens.items():
        tenant_id = _tenant_id_from_jwt(token)
        assert tenant_id, f"El JWT de {email} no expone app_metadata.tenant_id"