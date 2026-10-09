-- =====================================================================================
-- FASE 6: Catálogo de Módulos y Planes de Suscripción
-- Ejecutar en el SQL Editor de Supabase
-- =====================================================================================

-- 1. Crear tabla de Módulos del Sistema
CREATE TABLE IF NOT EXISTS system_modules (
    slug TEXT PRIMARY KEY, -- 'gym', 'real_estate', 'salon'
    name TEXT NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Habilitar RLS en system_modules
ALTER TABLE system_modules ENABLE ROW LEVEL SECURITY;

-- Políticas para system_modules: todos pueden ver (para el catálogo), solo super-admin edita
CREATE POLICY "Cualquiera puede ver modulos activos" ON system_modules
    FOR SELECT USING (is_active = true OR public.is_super_admin());

CREATE POLICY "Solo super-admin modifica modulos" ON system_modules
    FOR ALL USING (public.is_super_admin());


-- 2. Crear tabla de Planes de Suscripción
CREATE TABLE IF NOT EXISTS subscription_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    module_slug TEXT NOT NULL REFERENCES system_modules(slug) ON DELETE CASCADE,
    name TEXT NOT NULL, -- 'Básico', 'Pro', 'Enterprise'
    base_price DECIMAL(10,2) NOT NULL,
    interval TEXT NOT NULL CHECK (interval IN ('monthly', 'yearly')),
    features JSONB DEFAULT '[]'::jsonb,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Habilitar RLS en subscription_plans
ALTER TABLE subscription_plans ENABLE ROW LEVEL SECURITY;

-- Políticas para subscription_plans
CREATE POLICY "Cualquiera puede ver planes activos" ON subscription_plans
    FOR SELECT USING (is_active = true OR public.is_super_admin());

CREATE POLICY "Solo super-admin modifica planes" ON subscription_plans
    FOR ALL USING (public.is_super_admin());


-- 3. Actualizar la tabla subscriptions existente
-- Agregamos plan_id referenciando a subscription_plans
ALTER TABLE subscriptions 
ADD COLUMN IF NOT EXISTS plan_id UUID REFERENCES subscription_plans(id),
ADD COLUMN IF NOT EXISTS custom_price DECIMAL(10,2); -- Opcional, anula base_price

-- =====================================================================================
-- DATOS SEMILLA (Seed Data)
-- =====================================================================================
INSERT INTO system_modules (slug, name, description)
VALUES 
    ('gym', 'Gimnasio y Fitness', 'Gestión de miembros, check-ins y pagos.'),
    ('real_estate', 'Inmobiliaria', 'Gestión de propiedades y prospectos.'),
    ('salon', 'Salón y Barbería', 'Citas y manejo de empleados.')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO subscription_plans (module_slug, name, base_price, interval)
VALUES 
    ('gym', 'Gym Básico', 29.00, 'monthly'),
    ('gym', 'Gym Pro', 59.00, 'monthly'),
    ('real_estate', 'Real Estate Básico', 49.00, 'monthly'),
    ('salon', 'Salón Básico', 19.00, 'monthly')
ON CONFLICT DO NOTHING;

-- =====================================================================================
-- FIN DEL SCRIPT
-- =====================================================================================
