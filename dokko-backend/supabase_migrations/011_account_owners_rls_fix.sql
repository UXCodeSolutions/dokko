-- =====================================================================================
-- FIX: Políticas faltantes en account_owners para super-admin
-- =====================================================================================

-- Permitir que el super-admin inserte en account_owners (necesario para crear tenants)
CREATE POLICY "Super-admin puede insertar account_owners" ON account_owners
  FOR INSERT WITH CHECK (public.is_super_admin() OR auth.uid() = user_id);

-- Permitir que el super-admin vea todos los account_owners
CREATE POLICY "Super-admin puede ver todos los account_owners" ON account_owners
  FOR SELECT USING (public.is_super_admin() OR auth.uid() = user_id);

-- Permitir que el super-admin modifique account_owners
CREATE POLICY "Super-admin puede modificar account_owners" ON account_owners
  FOR UPDATE USING (public.is_super_admin() OR auth.uid() = user_id);
