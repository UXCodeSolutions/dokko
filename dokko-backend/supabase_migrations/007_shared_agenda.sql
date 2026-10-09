-- =====================================================================================
-- FASE 16: Schema de la Agenda Compartida
-- Ejecutar en el SQL Editor de Supabase
-- =====================================================================================

-- 1. Recursos de la agenda (empleados, canchas, etc)
CREATE TABLE IF NOT EXISTS shared_agenda_resources (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    type TEXT NOT NULL, -- ej. 'employee', 'room', 'equipment'
    reference_id UUID,  -- Ref a otra tabla si es necesario
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Horarios regulares de disponibilidad
CREATE TABLE IF NOT EXISTS shared_agenda_availability (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    resource_id UUID NOT NULL REFERENCES shared_agenda_resources(id) ON DELETE CASCADE,
    day_of_week INT NOT NULL CHECK (day_of_week BETWEEN 0 AND 6), -- 0=Domingo, 1=Lunes...
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    UNIQUE(resource_id, day_of_week)
);

-- 3. Excepciones al horario regular (vacaciones, días libres)
CREATE TABLE IF NOT EXISTS shared_agenda_exceptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    resource_id UUID NOT NULL REFERENCES shared_agenda_resources(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    is_working BOOLEAN NOT NULL DEFAULT false,
    start_time TIME,
    end_time TIME,
    notes TEXT,
    UNIQUE(resource_id, date)
);

-- 4. Citas / Reservas
CREATE TABLE IF NOT EXISTS shared_agenda_appointments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    resource_id UUID NOT NULL REFERENCES shared_agenda_resources(id) ON DELETE CASCADE,
    client_name TEXT,
    client_id UUID,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ NOT NULL,
    status TEXT NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'completed', 'cancelled', 'no_show')),
    module_reference TEXT, -- ej 'salon'
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. Función y Trigger para PREVENIR DOBLE-BOOKING
CREATE OR REPLACE FUNCTION prevent_double_booking()
RETURNS TRIGGER AS $$
DECLARE
    conflict_count INT;
BEGIN
    IF NEW.status != 'cancelled' THEN
        SELECT count(*)
        INTO conflict_count
        FROM shared_agenda_appointments
        WHERE resource_id = NEW.resource_id
          AND status != 'cancelled'
          AND id != COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::UUID)
          -- Lógica de superposición: Rango 1 y Rango 2 se superponen si: R1_start < R2_end AND R1_end > R2_start
          AND (NEW.start_time < end_time AND NEW.end_time > start_time);

        IF conflict_count > 0 THEN
            RAISE EXCEPTION 'DOBLE_BOOKING: El recurso ya tiene una cita en ese horario.';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_prevent_double_booking ON shared_agenda_appointments;
CREATE TRIGGER trg_prevent_double_booking
    BEFORE INSERT OR UPDATE ON shared_agenda_appointments
    FOR EACH ROW EXECUTE FUNCTION prevent_double_booking();


-- 6. Row Level Security (RLS)
ALTER TABLE shared_agenda_resources ENABLE ROW LEVEL SECURITY;
ALTER TABLE shared_agenda_availability ENABLE ROW LEVEL SECURITY;
ALTER TABLE shared_agenda_exceptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE shared_agenda_appointments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Agenda resources: aislamiento por tenant" ON shared_agenda_resources FOR ALL USING (tenant_id = public.tenant_id() OR public.is_super_admin());
CREATE POLICY "Agenda availability: aislamiento por tenant" ON shared_agenda_availability FOR ALL USING (tenant_id = public.tenant_id() OR public.is_super_admin());
CREATE POLICY "Agenda exceptions: aislamiento por tenant" ON shared_agenda_exceptions FOR ALL USING (tenant_id = public.tenant_id() OR public.is_super_admin());
CREATE POLICY "Agenda appointments: aislamiento por tenant" ON shared_agenda_appointments FOR ALL USING (tenant_id = public.tenant_id() OR public.is_super_admin());

-- =====================================================================================
-- FIN DEL SCRIPT
-- =====================================================================================
