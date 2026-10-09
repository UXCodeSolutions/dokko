-- =====================================================================================
-- FIX CRÍTICO: las funciones tenant_id() e is_super_admin() leían un nombre de
-- variable de PostgREST que no existe (request.jwt.claim.app_metadata).
-- El nombre correcto es la función helper auth.jwt(), provista por Supabase.
-- =====================================================================================

CREATE OR REPLACE FUNCTION public.tenant_id() RETURNS uuid AS $$
  SELECT NULLIF(
    (auth.jwt() -> 'app_metadata' ->> 'tenant_id'),
    ''
  )::uuid;
$$ LANGUAGE sql STABLE;

CREATE OR REPLACE FUNCTION public.is_super_admin() RETURNS boolean AS $$
  SELECT COALESCE(
    (auth.jwt() -> 'app_metadata' ->> 'is_super_admin')::boolean,
    false
  );
$$ LANGUAGE sql STABLE;
