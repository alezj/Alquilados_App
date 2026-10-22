-- Keep RLS helper functions outside the exposed public schema and enforce the
-- existing CRM permission catalog at the row level.
CREATE SCHEMA IF NOT EXISTS private;

ALTER FUNCTION public.is_platform_admin() SET SCHEMA private;
ALTER FUNCTION public.has_company_access(uuid, boolean) SET SCHEMA private;

CREATE OR REPLACE FUNCTION private.is_platform_admin()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$ SELECT EXISTS (
  SELECT 1 FROM public.global_user_roles
  WHERE user_id = auth.uid() AND role = 'sysAdmin'
); $$;

CREATE OR REPLACE FUNCTION private.has_company_access(target_company uuid, require_admin boolean DEFAULT false)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$ SELECT private.is_platform_admin() OR EXISTS (
  SELECT 1
  FROM public.company_memberships m
  JOIN public.companies c ON c.id = m.company_id
  JOIN public.profiles p ON p.id = m.user_id
  WHERE m.user_id = auth.uid()
    AND m.company_id = target_company
    AND m.status = 'approved'
    AND p.approval_status = 'approved'
    AND p.is_active IS TRUE
    AND c.status = 'active'
    AND (NOT require_admin OR m.role = 'admin_empresa')
); $$;

CREATE OR REPLACE FUNCTION private.has_business_permission(target_company uuid, module_name text, action_name text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$ SELECT private.is_platform_admin() OR EXISTS (
  SELECT 1
  FROM public.company_memberships m
  JOIN public.companies c ON c.id = m.company_id
  JOIN public.profiles p ON p.id = m.user_id
  JOIN public.role_permissions rp ON rp.role_id = p.role_id
  WHERE m.user_id = auth.uid()
    AND m.company_id = target_company
    AND m.status = 'approved'
    AND p.approval_status = 'approved'
    AND p.is_active IS TRUE
    AND c.status = 'active'
    AND (
      m.role = 'admin_empresa'
      OR rp.permission_id = module_name || ':' || action_name
      OR rp.permission_id = module_name || ':manage'
    )
); $$;

CREATE OR REPLACE FUNCTION public.is_platform_admin()
RETURNS boolean LANGUAGE sql STABLE SECURITY INVOKER
SET search_path = pg_catalog, public, auth
AS $$ SELECT EXISTS (
  SELECT 1 FROM public.global_user_roles
  WHERE user_id = auth.uid() AND role = 'sysAdmin'
); $$;

CREATE OR REPLACE FUNCTION public.set_business_company_id()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE selected_company uuid;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Se requiere una sesión autenticada'; END IF;
  IF TG_OP = 'UPDATE' THEN
    selected_company := OLD.company_id;
  ELSIF NEW.company_id IS NOT NULL AND private.has_company_access(NEW.company_id, false) THEN
    selected_company := NEW.company_id;
  ELSIF private.is_platform_admin() THEN
    RAISE EXCEPTION 'Debes indicar una empresa válida para el registro';
  ELSE
    SELECT m.company_id INTO selected_company
    FROM public.company_memberships m
    JOIN public.companies c ON c.id = m.company_id
    WHERE m.user_id = auth.uid() AND m.status = 'approved' AND c.status = 'active'
    ORDER BY m.requested_at LIMIT 1;
  END IF;
  IF selected_company IS NULL OR NOT private.has_company_access(selected_company, false) THEN
    RAISE EXCEPTION 'El usuario no tiene una empresa activa autorizada';
  END IF;
  IF TG_OP = 'UPDATE' AND NEW.company_id IS DISTINCT FROM OLD.company_id THEN
    RAISE EXCEPTION 'No se permite cambiar la empresa de un registro';
  END IF;
  NEW.company_id := selected_company;
  RETURN NEW;
END; $$;

CREATE OR REPLACE FUNCTION public.prevent_profile_privilege_escalation()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$ BEGIN
  IF auth.uid() = OLD.id AND NOT private.is_platform_admin() AND (
    NEW.role_id IS DISTINCT FROM OLD.role_id OR NEW.is_active IS DISTINCT FROM OLD.is_active OR
    NEW.approval_status IS DISTINCT FROM OLD.approval_status OR NEW.approved_by IS DISTINCT FROM OLD.approved_by OR
    NEW.approved_at IS DISTINCT FROM OLD.approved_at
  ) THEN RAISE EXCEPTION 'No puedes modificar tus privilegios o estado de aprobación'; END IF;
  RETURN NEW;
END; $$;

CREATE OR REPLACE FUNCTION public.review_company_membership(membership_id uuid, approve boolean, assigned_role text DEFAULT 'usuario')
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE target public.company_memberships%ROWTYPE;
BEGIN
  SELECT * INTO target FROM public.company_memberships WHERE id = membership_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Solicitud no encontrada'; END IF;
  IF NOT private.is_platform_admin() AND NOT private.has_company_access(target.company_id, true) THEN
    RAISE EXCEPTION 'No autorizado para administrar esta empresa';
  END IF;
  IF assigned_role NOT IN ('usuario','admin_empresa') OR (assigned_role='admin_empresa' AND NOT private.is_platform_admin()) THEN
    RAISE EXCEPTION 'Rol no permitido';
  END IF;
  UPDATE public.company_memberships
  SET role = CASE WHEN approve THEN assigned_role ELSE role END,
      status = CASE WHEN approve THEN 'approved' ELSE 'rejected' END,
      approved_by = auth.uid(), approved_at = CASE WHEN approve THEN now() ELSE NULL END
  WHERE id = membership_id;
  UPDATE public.profiles SET is_active = approve,
    approval_status = CASE WHEN approve THEN 'approved' ELSE 'rejected' END,
    approved_by = auth.uid(), approved_at = CASE WHEN approve THEN now() ELSE NULL END
  WHERE id = target.user_id;
END; $$;

REVOKE ALL ON FUNCTION private.is_platform_admin() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION private.has_company_access(uuid, boolean) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION private.has_business_permission(uuid, text, text) FROM PUBLIC, anon;
GRANT USAGE ON SCHEMA private TO authenticated;
GRANT EXECUTE ON FUNCTION private.is_platform_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION private.has_company_access(uuid, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION private.has_business_permission(uuid, text, text) TO authenticated;
REVOKE ALL ON FUNCTION public.is_platform_admin() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_platform_admin() TO authenticated;
REVOKE ALL ON FUNCTION public.set_business_company_id() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.prevent_profile_privilege_escalation() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.review_company_membership(uuid, boolean, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.review_company_membership(uuid, boolean, text) TO authenticated;

DROP POLICY IF EXISTS companies_read_member ON public.companies;
DROP POLICY IF EXISTS companies_admin_manage ON public.companies;
CREATE POLICY companies_read_member ON public.companies FOR SELECT TO authenticated
USING (status='active' AND (private.is_platform_admin() OR private.has_company_access(id, false)));
CREATE POLICY companies_admin_manage ON public.companies FOR ALL TO authenticated
USING (private.is_platform_admin()) WITH CHECK (private.is_platform_admin());

DROP POLICY IF EXISTS memberships_read_self_or_admin ON public.company_memberships;
DROP POLICY IF EXISTS memberships_admin_manage ON public.company_memberships;
CREATE POLICY memberships_read_self_or_admin ON public.company_memberships FOR SELECT TO authenticated
USING (user_id=auth.uid() OR private.is_platform_admin() OR private.has_company_access(company_id, true));


DO $$ DECLARE t text; module_name text; BEGIN
  FOREACH t IN ARRAY ARRAY['propiedades','inquilinos','alquileres','pagos','mantenimientos'] LOOP
    module_name := t;
    EXECUTE format('DROP POLICY IF EXISTS tenant_select ON public.%I', t);
    EXECUTE format('DROP POLICY IF EXISTS tenant_insert ON public.%I', t);
    EXECUTE format('DROP POLICY IF EXISTS tenant_update ON public.%I', t);
    EXECUTE format('DROP POLICY IF EXISTS tenant_delete ON public.%I', t);
    EXECUTE format('CREATE POLICY tenant_select ON public.%I FOR SELECT TO authenticated USING (private.has_business_permission(company_id, %L, ''read''))', t, module_name);
    EXECUTE format('CREATE POLICY tenant_insert ON public.%I FOR INSERT TO authenticated WITH CHECK (private.has_business_permission(company_id, %L, ''create''))', t, module_name);
    EXECUTE format('CREATE POLICY tenant_update ON public.%I FOR UPDATE TO authenticated USING (private.has_business_permission(company_id, %L, ''update'')) WITH CHECK (private.has_business_permission(company_id, %L, ''update''))', t, module_name, module_name);
    EXECUTE format('CREATE POLICY tenant_delete ON public.%I FOR DELETE TO authenticated USING (private.has_business_permission(company_id, %L, ''delete''))', t, module_name);
  END LOOP;
END $$;

