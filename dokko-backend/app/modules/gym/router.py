from fastapi import APIRouter, Depends, HTTPException, status
from app.core.auth import get_current_tenant_id
from app.core.supabase_client import supabase_admin
from app.core.validators import assert_belongs_to_tenant
from .schemas import (
    GymMemberCreate, GymMemberUpdate, GymMemberOut,
    GymMembershipPlanCreate, GymMembershipPlanUpdate, GymMembershipPlanOut,
    GymPaymentCreate, GymPaymentOut,
    GymCheckinCreate, GymCheckinOut,
    GymProductCreate, GymProductUpdate, GymProductOut,
    GymSaleCreate, GymSaleOut,
    GymDashboardKpisOut,
    GymSettingsUpdate, GymSettingsOut,
    GymChurnOverview, GymChurnMemberOut, GymChurnMetricPoint,
    GymEmployeeCreate, GymEmployeeUpdate, GymEmployeeOut,
)
from decimal import Decimal
from typing import Optional
import uuid
import postgrest.exceptions
from datetime import date, datetime, timedelta, timezone
import calendar

router = APIRouter()


def _json_safe(data: dict) -> dict:
    """Convierte tipos no serializables (Decimal, UUID, fechas) para el insert/update de Supabase."""
    def _conv(v):
        if isinstance(v, (Decimal, uuid.UUID, date, datetime)):
            return str(v)
        return v
    return {k: _conv(v) for k, v in data.items()}


# ═══════════════════════════════════════════════════════
# Dashboard
# ═══════════════════════════════════════════════════════

@router.get("/dashboard/kpis", response_model=GymDashboardKpisOut)
def get_dashboard_kpis(tenant_id: str = Depends(get_current_tenant_id)):
    today_str = date.today().isoformat()
    now = datetime.now()
    first_day = date(now.year, now.month, 1).isoformat()
    last_day = date(now.year, now.month, calendar.monthrange(now.year, now.month)[1]).isoformat()
    in_7_days = (date.today() + timedelta(days=7)).isoformat()

    # 1. Active members count
    members_res = supabase_admin.table("gym_members")\
        .select("id", count="exact")\
        .eq("tenant_id", tenant_id)\
        .eq("status", "active")\
        .execute()
    active_count = members_res.count or 0

    # 2. Upcoming expirations count
    expirations_res = supabase_admin.table("gym_members")\
        .select("id", count="exact")\
        .eq("tenant_id", tenant_id)\
        .gte("membership_expires_at", today_str)\
        .lte("membership_expires_at", in_7_days)\
        .execute()
    upcoming_count = expirations_res.count or 0

    # 3. Checkins today count
    checkins_res = supabase_admin.table("gym_checkins")\
        .select("id", count="exact")\
        .eq("tenant_id", tenant_id)\
        .gte("checked_in_at", f"{today_str}T00:00:00")\
        .execute()
    checkins_today = checkins_res.count or 0

    # 4. Monthly revenue (sales + payments)
    sales_res = supabase_admin.table("gym_sales")\
        .select("total")\
        .eq("tenant_id", tenant_id)\
        .gte("sold_at", f"{first_day}T00:00:00")\
        .lte("sold_at", f"{last_day}T23:59:59")\
        .execute()
    
    payments_res = supabase_admin.table("gym_membership_payments")\
        .select("amount")\
        .eq("tenant_id", tenant_id)\
        .gte("paid_at", f"{first_day}T00:00:00")\
        .lte("paid_at", f"{last_day}T23:59:59")\
        .execute()

    sales_total = sum(item.get("total", 0) for item in sales_res.data)
    payments_total = sum(item.get("amount", 0) for item in payments_res.data)
    monthly_revenue = Decimal(str(sales_total)) + Decimal(str(payments_total))

    return GymDashboardKpisOut(
        active_members_count=active_count,
        monthly_revenue=monthly_revenue,
        upcoming_expirations_count=upcoming_count,
        checkins_today=checkins_today,
    )


# ═══════════════════════════════════════════════════════
# Membership Plans
# ═══════════════════════════════════════════════════════

@router.get("/plans", response_model=list[GymMembershipPlanOut])
def list_plans(tenant_id: str = Depends(get_current_tenant_id)):
    res = supabase_admin.table("gym_membership_plans")\
        .select("*")\
        .eq("tenant_id", tenant_id)\
        .eq("is_active", True)\
        .execute()
    return res.data


@router.post("/plans", response_model=GymMembershipPlanOut, status_code=status.HTTP_201_CREATED)
def create_plan(body: GymMembershipPlanCreate, tenant_id: str = Depends(get_current_tenant_id)):
    res = supabase_admin.table("gym_membership_plans")\
        .insert({"tenant_id": tenant_id, **_json_safe(body.model_dump())})\
        .execute()
    return res.data[0]


@router.patch("/plans/{plan_id}", response_model=GymMembershipPlanOut)
def update_plan(plan_id: str, body: GymMembershipPlanUpdate, tenant_id: str = Depends(get_current_tenant_id)):
    updates = _json_safe(body.model_dump(exclude_unset=True))
    if not updates:
        raise HTTPException(status_code=400, detail="No hay campos para actualizar.")
    res = supabase_admin.table("gym_membership_plans")\
        .update(updates)\
        .eq("id", plan_id)\
        .eq("tenant_id", tenant_id)\
        .execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Plan no encontrado.")
    return res.data[0]


@router.delete("/plans/{plan_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_plan(plan_id: str, tenant_id: str = Depends(get_current_tenant_id)):
    supabase_admin.table("gym_membership_plans")\
        .delete()\
        .eq("id", plan_id)\
        .eq("tenant_id", tenant_id)\
        .execute()


# ═══════════════════════════════════════════════════════
# Members
# ═══════════════════════════════════════════════════════

@router.get("/members", response_model=list[GymMemberOut])
def list_members(tenant_id: str = Depends(get_current_tenant_id)):
    res = supabase_admin.table("gym_members")\
        .select("*")\
        .eq("tenant_id", tenant_id)\
        .order("last_name")\
        .execute()
    return res.data


@router.post("/members", response_model=GymMemberOut, status_code=status.HTTP_201_CREATED)
def create_member(body: GymMemberCreate, tenant_id: str = Depends(get_current_tenant_id)):
    payload = _json_safe({"tenant_id": tenant_id, **body.model_dump(exclude_none=True)})
    res = supabase_admin.table("gym_members")\
        .insert(payload)\
        .execute()
    return res.data[0]


@router.get("/members/{member_id}", response_model=GymMemberOut)
def get_member(member_id: str, tenant_id: str = Depends(get_current_tenant_id)):
    res = supabase_admin.table("gym_members")\
        .select("*")\
        .eq("id", member_id)\
        .eq("tenant_id", tenant_id)\
        .single()\
        .execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Miembro no encontrado.")
    return res.data


@router.patch("/members/{member_id}", response_model=GymMemberOut)
def update_member(member_id: str, body: GymMemberUpdate, tenant_id: str = Depends(get_current_tenant_id)):
    updates = {k: v for k, v in body.model_dump().items() if v is not None}
    res = supabase_admin.table("gym_members")\
        .update(_json_safe(updates))\
        .eq("id", member_id)\
        .eq("tenant_id", tenant_id)\
        .execute()
    return res.data[0]


@router.delete("/members/{member_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_member(member_id: str, tenant_id: str = Depends(get_current_tenant_id)):
    # FASE 25 — Ley 172-13: antes de borrar, desvincular ventas (FK) y auditar.
    supabase_admin.table("gym_sales")\
        .update({"member_id": None})\
        .eq("member_id", member_id)\
        .eq("tenant_id", tenant_id)\
        .execute()
    try:
        supabase_admin.table("audit_log").insert({
            "tenant_id": tenant_id,
            "action": "data_erasure_member",
            "entity": "gym_member",
            "entity_id": member_id,
            "metadata": {"law": "Ley 172-13", "scope": "full_erasure"},
        }).execute()
    except Exception:
        pass
    supabase_admin.table("gym_members")\
        .delete()\
        .eq("id", member_id)\
        .eq("tenant_id", tenant_id)\
        .execute()


@router.get("/members/{member_id}/export-data")
def export_member_data(member_id: str, tenant_id: str = Depends(get_current_tenant_id)):
    """Exportación de datos personales (Ley 172-13): miembro + pagos + check-ins."""
    member = supabase_admin.table("gym_members")\
        .select("*")\
        .eq("id", member_id)\
        .eq("tenant_id", tenant_id)\
        .single()\
        .execute()
    if not member.data:
        raise HTTPException(status_code=404, detail="Miembro no encontrado.")

    member_row = dict(member.data)
    payments = supabase_admin.table("gym_membership_payments")\
        .select("*")\
        .eq("member_id", member_id)\
        .eq("tenant_id", tenant_id)\
        .execute()
    checkins = supabase_admin.table("gym_checkins")\
        .select("*")\
        .eq("member_id", member_id)\
        .eq("tenant_id", tenant_id)\
        .execute()

    payload = {
        "law": "Ley 172-13 (Protección de Datos Personales)",
        "exported_at": datetime.now(timezone.utc).isoformat(),
        "tenant_id": tenant_id,
        "personal_data": member_row,
        "consent_granted_at": member_row.get("consent_granted_at"),
        "membership_payments": payments.data or [],
        "checkins": checkins.data or [],
    }
    try:
        supabase_admin.table("audit_log").insert({
            "tenant_id": tenant_id,
            "action": "data_export_member",
            "entity": "gym_member",
            "entity_id": member_id,
            "metadata": {"law": "Ley 172-13", "pii": True},
        }).execute()
    except Exception:
        pass
    return payload


# ═══════════════════════════════════════════════════════
# Membership Payments
# ═══════════════════════════════════════════════════════

@router.get("/members/{member_id}/payments", response_model=list[GymPaymentOut])
def list_member_payments(member_id: str, tenant_id: str = Depends(get_current_tenant_id)):
    res = supabase_admin.table("gym_membership_payments")\
        .select("*")\
        .eq("member_id", member_id)\
        .eq("tenant_id", tenant_id)\
        .order("paid_at", desc=True)\
        .execute()
    return res.data


@router.post("/payments", response_model=GymPaymentOut, status_code=status.HTTP_201_CREATED)
def register_payment(body: GymPaymentCreate, tenant_id: str = Depends(get_current_tenant_id)):
    """
    Registrar un pago activa el trigger en BD que actualiza
    membership_expires_at del miembro automáticamente.
    """
    assert_belongs_to_tenant("gym_members", str(body.member_id) if body.member_id else None, tenant_id, "Miembro")
    assert_belongs_to_tenant("gym_membership_plans", str(body.plan_id) if body.plan_id else None, tenant_id, "Plan")
    
    res = supabase_admin.table("gym_membership_payments")\
        .insert({
            "tenant_id": tenant_id,
            **_json_safe(body.model_dump())
        })\
        .execute()
    return res.data[0]


# ═══════════════════════════════════════════════════════
# Check-ins
# ═══════════════════════════════════════════════════════

@router.get("/checkins/today", response_model=list[GymCheckinOut])
def list_todays_checkins(tenant_id: str = Depends(get_current_tenant_id)):
    from datetime import date
    today = date.today().isoformat()
    res = supabase_admin.table("gym_checkins")\
        .select("*, gym_members(first_name, last_name)")\
        .eq("tenant_id", tenant_id)\
        .gte("checked_in_at", f"{today}T00:00:00")\
        .order("checked_in_at", desc=True)\
        .execute()
    return res.data


@router.post("/checkins", response_model=GymCheckinOut, status_code=status.HTTP_201_CREATED)
def create_checkin(body: GymCheckinCreate, tenant_id: str = Depends(get_current_tenant_id)):
    assert_belongs_to_tenant("gym_members", str(body.member_id) if body.member_id else None, tenant_id, "Miembro")
    res = supabase_admin.table("gym_checkins")\
        .insert({"tenant_id": tenant_id, **_json_safe(body.model_dump())})\
        .execute()
    return res.data[0]


# ═══════════════════════════════════════════════════════
# Products / Inventory
# ═══════════════════════════════════════════════════════

@router.get("/products", response_model=list[GymProductOut])
def list_products(tenant_id: str = Depends(get_current_tenant_id)):
    res = supabase_admin.table("gym_products")\
        .select("*")\
        .eq("tenant_id", tenant_id)\
        .eq("is_active", True)\
        .order("name")\
        .execute()
    return res.data


@router.post("/products", response_model=GymProductOut, status_code=status.HTTP_201_CREATED)
def create_product(body: GymProductCreate, tenant_id: str = Depends(get_current_tenant_id)):
    res = supabase_admin.table("gym_products")\
        .insert({"tenant_id": tenant_id, **_json_safe(body.model_dump(exclude_none=True))})\
        .execute()
    return res.data[0]


@router.patch("/products/{product_id}", response_model=GymProductOut)
def update_product(product_id: str, body: GymProductUpdate, tenant_id: str = Depends(get_current_tenant_id)):
    updates = _json_safe(body.model_dump(exclude_unset=True))
    if not updates:
        raise HTTPException(status_code=400, detail="No hay campos para actualizar.")
    res = supabase_admin.table("gym_products")\
        .update(updates)\
        .eq("id", product_id)\
        .eq("tenant_id", tenant_id)\
        .execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Producto no encontrado.")
    return res.data[0]


@router.delete("/products/{product_id}", status_code=status.HTTP_204_NO_CONTENT)
def deactivate_product(product_id: str, tenant_id: str = Depends(get_current_tenant_id)):
    """Soft delete: marca el producto como inactivo."""
    supabase_admin.table("gym_products")\
        .update({"is_active": False})\
        .eq("id", product_id)\
        .eq("tenant_id", tenant_id)\
        .execute()


# ═══════════════════════════════════════════════════════
# Sales (POS)
# ═══════════════════════════════════════════════════════

@router.post("/sales", response_model=GymSaleOut, status_code=status.HTTP_201_CREATED)
def create_sale(body: GymSaleCreate, tenant_id: str = Depends(get_current_tenant_id)):
    """
    Crea una venta e inserta sus ítems. El trigger de BD descuenta el stock
    automáticamente al insertar cada sale_item.
    """
    assert_belongs_to_tenant("gym_members", str(body.member_id) if body.member_id else None, tenant_id, "Miembro")
    for item in body.items:
        assert_belongs_to_tenant("gym_products", str(item.product_id), tenant_id, "Producto")

    # Validar stock disponible antes de vender
    product_ids = sorted({str(item.product_id) for item in body.items})
    products_res = supabase_admin.table("gym_products").select("id, name, stock_quantity").in_("id", product_ids).execute()
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

    # Insertar la venta principal
    sale_res = supabase_admin.table("gym_sales").insert({
        "tenant_id": tenant_id,
        "member_id": str(body.member_id) if body.member_id else None,
        "total": float(total),
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
    supabase_admin.table("gym_sale_items").insert(items_payload).execute()

    return sale


@router.get("/sales", response_model=list[GymSaleOut])
def list_sales(tenant_id: str = Depends(get_current_tenant_id)):
    res = supabase_admin.table("gym_sales")\
        .select("*")\
        .eq("tenant_id", tenant_id)\
        .order("sold_at", desc=True)\
        .limit(50)\
        .execute()
    return res.data


# ═══════════════════════════════════════════════════════
# Reports
# ═══════════════════════════════════════════════════════

@router.get("/reports/revenue")
def report_revenue(days: int = 30, tenant_id: str = Depends(get_current_tenant_id)):
    """
    Retorna ingresos diarios (pagos de membresía + ventas POS)
    para los últimos `days` días.
    """
    today = date.today()
    result = []

    for i in range(days - 1, -1, -1):
        day = today - timedelta(days=i)
        day_str = day.isoformat()
        start = f"{day_str}T00:00:00"
        end   = f"{day_str}T23:59:59"

        payments_res = supabase_admin.table("gym_membership_payments")\
            .select("amount")\
            .eq("tenant_id", tenant_id)\
            .gte("paid_at", start)\
            .lte("paid_at", end)\
            .execute()
        payments_total = sum(float(r.get("amount", 0)) for r in payments_res.data)

        sales_res = supabase_admin.table("gym_sales")\
            .select("total")\
            .eq("tenant_id", tenant_id)\
            .gte("sold_at", start)\
            .lte("sold_at", end)\
            .execute()
        sales_total = sum(float(r.get("total", 0)) for r in sales_res.data)

        result.append({
            "date": day_str,
            "memberships": round(payments_total, 2),
            "pos": round(sales_total, 2),
            "total": round(payments_total + sales_total, 2),
        })

    return result


@router.get("/reports/checkins")
def report_checkins(days: int = 30, tenant_id: str = Depends(get_current_tenant_id)):
    """Check-ins diarios para los últimos `days` días."""
    today = date.today()
    result = []

    for i in range(days - 1, -1, -1):
        day = today - timedelta(days=i)
        day_str = day.isoformat()

        res = supabase_admin.table("gym_checkins")\
            .select("id", count="exact")\
            .eq("tenant_id", tenant_id)\
            .gte("checked_in_at", f"{day_str}T00:00:00")\
            .lte("checked_in_at", f"{day_str}T23:59:59")\
            .execute()

        result.append({
            "date": day_str,
            "count": res.count or 0,
        })

    return result


@router.get("/reports/members/status")
def report_members_status(tenant_id: str = Depends(get_current_tenant_id)):
    """Distribución de miembros por estado."""
    statuses = ["active", "expired", "suspended", "cancelled"]
    result = {}

    for s in statuses:
        res = supabase_admin.table("gym_members")\
            .select("id", count="exact")\
            .eq("tenant_id", tenant_id)\
            .eq("status", s)\
            .execute()
        result[s] = res.count or 0

    return result


# ═══════════════════════════════════════════════════════
# Churn / Revenue Recovery
# ═══════════════════════════════════════════════════════

def _parse_dt(v) -> Optional[datetime]:
    if not v:
        return None
    try:
        return datetime.fromisoformat(str(v).replace("Z", "+00:00"))
    except ValueError:
        return None


def _add_months(d: date, delta: int) -> date:
    month = d.month - 1 + delta
    year = d.year + month // 12
    month = month % 12 + 1
    return date(year, month, 1)


def _compute_churn_overview(members: list, last_checkin_by_member: dict, today: date, now: datetime) -> tuple:
    """Lógica de "miembro en riesgo" y métricas históricas. Corres en el servidor,
    sin cálculo manual del negocio: baja asistencia (≥14 días sin check-in) y/o
    vencimiento de membresía (≤30 días o ya vencida)."""
    at_risk = []
    active_members_count = 0

    for m in members:
        if m.get("status") != "active":
            continue
        active_members_count += 1

        reasons = []
        last_ci = last_checkin_by_member.get(m["id"])
        days_since = (now - last_ci).days if last_ci else None
        if days_since is None:
            reasons.append("Sin check-ins registrados")
        elif days_since >= 14:
            reasons.append(f"Sin check-in en {days_since} días")

        exp_str = m.get("membership_expires_at")
        exp = date.fromisoformat(str(exp_str)) if exp_str else None
        days_until = None
        if exp:
            days_until = (exp - today).days
            if days_until < 0:
                reasons.append(f"Membresía vencida desde hace {-days_until} días")
            elif days_until <= 30:
                reasons.append(f"Membresía vence en {days_until} días")

        if not reasons:
            continue

        at_risk.append(GymChurnMemberOut(
            member_id=m["id"],
            first_name=m.get("first_name", ""),
            last_name=m.get("last_name", ""),
            membership_expires_at=exp,
            last_checkin_at=last_ci,
            days_since_last_checkin=days_since,
            days_until_expiry=days_until,
            risk_level="alto" if len(reasons) >= 2 else "medio",
            reasons=reasons,
        ))

    at_risk.sort(key=lambda r: (0 if r.risk_level == "alto" else 1, r.last_name))

    # Churn histórico: por cada uno de los últimos 6 meses.
    base = today.replace(day=1)
    points = []
    total_churned = total_active = 0
    for i in range(5, -1, -1):
        first = _add_months(base, -i)
        last = date(first.year, first.month, calendar.monthrange(first.year, first.month)[1])

        churned = active_end = 0
        for m in members:
            created = _parse_dt(m.get("created_at")).date() if _parse_dt(m.get("created_at")) else None
            if created and created > last:
                continue  # aún no existía el miembro a fin de mes
            exp_str = m.get("membership_expires_at")
            exp = date.fromisoformat(str(exp_str)) if exp_str else None
            lapsed_this_month = (
                exp is not None
                and first <= exp <= last
                and (m.get("status") in ("expired", "suspended") or exp <= today)
            )
            if lapsed_this_month:
                churned += 1
            if m.get("status") != "cancelled" and (exp is None or exp > last):
                active_end += 1

        rate = round(churned / active_end * 100, 1) if active_end else 0.0
        points.append(GymChurnMetricPoint(
            month=f"{first.year}-{first.month:02d}",
            churned=churned,
            active_end=active_end,
            churn_rate=rate,
        ))
        total_churned += churned
        total_active += active_end

    churn_rate_6m = round(total_churned / total_active * 100, 1) if total_active else 0.0
    return active_members_count, churn_rate_6m, at_risk, points


@router.get("/churn/overview", response_model=GymChurnOverview)
def churn_overview(tenant_id: str = Depends(get_current_tenant_id)):
    """Miembros en riesgo (reglas automáticas) + métricas de churn de 6 meses."""
    members = supabase_admin.table("gym_members")\
        .select("id, first_name, last_name, status, membership_expires_at, created_at")\
        .eq("tenant_id", tenant_id)\
        .execute()
    members = members.data

    cutoff = (datetime.now(timezone.utc) - timedelta(days=45)).isoformat()
    checkins = supabase_admin.table("gym_checkins")\
        .select("member_id, checked_in_at")\
        .eq("tenant_id", tenant_id)\
        .gte("checked_in_at", cutoff)\
        .execute()

    last_checkin_by_member: dict = {}
    for c in checkins.data:
        t = _parse_dt(c.get("checked_in_at"))
        if t is None:
            continue
        prev = last_checkin_by_member.get(c["member_id"])
        if prev is None or t > prev:
            last_checkin_by_member[c["member_id"]] = t

    now = datetime.now(timezone.utc)
    today = date.today()
    active_count, rate_6m, at_risk, points = _compute_churn_overview(
        members, last_checkin_by_member, today, now)

    return GymChurnOverview(
        at_risk=at_risk,
        at_risk_count=len(at_risk),
        active_members_count=active_count,
        churn_rate_6m=rate_6m,
        months=points,
    )


@router.post("/churn/remind/{member_id}")
def churn_remind(member_id: str, tenant_id: str = Depends(get_current_tenant_id)):
    """Registra el recordatorio al miembro en riesgo en el audit_log del tenant."""
    res = supabase_admin.table("gym_members")\
        .select("id, first_name, last_name")\
        .eq("id", member_id)\
        .eq("tenant_id", tenant_id)\
        .maybe_single()\
        .execute()
    if res is None or not res.data:
        raise HTTPException(status_code=404, detail="Miembro no encontrado.")

    supabase_admin.table("audit_log").insert({
        "tenant_id": tenant_id,
        "action": "churn_reminder",
        "entity": "gym_member",
        "details": {"member_id": member_id, "member_name": f"{res.data.get('first_name', '')} {res.data.get('last_name', '')}".strip()},
    }).execute()

    return {"ok": True, "message": "Recordatorio de recuperación enviado al miembro."}


# ═══════════════════════════════════════════════════════
# Settings
# ═══════════════════════════════════════════════════════

@router.get("/settings", response_model=GymSettingsOut)
def get_settings(tenant_id: str = Depends(get_current_tenant_id)):
    """Retorna la configuración del gym para este tenant. Crea un row vacío si no existe."""
    try:
        res = supabase_admin.table("gym_settings")\
            .select("*")\
            .eq("tenant_id", tenant_id)\
            .execute()
    except postgrest.exceptions.APIError as e:
        if "PGRST205" in str(e):
            return {"tenant_id": tenant_id}  # tabla aún no migrada (006)
        raise e

    if res.data:
        return res.data[0]

    # Primera vez: insertar defaults
    default = supabase_admin.table("gym_settings")\
        .insert({"tenant_id": tenant_id})\
        .execute()
    return default.data[0]


# ═══════════════════════════════════════════════════════
# Employees (FASE 15)
# ═══════════════════════════════════════════════════════

@router.get("/employees", response_model=list[GymEmployeeOut])
def list_employees(tenant_id: str = Depends(get_current_tenant_id)):
    """Lista empleados activos del gym."""
    res = supabase_admin.table("gym_employees")\
        .select("*")\
        .eq("tenant_id", tenant_id)\
        .eq("is_active", True)\
        .order("first_name")\
        .execute()
    return res.data


@router.post("/employees", response_model=GymEmployeeOut, status_code=status.HTTP_201_CREATED)
def create_employee(body: GymEmployeeCreate, tenant_id: str = Depends(get_current_tenant_id)):
    """Crea un empleado del gym."""
    payload = body.model_dump()
    payload["tenant_id"] = tenant_id
    res = supabase_admin.table("gym_employees").insert(payload).execute()
    if not res.data:
        raise HTTPException(status_code=400, detail="Error al crear empleado.")
    return res.data[0]


@router.patch("/employees/{employee_id}", response_model=GymEmployeeOut)
def update_employee(employee_id: uuid.UUID, body: GymEmployeeUpdate, tenant_id: str = Depends(get_current_tenant_id)):
    """Actualiza un empleado del gym (incluye desactivar)."""
    payload = {k: v for k, v in body.model_dump().items() if v is not None}
    res = supabase_admin.table("gym_employees")\
        .update(payload)\
        .eq("id", str(employee_id))\
        .eq("tenant_id", tenant_id)\
        .execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Empleado no encontrado.")
    return res.data[0]


@router.delete("/employees/{employee_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_employee(employee_id: uuid.UUID, tenant_id: str = Depends(get_current_tenant_id)):
    """Desactiva un empleado del gym (soft delete)."""
    supabase_admin.table("gym_employees")\
        .update({"is_active": False})\
        .eq("id", str(employee_id))\
        .eq("tenant_id", tenant_id)\
        .execute()


@router.patch("/settings", response_model=GymSettingsOut)
def update_settings(body: GymSettingsUpdate, tenant_id: str = Depends(get_current_tenant_id)):
    """Actualiza (upsert) la configuración del gym."""
    updates = {k: v for k, v in body.model_dump().items() if v is not None}
    updates["updated_at"] = datetime.utcnow().isoformat()

    # Check if row exists
    try:
        existing = supabase_admin.table("gym_settings")\
            .select("id")\
            .eq("tenant_id", tenant_id)\
            .execute()
    except postgrest.exceptions.APIError as e:
        if "PGRST205" in str(e):
            raise HTTPException(
                status_code=503,
                detail="El módulo de settings requiere aplicar la migración 006 (tabla gym_settings) en Supabase.",
            )
        raise e

    if existing.data:
        res = supabase_admin.table("gym_settings")\
            .update(updates)\
            .eq("tenant_id", tenant_id)\
            .execute()
    else:
        res = supabase_admin.table("gym_settings")\
            .insert({"tenant_id": tenant_id, **updates})\
            .execute()

    return res.data[0]
