-- =====================================================================================
-- FASE 8: Schema del Módulo Gym
-- Ejecutar en el SQL Editor de Supabase
-- =====================================================================================

-- Membresías/Planes del Gym (catálogo definido por el tenant)
CREATE TABLE IF NOT EXISTS gym_membership_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name TEXT NOT NULL,           -- Ej: "Mensual", "Trimestral", "Anual"
    price DECIMAL(10,2) NOT NULL,
    duration_days INT NOT NULL,   -- 30, 90, 365
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Miembros del Gym
CREATE TABLE IF NOT EXISTS gym_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    email TEXT,
    phone TEXT,
    id_number TEXT,               -- Cédula / Pasaporte
    photo_url TEXT,
    notes TEXT,
    -- Estado calculado, actualizado por triggers/backend
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'expired', 'suspended', 'cancelled')),
    membership_expires_at DATE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Pagos de Membresía (historial)
CREATE TABLE IF NOT EXISTS gym_membership_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    member_id UUID NOT NULL REFERENCES gym_members(id) ON DELETE CASCADE,
    plan_id UUID REFERENCES gym_membership_plans(id),
    amount DECIMAL(10,2) NOT NULL,
    payment_method TEXT DEFAULT 'cash' CHECK (payment_method IN ('cash', 'card', 'transfer', 'other')),
    paid_at TIMESTAMPTZ DEFAULT NOW(),
    valid_from DATE NOT NULL,
    valid_until DATE NOT NULL,
    notes TEXT,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Check-ins de Miembros
CREATE TABLE IF NOT EXISTS gym_checkins (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    member_id UUID NOT NULL REFERENCES gym_members(id) ON DELETE CASCADE,
    checked_in_at TIMESTAMPTZ DEFAULT NOW(),
    notes TEXT
);

-- Catálogo de Productos (bar, suplementos, etc.)
CREATE TABLE IF NOT EXISTS gym_products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    sku TEXT,
    category TEXT DEFAULT 'general',
    price DECIMAL(10,2) NOT NULL DEFAULT 0,
    stock_quantity INT NOT NULL DEFAULT 0,
    stock_alert_threshold INT DEFAULT 5,   -- Avisar cuando stock baje de aquí
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Ventas (transacciones de caja)
CREATE TABLE IF NOT EXISTS gym_sales (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    member_id UUID REFERENCES gym_members(id),  -- Puede ser venta a no-miembro
    total DECIMAL(10,2) NOT NULL,
    payment_method TEXT DEFAULT 'cash' CHECK (payment_method IN ('cash', 'card', 'transfer', 'other')),
    sold_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES auth.users(id),
    notes TEXT
);

-- Ítems de cada venta
CREATE TABLE IF NOT EXISTS gym_sale_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sale_id UUID NOT NULL REFERENCES gym_sales(id) ON DELETE CASCADE,
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES gym_products(id),
    quantity INT NOT NULL DEFAULT 1,
    unit_price DECIMAL(10,2) NOT NULL,
    subtotal DECIMAL(10,2) NOT NULL
);

-- Movimientos de Stock (entrada/salida de inventario)
CREATE TABLE IF NOT EXISTS gym_stock_movements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES gym_products(id) ON DELETE CASCADE,
    quantity_change INT NOT NULL,  -- Positivo = entrada, Negativo = salida
    reason TEXT NOT NULL CHECK (reason IN ('purchase', 'sale', 'adjustment', 'return', 'loss')),
    reference_id UUID,             -- ID de gym_sales o gym_membership_payments si aplica
    notes TEXT,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================================================
-- TRIGGER: Actualizar stock al crear un sale_item
-- =====================================================================================
CREATE OR REPLACE FUNCTION update_product_stock_on_sale()
RETURNS TRIGGER AS $$
BEGIN
    -- Reducir stock
    UPDATE gym_products
    SET stock_quantity = stock_quantity - NEW.quantity,
        updated_at = NOW()
    WHERE id = NEW.product_id;

    -- Registrar en stock_movements
    INSERT INTO gym_stock_movements (tenant_id, product_id, quantity_change, reason, reference_id)
    VALUES (NEW.tenant_id, NEW.product_id, -NEW.quantity, 'sale', NEW.sale_id);

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_stock_on_sale ON gym_sale_items;
CREATE TRIGGER trg_update_stock_on_sale
    AFTER INSERT ON gym_sale_items
    FOR EACH ROW EXECUTE FUNCTION update_product_stock_on_sale();

-- =====================================================================================
-- TRIGGER: Actualizar membership_expires_at al registrar pago
-- =====================================================================================
CREATE OR REPLACE FUNCTION update_member_expiry_on_payment()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE gym_members
    SET membership_expires_at = NEW.valid_until,
        status = 'active',
        updated_at = NOW()
    WHERE id = NEW.member_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_member_expiry ON gym_membership_payments;
CREATE TRIGGER trg_update_member_expiry
    AFTER INSERT ON gym_membership_payments
    FOR EACH ROW EXECUTE FUNCTION update_member_expiry_on_payment();

-- =====================================================================================
-- RLS: Aislamiento estricto de todos los datos del módulo Gym
-- =====================================================================================
ALTER TABLE gym_membership_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE gym_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE gym_membership_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE gym_checkins ENABLE ROW LEVEL SECURITY;
ALTER TABLE gym_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE gym_sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE gym_sale_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE gym_stock_movements ENABLE ROW LEVEL SECURITY;

-- Macro para todos: aislamiento por tenant_id O super-admin puede ver todo
CREATE POLICY "Gym: aislamiento por tenant" ON gym_membership_plans FOR ALL USING (tenant_id = public.tenant_id() OR public.is_super_admin());
CREATE POLICY "Gym: aislamiento por tenant" ON gym_members FOR ALL USING (tenant_id = public.tenant_id() OR public.is_super_admin());
CREATE POLICY "Gym: aislamiento por tenant" ON gym_membership_payments FOR ALL USING (tenant_id = public.tenant_id() OR public.is_super_admin());
CREATE POLICY "Gym: aislamiento por tenant" ON gym_checkins FOR ALL USING (tenant_id = public.tenant_id() OR public.is_super_admin());
CREATE POLICY "Gym: aislamiento por tenant" ON gym_products FOR ALL USING (tenant_id = public.tenant_id() OR public.is_super_admin());
CREATE POLICY "Gym: aislamiento por tenant" ON gym_sales FOR ALL USING (tenant_id = public.tenant_id() OR public.is_super_admin());
CREATE POLICY "Gym: aislamiento por tenant" ON gym_sale_items FOR ALL USING (tenant_id = public.tenant_id() OR public.is_super_admin());
CREATE POLICY "Gym: aislamiento por tenant" ON gym_stock_movements FOR ALL USING (tenant_id = public.tenant_id() OR public.is_super_admin());

-- =====================================================================================
-- FIN DEL SCRIPT
-- =====================================================================================
