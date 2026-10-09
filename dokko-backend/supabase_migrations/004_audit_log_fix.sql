-- =====================================================================================
-- FASE 7: Fix explícito para inserciones en audit_log por parte del super-admin
-- =====================================================================================

DROP POLICY IF EXISTS "Aislamiento estricto de audit log" ON audit_log;

CREATE POLICY "Super-admin puede ver todo el audit log" ON audit_log
  FOR SELECT USING (public.is_super_admin() OR tenant_id = public.tenant_id());

CREATE POLICY "Super-admin puede insertar en audit log" ON audit_log
  FOR INSERT WITH CHECK (public.is_super_admin() OR tenant_id = public.tenant_id());

CREATE POLICY "Nadie puede modificar el audit log" ON audit_log
  FOR UPDATE USING (false);

CREATE POLICY "Nadie puede eliminar el audit log" ON audit_log
  FOR DELETE USING (false);

-- =====================================================================================
-- FIN DEL SCRIPT
-- =====================================================================================
