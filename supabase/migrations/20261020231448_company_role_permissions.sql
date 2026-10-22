-- Tenant-specific permission assignments based on the existing CRM catalog.
CREATE TABLE IF NOT EXISTS public.company_role_permissions (
  company_id uuid NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  role_id text NOT NULL REFERENCES public.roles(id) ON DELETE CASCADE,
  permission_id text NOT NULL REFERENCES public.permissions(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (company_id, role_id, permission_id)
);

ALTER TABLE public.company_role_permissions ENABLE ROW LEVEL SECURITY;
INSERT INTO public.company_role_permissions(company_id, role_id, permission_id)
SELECT c.id, rp.role_id, rp.permission_id
FROM public.companies c CROSS JOIN public.role_permissions rp
ON CONFLICT DO NOTHING;

CREATE OR REPLACE FUNCTION private.seed_company_permissions()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
  INSERT INTO public.company_role_permissions(company_id, role_id, permission_id)
  SELECT NEW.id, rp.role_id, rp.permission_id FROM public.role_permissions rp
  ON CONFLICT DO NOTHING;
  RETURN NEW;
END; $$;

DROP TRIGGER IF EXISTS seed_company_permissions_after_insert ON public.companies;
CREATE TRIGGER seed_company_permissions_after_insert
AFTER INSERT ON public.companies
FOR EACH ROW EXECUTE FUNCTION private.seed_company_permissions();

CREATE OR REPLACE FUNCTION private.has_business_permission(target_company uuid, module_name text, action_name text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$ SELECT private.is_platform_admin() OR EXISTS (
  SELECT 1
  FROM public.company_memberships m
  JOIN public.companies c ON c.id = m.company_id
  JOIN public.profiles p ON p.id = m.user_id
  JOIN public.company_role_permissions crp
    ON crp.company_id = m.company_id AND crp.role_id = m.app_role_id
  WHERE m.user_id = auth.uid()
    AND m.company_id = target_company
    AND m.status = 'approved'
    AND p.approval_status = 'approved'
    AND p.is_active IS TRUE
    AND c.status = 'active'
    AND (
      m.role = 'admin_empresa'
      OR crp.permission_id = module_name || ':' || action_name
      OR crp.permission_id = module_name || ':manage'
    )
); $$;

REVOKE ALL ON FUNCTION private.seed_company_permissions() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.has_business_permission(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.has_business_permission(uuid, text, text) TO authenticated;

CREATE POLICY company_permissions_read ON public.company_role_permissions FOR SELECT TO authenticated
USING (private.has_company_access(company_id, false));
CREATE POLICY company_permissions_manage ON public.company_role_permissions FOR ALL TO authenticated
USING (private.is_platform_admin() OR private.has_company_access(company_id, true))
WITH CHECK (private.is_platform_admin() OR private.has_company_access(company_id, true));

REVOKE ALL ON public.company_role_permissions FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.company_role_permissions TO authenticated;
