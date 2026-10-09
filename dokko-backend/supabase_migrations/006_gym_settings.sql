-- =====================================================================================
-- FASE 15: Tabla de Configuración del Módulo Gym
-- Ejecutar en el SQL Editor de Supabase
-- =====================================================================================

CREATE TABLE IF NOT EXISTS gym_settings (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id   UUID NOT NULL UNIQUE REFERENCES tenants(id) ON DELETE CASCADE,
    gym_name    TEXT,
    address     TEXT,
    phone       TEXT,
    email       TEXT,
    website     TEXT,
    capacity    INT DEFAULT 0,              -- Capacidad máxima por sesión (0 = sin límite)
    currency    TEXT DEFAULT 'USD',
    timezone    TEXT DEFAULT 'America/New_York',
    -- Horario semanal (JSON): { "mon": {"open": "06:00", "close": "22:00", "closed": false}, ... }
    hours       JSONB DEFAULT '{}'::JSONB,
    updated_at  TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE gym_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Gym settings: aislamiento por tenant"
    ON gym_settings FOR ALL
    USING (tenant_id = public.tenant_id() OR public.is_super_admin());
