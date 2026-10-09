-- =====================================================================================
-- FASE 5 FIX: Ajustes para flujo Super-Admin
-- Ejecutar en el SQL Editor de Supabase DESPUÉS de 001_core_schema.sql
-- =====================================================================================

-- 1. Hacer owner_id nullable en tenants para poder crear tenants sin account_owner previo
ALTER TABLE tenants ALTER COLUMN owner_id DROP NOT NULL;

-- 2. Política RLS: Super-admin puede INSERTAR tenants sin restricción de tenant_id
-- (ya cubierto por public.is_super_admin() pero agregamos INSERT explícito)
CREATE POLICY "Super-admin puede ver todos los tenants" ON tenants
  FOR SELECT USING (public.is_super_admin());

CREATE POLICY "Super-admin puede insertar tenants" ON tenants
  FOR INSERT WITH CHECK (public.is_super_admin());

CREATE POLICY "Super-admin puede modificar tenants" ON tenants
  FOR UPDATE USING (public.is_super_admin());

CREATE POLICY "Super-admin puede eliminar tenants" ON tenants
  FOR DELETE USING (public.is_super_admin());

-- 3. Super-admin puede ver todos los account_owners
CREATE POLICY "Super-admin puede ver account owners" ON account_owners
  FOR ALL USING (public.is_super_admin());

-- 4. Super-admin puede ver y gestionar todos los tenant_users
CREATE POLICY "Super-admin gestiona tenant users" ON tenant_users
  FOR ALL USING (public.is_super_admin());

-- 5. Instrucción para marcar un usuario como super-admin
-- (reemplazar el email con el tuyo antes de ejecutar)
-- UPDATE auth.users
-- SET raw_app_meta_data = raw_app_meta_data || '{"is_super_admin": true}'::jsonb
-- WHERE email = 'tu-email@ejemplo.com';

-- =====================================================================================
-- FIN DEL SCRIPT
-- =====================================================================================
