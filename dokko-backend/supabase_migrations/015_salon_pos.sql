-- =====================================================================================
-- FASE 22: POS del Módulo Salón/Barbería (catálogo, ventas, comisiones)
-- Ejecutar en el SQL Editor de Supabase DESPUÉS de 009_salon_schema.sql
-- =====================================================================================

-- 1. Catálogo de Productos del Salón (venta en el mostrador)
CREATE TABLE IF NOT EXISTS salon_products (
    id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id            UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name                 TEXT NOT NULL,
    sku                  TEXT,
    category             TEXT NOT NULL DEFAULT 'general',  -- 'hair', 'beard', 'color', 'treatment', 'nails', 'retail', 'general'
    price                NUMERIC(10,2) NOT NULL DEFAULT 0,
    stock_quantity       INT NOT NULL DEFAULT 0,
    stock_alert_threshold INT DEFAULT 5,
    image_url            TEXT,
    is_active            BOOLEAN NOT NULL DEFAULT true,
    created_at           TIMESTAMPTZ DEFAULT NOW(),
    updated_at           TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Ventas del Salón (POS)
CREATE TABLE IF NOT EXISTS salon_sales (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id          UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    client_id          UUID REFERENCES salon_clients(id) ON DELETE SET NULL,
    employee_id        UUID REFERENCES salon_employees(id) ON DELETE SET NULL,  -- responsable/estilista
    total              NUMERIC(10,2) NOT NULL DEFAULT 0,
    commission_amount  NUMERIC(10,2) NOT NULL DEFAULT 0,   -- comisión calculada al vender
    payment_method     TEXT DEFAULT 'cash' CHECK (payment_method IN ('cash', 'card', 'transfer', 'other')),
    sold_at            TIMESTAMPTZ DEFAULT NOW(),
    created_by         UUID REFERENCES auth.users(id),
    notes              TEXT
);

-- 3. Ítems de cada venta
CREATE TABLE IF NOT EXISTS salon_sale_items (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sale_id    UUID NOT NULL REFERENCES salon_sales(id) ON DELETE CASCADE,
    tenant_id  UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES salon_products(id),
    quantity   INT NOT NULL DEFAULT 1,
    unit_price NUMERIC(10,2) NOT NULL,
    subtotal   NUMERIC(10,2) NOT NULL
);

-- 4. Comisiones por venta (se genera al crear la venta si tiene empleado asignado)
CREATE TABLE IF NOT EXISTS salon_commissions (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id   UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    sale_id     UUID NOT NULL REFERENCES salon_sales(id) ON DELETE CASCADE,
    employee_id UUID NOT NULL REFERENCES salon_employees(id) ON DELETE CASCADE,
    amount      NUMERIC(10,2) NOT NULL DEFAULT 0,
    rate        NUMERIC(5,2) NOT NULL DEFAULT 0,   -- % aplicado en el momento
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================================================
-- TRIGGER: Actualizar stock del producto al crear un sale_item
-- =====================================================================================
CREATE OR REPLACE FUNCTION update_salon_product_stock_on_sale()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE salon_products
    SET stock_quantity = stock_quantity - NEW.quantity,
        updated_at = NOW()
    WHERE id = NEW.product_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_salon_stock_on_sale ON salon_sale_items;
CREATE TRIGGER trg_update_salon_stock_on_sale
    AFTER INSERT ON salon_sale_items
    FOR EACH ROW EXECUTE FUNCTION update_salon_product_stock_on_sale();

-- =====================================================================================
-- RLS: Aislamiento estricto de todos los datos del POS del Salón
-- =====================================================================================
ALTER TABLE salon_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE salon_sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE salon_sale_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE salon_commissions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Salon POS products: aislamiento por tenant"
    ON salon_products FOR ALL
    USING (tenant_id = public.tenant_id() OR public.is_super_admin());

CREATE POLICY "Salon POS sales: aislamiento por tenant"
    ON salon_sales FOR ALL
    USING (tenant_id = public.tenant_id() OR public.is_super_admin());

CREATE POLICY "Salon POS sale_items: aislamiento por tenant"
    ON salon_sale_items FOR ALL
    USING (tenant_id = public.tenant_id() OR public.is_super_admin());

CREATE POLICY "Salon POS commissions: aislamiento por tenant"
    ON salon_commissions FOR ALL
    USING (tenant_id = public.tenant_id() OR public.is_super_admin());

-- =====================================================================================
-- FIN DEL SCRIPT — Recuerda ejecutar en Supabase SQL Editor
-- =====================================================================================