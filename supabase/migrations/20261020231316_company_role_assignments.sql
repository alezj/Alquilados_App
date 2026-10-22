-- Keep each tenant member's application role on that tenant membership.
ALTER TABLE public.company_memberships
  ADD COLUMN IF NOT EXISTS app_role_id text NOT NULL DEFAULT 'agente'
    REFERENCES public.roles(id) ON DELETE RESTRICT;

UPDATE public.company_memberships m
SET app_role_id = p.role_id
FROM public.profiles p
WHERE p.id = m.user_id AND m.app_role_id = 'agente' AND p.role_id IN (
  SELECT id FROM public.roles
);

CREATE OR REPLACE FUNCTION private.has_business_permission(target_company uuid, module_name text, action_name text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$ SELECT private.is_platform_admin() OR EXISTS (
  SELECT 1
  FROM public.company_memberships m
  JOIN public.companies c ON c.id = m.company_id
  JOIN public.profiles p ON p.id = m.user_id
  JOIN public.role_permissions rp ON rp.role_id = m.app_role_id
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

DROP FUNCTION public.review_company_membership(uuid, boolean, text);
CREATE FUNCTION public.review_company_membership(
  membership_id uuid,
  approve boolean,
  assigned_role text DEFAULT 'usuario',
  assigned_app_role text DEFAULT 'agente'
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public, auth, private
AS $$
DECLARE target public.company_memberships%ROWTYPE;
BEGIN
  SELECT * INTO target FROM public.company_memberships WHERE id = membership_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Solicitud no encontrada'; END IF;
  IF NOT private.is_platform_admin() AND NOT private.has_company_access(target.company_id, true) THEN
    RAISE EXCEPTION 'No autorizado para administrar esta empresa';
  END IF;
  IF assigned_role NOT IN ('usuario','admin_empresa') OR (assigned_role='admin_empresa' AND NOT private.is_platform_admin()) THEN
    RAISE EXCEPTION 'Rol de empresa no permitido';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.roles WHERE id = assigned_app_role)
     OR (assigned_app_role='admin' AND NOT private.is_platform_admin()) THEN
    RAISE EXCEPTION 'Rol de aplicación no permitido';
  END IF;
  UPDATE public.company_memberships
  SET role = CASE WHEN approve THEN assigned_role ELSE role END,
      app_role_id = CASE WHEN approve THEN assigned_app_role ELSE app_role_id END,
      status = CASE WHEN approve THEN 'approved' ELSE 'rejected' END,
      approved_by = auth.uid(), approved_at = CASE WHEN approve THEN now() ELSE NULL END
  WHERE id = membership_id;
  UPDATE public.profiles SET is_active = approve,
    approval_status = CASE WHEN approve THEN 'approved' ELSE 'rejected' END,
    approved_by = auth.uid(), approved_at = CASE WHEN approve THEN now() ELSE NULL END
  WHERE id = target.user_id;
END; $$;

REVOKE ALL ON FUNCTION public.review_company_membership(uuid, boolean, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.review_company_membership(uuid, boolean, text, text) TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.companies TO authenticated;

