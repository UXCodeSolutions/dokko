-- =====================================================================================
-- FASE 1: Esquema Core en Supabase
-- Aislamiento de tenants absoluto usando Row Level Security (RLS)
-- =====================================================================================

-- 1. Extensiones necesarias
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. Funciones de Seguridad Global (usadas en las políticas RLS)
CREATE OR REPLACE FUNCTION public.tenant_id() RETURNS uuid AS $$
  SELECT (NULLIF(current_setting('request.jwt.claim.app_metadata', true)::jsonb->>'tenant_id', ''))::uuid;
$$ LANGUAGE sql STABLE;

CREATE OR REPLACE FUNCTION public.is_super_admin() RETURNS boolean AS $$
  SELECT (current_setting('request.jwt.claim.app_metadata', true)::jsonb->>'is_super_admin')::boolean = true;
$$ LANGUAGE sql STABLE;


-- 3. Tablas Base
CREATE TABLE account_owners (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc', now())
);

CREATE TABLE tenants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    owner_id UUID NOT NULL REFERENCES account_owners(id) ON DELETE RESTRICT,
    name TEXT NOT NULL,
    module_slug TEXT NOT NULL, -- ej. 'gym', 'real_estate'
    brand_config JSONB DEFAULT '{}'::jsonb,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'cancelled')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc', now())
);

CREATE TABLE tenant_users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK (role IN ('admin', 'staff')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc', now()),
    UNIQUE (tenant_id, user_id)
);

CREATE TABLE subscriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    plan_id TEXT NOT NULL,
    status TEXT NOT NULL,
    current_period_end TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc', now())
);

CREATE TABLE payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    amount NUMERIC(10, 2) NOT NULL,
    status TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc', now())
);

CREATE TABLE audit_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    action TEXT NOT NULL,
    entity TEXT NOT NULL,
    details JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc', now())
);


-- 4. Habilitar RLS (Row Level Security) en todas las tablas
ALTER TABLE account_owners ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenant_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;


-- 5. Políticas de Aislamiento (RLS Policies)

-- A) account_owners
-- Solo el dueño de la cuenta o el super_admin puede ver/editar su registro.
CREATE POLICY "Dueño de cuenta puede ver su registro" ON account_owners
  FOR SELECT USING (auth.uid() = user_id OR public.is_super_admin());

CREATE POLICY "Dueño de cuenta puede editar su registro" ON account_owners
  FOR UPDATE USING (auth.uid() = user_id);

-- B) tenants
-- Los tenant_users solo pueden ver los datos de su tenant. Super admin lo ve todo.
CREATE POLICY "Usuarios del tenant pueden ver su tenant" ON tenants
  FOR SELECT USING (id = public.tenant_id() OR public.is_super_admin());

CREATE POLICY "Solo super_admin puede crear tenants" ON tenants
  FOR INSERT WITH CHECK (public.is_super_admin());

CREATE POLICY "Admin del tenant puede actualizar brand_config" ON tenants
  FOR UPDATE USING (id = public.tenant_id() AND EXISTS (
      SELECT 1 FROM tenant_users WHERE tenant_users.user_id = auth.uid() AND role = 'admin'
  ));

-- C) tenant_users
-- Usuarios solo pueden ver los usuarios que comparten su mismo tenant.
CREATE POLICY "Usuarios ven miembros de su tenant" ON tenant_users
  FOR SELECT USING (tenant_id = public.tenant_id() OR public.is_super_admin());

-- D) subscriptions, payments, audit_log
-- Las tres siguen la regla estricta: solo acceder donde tenant_id = public.tenant_id()
CREATE POLICY "Aislamiento estricto de suscripciones" ON subscriptions
  FOR ALL USING (tenant_id = public.tenant_id() OR public.is_super_admin());

CREATE POLICY "Aislamiento estricto de pagos" ON payments
  FOR ALL USING (tenant_id = public.tenant_id() OR public.is_super_admin());

CREATE POLICY "Aislamiento estricto de audit log" ON audit_log
  FOR ALL USING (tenant_id = public.tenant_id() OR public.is_super_admin());

-- =====================================================================================
-- FIN DEL SCRIPT
-- =====================================================================================
