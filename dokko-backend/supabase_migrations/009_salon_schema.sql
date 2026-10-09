-- =====================================================================================
-- FASE 21: Schema del Módulo Salón/Barbería
-- Ejecutar en el SQL Editor de Supabase DESPUÉS de 007_shared_agenda.sql
-- =====================================================================================

-- 1. Catálogo de Servicios del Salón
CREATE TABLE IF NOT EXISTS salon_services (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name            TEXT NOT NULL,
    description     TEXT,
    category        TEXT NOT NULL DEFAULT 'general',  -- 'hair', 'beard', 'color', 'treatment', 'nails', 'general'
    duration_minutes INT NOT NULL DEFAULT 30,
    price           NUMERIC(10,2) NOT NULL DEFAULT 0,
    is_active       BOOLEAN NOT NULL DEFAULT true,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Empleados del Salón (extiende shared_agenda_resources)
CREATE TABLE IF NOT EXISTS salon_employees (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    resource_id     UUID REFERENCES shared_agenda_resources(id) ON DELETE SET NULL,
    first_name      TEXT NOT NULL,
    last_name       TEXT NOT NULL,
    phone           TEXT,
    email           TEXT,
    specialties     TEXT[] DEFAULT '{}',             -- ej: ['corte', 'tintura', 'barba']
    commission_rate NUMERIC(5,2) DEFAULT 0.00,       -- porcentaje base de comisión
    color           TEXT DEFAULT '#3ECF8E',           -- color de columna en agenda
    is_active       BOOLEAN NOT NULL DEFAULT true,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Clientes del Salón (CRM)
CREATE TABLE IF NOT EXISTS salon_clients (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    first_name      TEXT NOT NULL,
    last_name       TEXT NOT NULL,
    phone           TEXT,
    email           TEXT,
    birthdate       DATE,
    notes           TEXT,
    preferences     JSONB DEFAULT '{}',              -- {hair_color, style, allergies, notes_free}
    last_visit_date DATE,
    total_visits    INT NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Servicios por Cita (JOIN: shared_agenda_appointments ↔ salon_services)
CREATE TABLE IF NOT EXISTS salon_appointment_services (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    appointment_id  UUID NOT NULL REFERENCES shared_agenda_appointments(id) ON DELETE CASCADE,
    service_id      UUID NOT NULL REFERENCES salon_services(id) ON DELETE RESTRICT,
    price_at_time   NUMERIC(10,2) NOT NULL,          -- precio en el momento de la cita
    UNIQUE(appointment_id, service_id)
);

-- 5. Trigger: actualizar last_visit_date y total_visits en el cliente al completar cita
CREATE OR REPLACE FUNCTION update_salon_client_visit()
RETURNS TRIGGER AS $$
BEGIN
    -- Solo cuando la cita cambia a 'completed' y tiene client_id
    IF NEW.status = 'completed' AND NEW.client_id IS NOT NULL AND OLD.status != 'completed' THEN
        UPDATE salon_clients
        SET last_visit_date = NOW()::DATE,
            total_visits = total_visits + 1,
            updated_at = NOW()
        WHERE id = NEW.client_id
          AND tenant_id = NEW.tenant_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_salon_client_visit ON shared_agenda_appointments;
CREATE TRIGGER trg_salon_client_visit
    AFTER UPDATE ON shared_agenda_appointments
    FOR EACH ROW EXECUTE FUNCTION update_salon_client_visit();

-- 6. Row Level Security (RLS)
ALTER TABLE salon_services ENABLE ROW LEVEL SECURITY;
ALTER TABLE salon_employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE salon_clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE salon_appointment_services ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Salon services: aislamiento por tenant"
    ON salon_services FOR ALL
    USING (tenant_id = public.tenant_id() OR public.is_super_admin());

CREATE POLICY "Salon employees: aislamiento por tenant"
    ON salon_employees FOR ALL
    USING (tenant_id = public.tenant_id() OR public.is_super_admin());

CREATE POLICY "Salon clients: aislamiento por tenant"
    ON salon_clients FOR ALL
    USING (tenant_id = public.tenant_id() OR public.is_super_admin());

CREATE POLICY "Salon appointment_services: aislamiento por tenant"
    ON salon_appointment_services FOR ALL
    USING (tenant_id = public.tenant_id() OR public.is_super_admin());

-- =====================================================================================
-- FIN DEL SCRIPT — Recuerda ejecutar en Supabase SQL Editor
-- =====================================================================================
