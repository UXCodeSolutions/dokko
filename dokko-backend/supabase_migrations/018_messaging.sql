-- =====================================================================================
-- FASE PILOTO 28: Sistema de Mensajería multi-módulo (piloto salón)
-- Bandeja de mensajes por lotes + deep-links a WhatsApp (wa.me) sin API.
-- Transversal: preparado para gym / realestate.
-- Ejecutar en el SQL Editor de Supabase DESPUÉS de 017_legal_consent.sql
-- =====================================================================================

-- Tabla de settings de mensajería por (tenant, módulo).
CREATE TABLE IF NOT EXISTS messaging_settings (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id   UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    module      TEXT NOT NULL CHECK (module IN ('salon', 'gym', 'realestate')),
    data        JSONB NOT NULL DEFAULT '{}',
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    updated_at  TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tenant_id, module)
);

-- Plantillas de mensaje por (tenant, módulo, key). Si no existe fila, el backend
-- usa la plantilla por defecto.
CREATE TABLE IF NOT EXISTS messaging_templates (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id   UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    module      TEXT NOT NULL CHECK (module IN ('salon', 'gym', 'realestate')),
    key         TEXT NOT NULL,
    label       TEXT NOT NULL DEFAULT '',
    body        TEXT NOT NULL,
    is_active   BOOLEAN NOT NULL DEFAULT true,
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    updated_at  TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tenant_id, module, key)
);

-- Lotes de mensajes: la unidad que el personal confirma/cancela de una vez.
CREATE TABLE IF NOT EXISTS message_batches (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id     UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    module        TEXT NOT NULL CHECK (module IN ('salon', 'gym', 'realestate')),
    status        TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'cancelled')),
    created_at    TIMESTAMPTZ DEFAULT NOW(),
    confirmed_at  TIMESTAMPTZ
);

-- Mensajes salientes. `status` avanza: ready → pending (lote) → sent/cancelled.
-- `batch_id` se asigna al materializar el lote. `phone` son dígitos E.164 (sin '+').
CREATE TABLE IF NOT EXISTS outbound_messages (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    module          TEXT NOT NULL CHECK (module IN ('salon', 'gym', 'realestate')),
    batch_id        UUID REFERENCES message_batches(id) ON DELETE SET NULL,
    template_key    TEXT,
    recipient_name  TEXT NOT NULL,
    phone           TEXT NOT NULL,
    body            TEXT NOT NULL,
    status          TEXT NOT NULL DEFAULT 'ready' CHECK (status IN ('ready', 'pending', 'sent', 'cancelled', 'failed')),
    source          TEXT NOT NULL DEFAULT 'manual' CHECK (source IN ('manual', 'reminder', 'waitlist', 'feedback', 'billing')),
    reference_id    UUID,
    scheduled_for   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    sent_at         TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Lista de espera del salón (aviso de cupo liberado).
CREATE TABLE IF NOT EXISTS salon_waitlist (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id     UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    client_id     UUID REFERENCES salon_clients(id) ON DELETE SET NULL,
    client_name   TEXT NOT NULL,
    phone         TEXT,
    service_name  TEXT,
    notes         TEXT,
    status        TEXT NOT NULL DEFAULT 'waiting' CHECK (status IN ('waiting', 'notified', 'served', 'removed')),
    created_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_outbound_messages_ready
    ON outbound_messages (tenant_id, module, status, scheduled_for);
CREATE INDEX IF NOT EXISTS idx_outbound_messages_batch
    ON outbound_messages (batch_id);
CREATE INDEX IF NOT EXISTS idx_message_batches_tenant
    ON message_batches (tenant_id, module, status);
CREATE INDEX IF NOT EXISTS idx_salon_waitlist_waiting
    ON salon_waitlist (tenant_id, status, created_at);

-- =====================================================================================
-- Row Level Security: aislamiento por tenant (mismo patrón que el resto del proyecto).
-- =====================================================================================
ALTER TABLE messaging_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE messaging_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE message_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE outbound_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE salon_waitlist ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Messaging settings: aislamiento por tenant" ON messaging_settings
    FOR ALL USING (tenant_id = public.tenant_id() OR public.is_super_admin());
CREATE POLICY "Messaging templates: aislamiento por tenant" ON messaging_templates
    FOR ALL USING (tenant_id = public.tenant_id() OR public.is_super_admin());
CREATE POLICY "Message batches: aislamiento por tenant" ON message_batches
    FOR ALL USING (tenant_id = public.tenant_id() OR public.is_super_admin());
CREATE POLICY "Outbound messages: aislamiento por tenant" ON outbound_messages
    FOR ALL USING (tenant_id = public.tenant_id() OR public.is_super_admin());
CREATE POLICY "Salon waitlist: aislamiento por tenant" ON salon_waitlist
    FOR ALL USING (tenant_id = public.tenant_id() OR public.is_super_admin());

-- =====================================================================================
-- FIN DEL SCRIPT — Recuerda ejecutar en Supabase SQL Editor
-- =====================================================================================