from fastapi import APIRouter, Depends, HTTPException, status
from typing import List
from postgrest.exceptions import APIError
from decimal import Decimal
from datetime import date, timedelta, datetime, timezone
import uuid

from app.core.supabase_client import supabase_admin
from app.core.auth import get_current_tenant_id
from app.core.validators import assert_belongs_to_tenant
from app.modules.messaging import service as messaging_service
from .schemas import (
    SalonServiceCreate, SalonServiceUpdate, SalonServiceOut,
    SalonEmployeeCreate, SalonEmployeeUpdate, SalonEmployeeOut,
    SalonClientCreate, SalonClientUpdate, SalonClientOut,
    SalonAppointmentCreate, SalonAppointmentUpdate, SalonAppointmentOut,
    SalonProductCreate, SalonProductUpdate, SalonProductOut,
    SalonSaleCreate, SalonSaleOut,
    SalonCommissionSummaryOut,
    WaitlistEntryCreate, WaitlistEntryUpdate, WaitlistEntryOut,
)

router = APIRouter(prefix="/salon", tags=["Salon"])


def _json_safe(data: dict) -> dict:
    """Convierte tipos no serializables (Decimal, UUID, fechas) para Supabase."""
    def _conv(v):
        if isinstance(v, (Decimal, uuid.UUID, date, timedelta)):
            return str(v)
        return v
    return {k: _conv(v) for k, v in data.items()}


def _business_name(tenant_id: str) -> str:
    res = (
        supabase_admin.table("tenants")
        .select("name")
        .eq("id", tenant_id)
        .single()
        .execute()
    )
    return (res.data or {}).get("name", "Dokko")


def _salon_client(client_id):
    if not client_id:
        return None
    res = (
        supabase_admin.table("salon_clients")
        .select("*")
        .eq("id", str(client_id))
        .single()
        .execute()
    )
    return res.data or None


# ── Services ──────────────────────────────────────────────────────────────────

@router.get("/services", response_model=List[SalonServiceOut])
async def list_services(tenant_id: str = Depends(get_current_tenant_id)):
    res = supabase_admin.table("salon_services").select("*").eq("tenant_id", tenant_id).order("name").execute()
    return res.data


@router.post("/services", response_model=SalonServiceOut, status_code=status.HTTP_201_CREATED)
async def create_service(body: SalonServiceCreate, tenant_id: str = Depends(get_current_tenant_id)):
    payload = body.model_dump()
    payload["tenant_id"] = tenant_id
    res = supabase_admin.table("salon_services").insert(payload).execute()
    if not res.data:
        raise HTTPException(status_code=400, detail="Error al crear servicio")
    return res.data[0]


@router.patch("/services/{service_id}", response_model=SalonServiceOut)
async def update_service(service_id: uuid.UUID, body: SalonServiceUpdate, tenant_id: str = Depends(get_current_tenant_id)):
    payload = {k: v for k, v in body.model_dump().items() if v is not None}
    res = supabase_admin.table("salon_services").update(payload).eq("id", str(service_id)).eq("tenant_id", tenant_id).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Servicio no encontrado")
    return res.data[0]


@router.delete("/services/{service_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_service(service_id: uuid.UUID, tenant_id: str = Depends(get_current_tenant_id)):
    supabase_admin.table("salon_services").update({"is_active": False}).eq("id", str(service_id)).eq("tenant_id", tenant_id).execute()


# ── Employees ─────────────────────────────────────────────────────────────────

@router.get("/employees", response_model=List[SalonEmployeeOut])
async def list_employees(tenant_id: str = Depends(get_current_tenant_id)):
    res = supabase_admin.table("salon_employees").select("*").eq("tenant_id", tenant_id).eq("is_active", True).order("first_name").execute()
    return res.data


@router.post("/employees", response_model=SalonEmployeeOut, status_code=status.HTTP_201_CREATED)
async def create_employee(body: SalonEmployeeCreate, tenant_id: str = Depends(get_current_tenant_id)):
    payload = body.model_dump()
    payload["tenant_id"] = tenant_id
    if payload.get("resource_id"):
        payload["resource_id"] = str(payload["resource_id"])
    res = supabase_admin.table("salon_employees").insert(payload).execute()
    if not res.data:
        raise HTTPException(status_code=400, detail="Error al crear empleado")
    return res.data[0]


@router.patch("/employees/{employee_id}", response_model=SalonEmployeeOut)
async def update_employee(employee_id: uuid.UUID, body: SalonEmployeeUpdate, tenant_id: str = Depends(get_current_tenant_id)):
    payload = {k: v for k, v in body.model_dump().items() if v is not None}
    res = supabase_admin.table("salon_employees").update(payload).eq("id", str(employee_id)).eq("tenant_id", tenant_id).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Empleado no encontrado")
    return res.data[0]


# ── Clients ───────────────────────────────────────────────────────────────────

@router.get("/clients", response_model=List[SalonClientOut])
async def list_clients(tenant_id: str = Depends(get_current_tenant_id)):
    res = supabase_admin.table("salon_clients").select("*").eq("tenant_id", tenant_id).order("last_name").execute()
    return res.data


@router.post("/clients", response_model=SalonClientOut, status_code=status.HTTP_201_CREATED)
async def create_client(body: SalonClientCreate, tenant_id: str = Depends(get_current_tenant_id)):
    payload = body.model_dump(exclude_none=True)
    payload["tenant_id"] = tenant_id
    if payload.get("birthdate"):
        payload["birthdate"] = str(payload["birthdate"])
    if payload.get("consent_granted_at"):
        payload["consent_granted_at"] = str(payload["consent_granted_at"])
    res = supabase_admin.table("salon_clients").insert(payload).execute()
    if not res.data:
        raise HTTPException(status_code=400, detail="Error al crear cliente")
    return res.data[0]


@router.patch("/clients/{client_id}", response_model=SalonClientOut)
async def update_client(client_id: uuid.UUID, body: SalonClientUpdate, tenant_id: str = Depends(get_current_tenant_id)):
    payload = {k: v for k, v in body.model_dump().items() if v is not None}
    if "birthdate" in payload and payload["birthdate"]:
        payload["birthdate"] = str(payload["birthdate"])
    if "consent_granted_at" in payload and payload["consent_granted_at"]:
        payload["consent_granted_at"] = str(payload["consent_granted_at"])
    res = supabase_admin.table("salon_clients").update(payload).eq("id", str(client_id)).eq("tenant_id", tenant_id).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Cliente no encontrado")
    return res.data[0]


@router.delete("/clients/{client_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_client(client_id: uuid.UUID, tenant_id: str = Depends(get_current_tenant_id)):
    # FASE 25 — Ley 172-13: desvincular citas/ventas y auditar antes del borrado físico.
    supabase_admin.table("shared_agenda_appointments").update({"client_id": None})\
        .eq("client_id", str(client_id)).eq("tenant_id", tenant_id).execute()
    try:
        supabase_admin.table("audit_log").insert({
            "tenant_id": tenant_id,
            "action": "data_erasure_client",
            "entity": "salon_client",
            "entity_id": str(client_id),
            "metadata": {"law": "Ley 172-13", "scope": "full_erasure"},
        }).execute()
    except Exception:
        pass
    supabase_admin.table("salon_clients").delete().eq("id", str(client_id)).eq("tenant_id", tenant_id).execute()


@router.get("/clients/{client_id}/export-data")
async def export_client_data(client_id: uuid.UUID, tenant_id: str = Depends(get_current_tenant_id)):
    """Exportación de datos personales (Ley 172-13) de un cliente de salón."""
    res = supabase_admin.table("salon_clients")\
        .select("*")\
        .eq("id", str(client_id))\
        .eq("tenant_id", tenant_id)\
        .single()\
        .execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Cliente no encontrado")

    appointments = supabase_admin.table("shared_agenda_appointments")\
        .select("*")\
        .eq("client_id", str(client_id))\
        .eq("tenant_id", tenant_id)\
        .execute()
    sales = supabase_admin.table("salon_sales")\
        .select("*")\
        .eq("client_id", str(client_id))\
        .eq("tenant_id", tenant_id)\
        .execute()

    payload = {
        "law": "Ley 172-13 (Protección de Datos Personales)",
        "exported_at": datetime.now(timezone.utc).isoformat(),
        "tenant_id": tenant_id,
        "personal_data": res.data,
        "consent_granted_at": res.data.get("consent_granted_at"),
        "appointments": appointments.data or [],
        "sales": sales.data or [],
    }
    try:
        supabase_admin.table("audit_log").insert({
            "tenant_id": tenant_id,
            "action": "data_export_client",
            "entity": "salon_client",
            "entity_id": str(client_id),
            "metadata": {"law": "Ley 172-13", "pii": True},
        }).execute()
    except Exception:
        pass
    return payload


# ── Appointments (wrapped shared_agenda with module_reference='salon') ────────

@router.get("/appointments", response_model=List[SalonAppointmentOut])
async def list_appointments(tenant_id: str = Depends(get_current_tenant_id)):
    res = (
        supabase_admin.table("shared_agenda_appointments")
        .select("*")
        .eq("tenant_id", tenant_id)
        .eq("module_reference", "salon")
        .order("start_time")
        .execute()
    )
    return res.data


@router.post("/appointments", response_model=SalonAppointmentOut, status_code=status.HTTP_201_CREATED)
async def create_appointment(body: SalonAppointmentCreate, tenant_id: str = Depends(get_current_tenant_id)):
    assert_belongs_to_tenant("shared_agenda_resources", str(body.resource_id), tenant_id, "Recurso")
    assert_belongs_to_tenant("salon_clients", str(body.client_id) if body.client_id else None, tenant_id, "Cliente")

    payload = {
        "tenant_id": tenant_id,
        "resource_id": str(body.resource_id),
        "client_id": str(body.client_id) if body.client_id else None,
        "client_name": body.client_name,
        "start_time": body.start_time.isoformat(),
        "end_time": body.end_time.isoformat(),
        "notes": body.notes,
        "module_reference": "salon",
        "status": "scheduled",
    }
    try:
        appt_res = supabase_admin.table("shared_agenda_appointments").insert(payload).execute()
    except APIError as e:
        if "DOBLE_BOOKING" in str(e):
            raise HTTPException(status_code=409, detail="El recurso ya tiene una cita en ese horario.")
        raise e
    if not appt_res.data:
        raise HTTPException(status_code=400, detail="Error al crear cita. Puede haber conflicto de horario.")

    appt = appt_res.data[0]
    appt_id = appt["id"]

    # Link services
    if body.service_ids:
        for service_id in body.service_ids:
            svc_res = supabase_admin.table("salon_services").select("price").eq("id", str(service_id)).eq("tenant_id", tenant_id).single().execute()
            price = svc_res.data["price"] if svc_res.data else 0
            supabase_admin.table("salon_appointment_services").insert({
                "tenant_id": tenant_id,
                "appointment_id": appt_id,
                "service_id": str(service_id),
                "price_at_time": price,
            }).execute()

    # FASE 28 — Mensajería: agenda el recordatorio de cita (respecta consentimiento).
    if body.client_id:
        client = _salon_client(body.client_id)
        messaging_service.schedule_salon_reminder(
            appt, client, tenant_id, _business_name(tenant_id)
        )

    return appt


@router.patch("/appointments/{appointment_id}", response_model=SalonAppointmentOut)
async def update_appointment(appointment_id: uuid.UUID, body: SalonAppointmentUpdate, tenant_id: str = Depends(get_current_tenant_id)):
    existing = (
        supabase_admin.table("shared_agenda_appointments")
        .select("*")
        .eq("id", str(appointment_id))
        .eq("tenant_id", tenant_id)
        .single()
        .execute()
    )
    if not existing.data:
        raise HTTPException(status_code=404, detail="Cita no encontrada")
    existing_appt = existing.data

    payload = {k: v for k, v in body.model_dump().items() if v is not None}
    if "start_time" in payload:
        payload["start_time"] = payload["start_time"].isoformat()
    if "end_time" in payload:
        payload["end_time"] = payload["end_time"].isoformat()
    res = supabase_admin.table("shared_agenda_appointments").update(payload).eq("id", str(appointment_id)).eq("tenant_id", tenant_id).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Cita no encontrada")
    updated = res.data[0]

    # FASE 28 — Mensajería: recordatorios, lista de espera y feedback reactivos.
    business = _business_name(tenant_id)
    client_id = updated.get("client_id") or existing_appt.get("client_id")
    client = _salon_client(client_id)
    old_status = existing_appt.get("status")
    new_status = updated.get("status", old_status)

    if new_status == "cancelled" and old_status != "cancelled":
        # Cancelación: anula el recordatorio pendiente y avisa a la lista de espera.
        messaging_service.cancel_messages_for_reference(tenant_id, "salon", str(appointment_id))
        messaging_service.schedule_waitlist_notification(tenant_id, business)
    elif new_status == "completed" and old_status != "completed":
        messaging_service.schedule_salon_feedback(updated, client, tenant_id, business)
    elif new_status not in ("cancelled", "completed") and updated.get("start_time") != existing_appt.get("start_time"):
        # Reprogramación: cancela el recordatorio anterior y agenda el nuevo.
        messaging_service.cancel_messages_for_reference(tenant_id, "salon", str(appointment_id))
        messaging_service.schedule_salon_reminder(updated, client, tenant_id, business)

    return updated


# ── Waitlist (lista de espera) ────────────────────────────────────────────────

@router.get("/waitlist", response_model=List[WaitlistEntryOut])
async def list_waitlist(tenant_id: str = Depends(get_current_tenant_id)):
    res = (
        supabase_admin.table("salon_waitlist")
        .select("*")
        .eq("tenant_id", tenant_id)
        .order("created_at")
        .execute()
    )
    return res.data


@router.post("/waitlist", response_model=WaitlistEntryOut, status_code=status.HTTP_201_CREATED)
async def add_waitlist(body: WaitlistEntryCreate, tenant_id: str = Depends(get_current_tenant_id)):
    payload = body.model_dump(exclude_none=True)
    payload["tenant_id"] = tenant_id
    if payload.get("client_id"):
        payload["client_id"] = str(payload["client_id"])
        client = _salon_client(payload["client_id"])
        if not payload.get("client_name") and client:
            payload["client_name"] = (
                f"{client.get('first_name', '')} {client.get('last_name', '')}".strip()
            )
        if not payload.get("phone") and client:
            payload["phone"] = client.get("phone")
    if not payload.get("client_name"):
        raise HTTPException(status_code=400, detail="El nombre del cliente es obligatorio.")
    res = supabase_admin.table("salon_waitlist").insert(payload).execute()
    if not res.data:
        raise HTTPException(status_code=400, detail="Error al agregar a la lista de espera")
    return res.data[0]


@router.patch("/waitlist/{entry_id}", response_model=WaitlistEntryOut)
async def update_waitlist(entry_id: uuid.UUID, body: WaitlistEntryUpdate, tenant_id: str = Depends(get_current_tenant_id)):
    payload = {k: v for k, v in body.model_dump().items() if v is not None}
    res = supabase_admin.table("salon_waitlist").update(payload).eq("id", str(entry_id)).eq("tenant_id", tenant_id).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Entrada de lista de espera no encontrada")
    return res.data[0]


@router.delete("/waitlist/{entry_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_waitlist(entry_id: uuid.UUID, tenant_id: str = Depends(get_current_tenant_id)):
    supabase_admin.table("salon_waitlist").delete().eq("id", str(entry_id)).eq("tenant_id", tenant_id).execute()


# ── Products (POS) ────────────────────────────────────────────────────────────

@router.get("/products", response_model=List[SalonProductOut])
async def list_products(tenant_id: str = Depends(get_current_tenant_id)):
    res = supabase_admin.table("salon_products")\
        .select("*")\
        .eq("tenant_id", tenant_id)\
        .eq("is_active", True)\
        .order("name")\
        .execute()
    return res.data


@router.post("/products", response_model=SalonProductOut, status_code=status.HTTP_201_CREATED)
async def create_product(body: SalonProductCreate, tenant_id: str = Depends(get_current_tenant_id)):
    payload = _json_safe(body.model_dump())
    payload["tenant_id"] = tenant_id
    res = supabase_admin.table("salon_products").insert(payload).execute()
    if not res.data:
        raise HTTPException(status_code=400, detail="Error al crear producto")
    return res.data[0]


@router.patch("/products/{product_id}", response_model=SalonProductOut)
async def update_product(product_id: uuid.UUID, body: SalonProductUpdate, tenant_id: str = Depends(get_current_tenant_id)):
    payload = _json_safe({k: v for k, v in body.model_dump().items() if v is not None})
    if not payload:
        raise HTTPException(status_code=400, detail="No hay campos para actualizar.")
    res = supabase_admin.table("salon_products").update(payload).eq("id", str(product_id)).eq("tenant_id", tenant_id).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Producto no encontrado.")
    return res.data[0]


@router.delete("/products/{product_id}", status_code=status.HTTP_204_NO_CONTENT)
async def deactivate_product(product_id: uuid.UUID, tenant_id: str = Depends(get_current_tenant_id)):
    """Soft delete: marca el producto como inactivo."""
    supabase_admin.table("salon_products").update({"is_active": False}).eq("id", str(product_id)).eq("tenant_id", tenant_id).execute()


# ── Sales (POS) ───────────────────────────────────────────────────────────────

@router.post("/sales", response_model=SalonSaleOut, status_code=status.HTTP_201_CREATED)
async def create_sale(body: SalonSaleCreate, tenant_id: str = Depends(get_current_tenant_id)):
    """
    Crea una venta con sus ítems. El trigger de BD descuenta stock automáticamente.
    Si se asigna un estilista (employee_id), calcula y registra su comisión.
    """
    for item in body.items:
        assert_belongs_to_tenant("salon_products", str(item.product_id), tenant_id, "Producto")
    if body.employee_id:
        assert_belongs_to_tenant("salon_employees", str(body.employee_id), tenant_id, "Empleado")
    if body.client_id:
        assert_belongs_to_tenant("salon_clients", str(body.client_id), tenant_id, "Cliente")

    # Validar stock disponible antes de vender
    product_ids = sorted({str(item.product_id) for item in body.items})
    products_res = supabase_admin.table("salon_products").select("id, name, stock_quantity").in_("id", product_ids).execute()
    stock_by_id = {str(p["id"]): p for p in (products_res.data or [])}
    quantities = {}
    for item in body.items:
        quantities[str(item.product_id)] = quantities.get(str(item.product_id), 0) + item.quantity
    for pid, qty in quantities.items():
        product = stock_by_id.get(pid)
        if product is None or int(product.get("stock_quantity") or 0) < qty:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Stock insuficiente para '{product['name'] if product else 'Producto'}'. Disponible: {int(product.get('stock_quantity') or 0)}, solicitado: {qty}.",
            )

    # Calcular total
    total = sum(item.unit_price * item.quantity for item in body.items)

    # Comisión si hay estilista asignado
    commission_rate = 0.0
    commission_amount = 0.0
    if body.employee_id:
        emp_res = supabase_admin.table("salon_employees").select("commission_rate").eq("id", str(body.employee_id)).eq("tenant_id", tenant_id).single().execute()
        if emp_res.data:
            commission_rate = float(emp_res.data.get("commission_rate") or 0)
            commission_amount = round(total * commission_rate / 100.0, 2)

    # Insertar la venta principal
    sale_res = supabase_admin.table("salon_sales").insert({
        "tenant_id": tenant_id,
        "client_id": str(body.client_id) if body.client_id else None,
        "employee_id": str(body.employee_id) if body.employee_id else None,
        "total": float(total),
        "commission_amount": commission_amount,
        "payment_method": body.payment_method,
        "notes": body.notes,
    }).execute()

    sale = sale_res.data[0]
    sale_id = sale["id"]

    # Insertar ítems (el trigger descuenta stock por cada uno)
    items_payload = [
        {
            "sale_id": sale_id,
            "tenant_id": tenant_id,
            "product_id": str(item.product_id),
            "quantity": item.quantity,
            "unit_price": float(item.unit_price),
            "subtotal": float(item.unit_price * item.quantity),
        }
        for item in body.items
    ]
    supabase_admin.table("salon_sale_items").insert(items_payload).execute()

    # Registrar comisión
    if body.employee_id and commission_amount > 0:
        supabase_admin.table("salon_commissions").insert({
            "tenant_id": tenant_id,
            "sale_id": sale_id,
            "employee_id": str(body.employee_id),
            "amount": commission_amount,
            "rate": commission_rate,
        }).execute()

    return sale


@router.get("/sales", response_model=List[SalonSaleOut])
async def list_sales(tenant_id: str = Depends(get_current_tenant_id)):
    res = supabase_admin.table("salon_sales")\
        .select("*")\
        .eq("tenant_id", tenant_id)\
        .order("sold_at", desc=True)\
        .limit(50)\
        .execute()
    return res.data


# ── Reports ───────────────────────────────────────────────────────────────────

@router.get("/reports/revenue")
async def report_revenue(days: int = 30, tenant_id: str = Depends(get_current_tenant_id)):
    """Ingresos diarios del POS para los últimos `days` días."""
    today = date.today()
    result = []

    for i in range(days - 1, -1, -1):
        day = today - timedelta(days=i)
        day_str = day.isoformat()

        sales_res = supabase_admin.table("salon_sales")\
            .select("total")\
            .eq("tenant_id", tenant_id)\
            .gte("sold_at", f"{day_str}T00:00:00")\
            .lte("sold_at", f"{day_str}T23:59:59")\
            .execute()
        sales_total = sum(float(r.get("total", 0)) for r in sales_res.data)

        result.append({
            "date": day_str,
            "pos": round(sales_total, 2),
            "total": round(sales_total, 2),
        })

    return result


@router.get("/reports/commissions", response_model=List[SalonCommissionSummaryOut])
async def report_commissions(days: int = 30, tenant_id: str = Depends(get_current_tenant_id)):
    """Resumen de comisiones por estilista para los últimos `days` días."""
    since = (date.today() - timedelta(days=days)).isoformat()

    res = supabase_admin.table("salon_commissions")\
        .select("*, salon_employees(first_name, last_name)")\
        .eq("tenant_id", tenant_id)\
        .gte("created_at", f"{since}T00:00:00")\
        .order("created_at", desc=True)\
        .execute()

    by_emp: dict[str, dict] = {}
    for row in res.data or []:
        emp = (row.get("salon_employees") or {})
        eid = str(row.get("employee_id"))
        name = f"{emp.get('first_name', '')} {emp.get('last_name', '')}".strip() or "Sin nombre"
        bucket = by_emp.setdefault(eid, {
            "employee_id": eid,
            "employee_name": name,
            "sales_count": 0,
            "total_sales": 0.0,
            "total_commission": 0.0,
        })
        bucket["sales_count"] += 1
        sale_res = supabase_admin.table("salon_sales").select("total").eq("id", str(row["sale_id"])).eq("tenant_id", tenant_id).single().execute()
        if sale_res.data:
            bucket["total_sales"] = round(bucket["total_sales"] + float(sale_res.data.get("total") or 0), 2)
        bucket["total_commission"] = round(bucket["total_commission"] + float(row.get("amount") or 0), 2)

    return sorted(by_emp.values(), key=lambda r: r["total_commission"], reverse=True)
