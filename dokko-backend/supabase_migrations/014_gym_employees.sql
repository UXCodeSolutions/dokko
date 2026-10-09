-- =====================================================================================
-- FASE 15: Empleados del Gym (configuración editable y persistente)
-- Ejecutar en el SQL Editor de Supabase
-- =====================================================================================

CREATE TABLE IF NOT EXISTS gym_employees (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id   UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    first_name  TEXT NOT NULL,
    last_name   TEXT NOT NULL,
    role        TEXT NOT NULL DEFAULT 'entrenador',  -- 'entrenador' | 'recepcion' | 'staff'
    phone       TEXT,
    email       TEXT,
    is_active   BOOLEAN NOT NULL DEFAULT true,
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    updated_at  TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE gym_employees ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Gym employees: aislamiento por tenant"
    ON gym_employees FOR ALL
    USING (tenant_id = public.tenant_id() OR public.is_super_admin());