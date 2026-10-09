"""
FASE 26 — Test de carga básico.

Verifica que el backend responde correctamente bajo N peticiones GET concurrentes
(idempotentes: /health y una lectura autenticada) sin errores 5xx y con latencia razonable.
"""
from __future__ import annotations

import os
import time
from concurrent.futures import ThreadPoolExecutor

import httpx

BASE = os.getenv("DOKKO_API_URL", "http://127.0.0.1:8000")


def _build_headers() -> dict:
    import base64
    import json

    url = os.getenv("SUPABASE_URL", "").rstrip("/")
    anon = os.getenv("SUPABASE_KEY", "")
    email = "gym-admin@dokko.dev"
    password = "DokkoTest1!"
    if not (url and anon):
        return {}

    with httpx.Client(base_url=url, timeout=30.0) as client:
        res = client.post(
            "/auth/v1/token",
            params={"grant_type": "password"},
            headers={"apikey": anon},
            json={"email": email, "password": password},
        )
        res.raise_for_status()
        token = res.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def test_backend_responde_bajo_carga_concurrente():
    headers = _build_headers()
    concurrency = 40
    errors: list[str] = []
    latencies_ms: list[float] = []

    def worker(i: int) -> None:
        target = "/health" if i % 2 == 0 else "/gym/dashboard/kpis"
        start = time.perf_counter()
        try:
            res = httpx.get(f"{BASE}{target}", headers=headers, timeout=15.0)
            elapsed = (time.perf_counter() - start) * 1000
            latencies_ms.append(elapsed)
            if res.status_code >= 500:
                errors.append(f"{target} -> {res.status_code}")
        except httpx.HTTPError as exc:  # noqa: PERF203
            errors.append(f"{target} -> {type(exc).__name__}")

    with ThreadPoolExecutor(max_workers=concurrency) as pool:
        list(pool.map(worker, range(concurrency)))

    assert not errors, f"Errores bajo carga: {errors[:10]}"
    p95 = sorted(latencies_ms)[int(len(latencies_ms) * 0.95) - 1]
    assert p95 < 2000, f"p95 de latencia demasiado alto: {p95:.0f}ms"
    assert len(latencies_ms) == concurrency