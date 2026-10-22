-- Multi-tenant bootstrap: one initial company, existing users become global admins.
-- Existing business rows are assigned to the explicitly approved initial company.

CREATE TABLE IF NOT EXISTS public.companies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  slug text NOT NULL UNIQUE,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'suspended')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.companies (name, slug, status)
VALUES ('Admin', 'admin', 'active')
ON CONFLICT (slug) DO UPDATE SET name = EXCLUDED.name;

CREATE TABLE IF NOT EXISTS public.global_user_roles (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role text NOT NULL CHECK (role IN ('sysAdmin')),
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, role)
);

-- Snapshot the users that exist at migration time only. Later signups are never promoted.
INSERT INTO public.global_user_roles (user_id, role)
SELECT id, 'sysAdmin' FROM auth.users
ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS public.company_memberships (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id uuid NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role text NOT NULL DEFAULT 'usuario' CHECK (role IN ('admin_empresa', 'usuario')),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'disabled')),
  requested_at timestamptz NOT NULL DEFAULT now(),
  approved_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  approved_at timestamptz,
  UNIQUE (company_id, user_id)
);

-- Existing users are attached to the initial company as company admins as well as global admins.
INSERT INTO public.company_memberships (company_id, user_id, role, status, approved_at)
SELECT c.id, u.id, 'admin_empresa', 'approved', now()
FROM public.companies c CROSS JOIN auth.users u
WHERE c.slug = 'admin'
ON CONFLICT (company_id, user_id) DO UPDATE
SET role = 'admin_empresa', status = 'approved', approved_at = COALESCE(public.company_memberships.approved_at, now());

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS approval_status text NOT NULL DEFAULT 'approved'
    CHECK (approval_status IN ('pending', 'approved', 'rejected', 'disabled')),
  ADD COLUMN IF NOT EXISTS approved_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS approved_at timestamptz;

UPDATE public.profiles SET approval_status = 'approved', approved_at = COALESCE(approved_at, now());

ALTER TABLE public.propiedades ADD COLUMN IF NOT EXISTS company_id uuid REFERENCES public.companies(id);
ALTER TABLE public.inquilinos ADD COLUMN IF NOT EXISTS company_id uuid REFERENCES public.companies(id);
ALTER TABLE public.alquileres ADD COLUMN IF NOT EXISTS company_id uuid REFERENCES public.companies(id);
ALTER TABLE public.pagos ADD COLUMN IF NOT EXISTS company_id uuid REFERENCES public.companies(id);
ALTER TABLE public.mantenimientos ADD COLUMN IF NOT EXISTS company_id uuid REFERENCES public.companies(id);

UPDATE public.propiedades SET company_id = (SELECT id FROM public.companies WHERE slug = 'admin') WHERE company_id IS NULL;
UPDATE public.inquilinos SET company_id = (SELECT id FROM public.companies WHERE slug = 'admin') WHERE company_id IS NULL;
UPDATE public.alquileres SET company_id = (SELECT id FROM public.companies WHERE slug = 'admin') WHERE company_id IS NULL;
UPDATE public.pagos SET company_id = (SELECT id FROM public.companies WHERE slug = 'admin') WHERE company_id IS NULL;
UPDATE public.mantenimientos SET company_id = (SELECT id FROM public.companies WHERE slug = 'admin') WHERE company_id IS NULL;

ALTER TABLE public.propiedades ALTER COLUMN company_id SET NOT NULL;
ALTER TABLE public.inquilinos ALTER COLUMN company_id SET NOT NULL;
ALTER TABLE public.alquileres ALTER COLUMN company_id SET NOT NULL;
ALTER TABLE public.pagos ALTER COLUMN company_id SET NOT NULL;
ALTER TABLE public.mantenimientos ALTER COLUMN company_id SET NOT NULL;

-- Composite unique keys let relationships enforce same-company references.
ALTER TABLE public.propiedades ADD CONSTRAINT propiedades_id_company_key UNIQUE (id, company_id);
ALTER TABLE public.inquilinos ADD CONSTRAINT inquilinos_id_company_key UNIQUE (id, company_id);
ALTER TABLE public.alquileres ADD CONSTRAINT alquileres_id_company_key UNIQUE (id, company_id);

ALTER TABLE public.alquileres DROP CONSTRAINT IF EXISTS alquileres_propiedadID_fkey;
ALTER TABLE public.alquileres DROP CONSTRAINT IF EXISTS alquileres_inquilinoID_fkey;
ALTER TABLE public.pagos DROP CONSTRAINT IF EXISTS pagos_idInquilino_fkey;
ALTER TABLE public.pagos DROP CONSTRAINT IF EXISTS pagos_idalquiler_fkey;
ALTER TABLE public.mantenimientos DROP CONSTRAINT IF EXISTS mantenimientos_propiedadID_fkey;

ALTER TABLE public.alquileres
  ADD CONSTRAINT alquileres_property_company_fkey FOREIGN KEY ("propiedadID", company_id)
    REFERENCES public.propiedades(id, company_id),
  ADD CONSTRAINT alquileres_tenant_company_fkey FOREIGN KEY ("inquilinoID", company_id)
    REFERENCES public.inquilinos(id, company_id);
ALTER TABLE public.pagos
  ADD CONSTRAINT pagos_tenant_company_fkey FOREIGN KEY ("idInquilino", company_id)
    REFERENCES public.inquilinos(id, company_id),
  ADD CONSTRAINT pagos_rental_company_fkey FOREIGN KEY ("idAlquiler", company_id)
    REFERENCES public.alquileres(id, company_id);
ALTER TABLE public.mantenimientos
  ADD CONSTRAINT mantenimientos_property_company_fkey FOREIGN KEY ("propiedadID", company_id)
    REFERENCES public.propiedades(id, company_id);

CREATE INDEX IF NOT EXISTS idx_memberships_user_status ON public.company_memberships(user_id, status);
CREATE INDEX IF NOT EXISTS idx_memberships_company_status ON public.company_memberships(company_id, status);
CREATE INDEX IF NOT EXISTS idx_propiedades_company ON public.propiedades(company_id);
CREATE INDEX IF NOT EXISTS idx_inquilinos_company ON public.inquilinos(company_id);
CREATE INDEX IF NOT EXISTS idx_alquileres_company ON public.alquileres(company_id);
CREATE INDEX IF NOT EXISTS idx_pagos_company ON public.pagos(company_id);
CREATE INDEX IF NOT EXISTS idx_mantenimientos_company ON public.mantenimientos(company_id);

CREATE OR REPLACE FUNCTION public.is_platform_admin()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.global_user_roles gur
    WHERE gur.user_id = auth.uid() AND gur.role = 'sysAdmin'
  );
$$;

CREATE OR REPLACE FUNCTION public.has_company_access(target_company uuid, require_admin boolean DEFAULT false)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
  SELECT public.is_platform_admin() OR EXISTS (
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
  );
$$;

CREATE OR REPLACE FUNCTION public.set_business_company_id()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE selected_company uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Se requiere una sesión autenticada';
  END IF;
  IF public.is_platform_admin() AND NEW.company_id IS NOT NULL THEN
    selected_company := NEW.company_id;
  ELSE
    SELECT m.company_id INTO selected_company
    FROM public.company_memberships m
    JOIN public.companies c ON c.id = m.company_id
    WHERE m.user_id = auth.uid() AND m.status = 'approved' AND c.status = 'active'
    ORDER BY m.requested_at LIMIT 1;
  END IF;
  IF selected_company IS NULL OR NOT public.has_company_access(selected_company, false) THEN
    RAISE EXCEPTION 'El usuario no tiene una empresa activa autorizada';
  END IF;
  IF TG_OP = 'UPDATE' AND NEW.company_id IS DISTINCT FROM OLD.company_id THEN
    RAISE EXCEPTION 'No se permite cambiar la empresa de un registro';
  END IF;
  NEW.company_id := selected_company;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.prevent_profile_privilege_escalation()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$ BEGIN
  IF auth.uid() = OLD.id AND NOT public.is_platform_admin() AND (
    NEW.role_id IS DISTINCT FROM OLD.role_id OR
    NEW.is_active IS DISTINCT FROM OLD.is_active OR
    NEW.approval_status IS DISTINCT FROM OLD.approval_status OR
    NEW.approved_by IS DISTINCT FROM OLD.approved_by OR
    NEW.approved_at IS DISTINCT FROM OLD.approved_at
  ) THEN RAISE EXCEPTION 'No puedes modificar tus privilegios o estado de aprobación'; END IF;
  RETURN NEW;
END; $$;

DROP TRIGGER IF EXISTS protect_profile_privileges ON public.profiles;
CREATE TRIGGER protect_profile_privileges BEFORE UPDATE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.prevent_profile_privilege_escalation();

DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['propiedades','inquilinos','alquileres','pagos','mantenimientos'] LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS set_company_id ON public.%I', t);
    EXECUTE format('CREATE TRIGGER set_company_id BEFORE INSERT OR UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.set_business_company_id()', t);
  END LOOP;
END $$;

-- Replace the unsafe signup behavior: caller-supplied roles are ignored; memberships stay pending.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE requested_company uuid;
BEGIN
  INSERT INTO public.profiles (id, email, full_name, phone, role_id, is_active, approval_status, "Origen", usuario)
  VALUES (
    NEW.id, NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
    COALESCE(NEW.raw_user_meta_data->>'phone', ''),
    'agente', false, 'pending',
    CASE WHEN lower(COALESCE(NEW.raw_user_meta_data->>'Origen','web')) IN ('movil','móvil','mobile') THEN 'movil' ELSE 'web' END,
    NEW.id
  ) ON CONFLICT (id) DO UPDATE SET email = EXCLUDED.email, full_name = EXCLUDED.full_name;
  BEGIN requested_company := NULLIF(NEW.raw_user_meta_data->>'company_id','')::uuid;
  EXCEPTION WHEN invalid_text_representation THEN requested_company := NULL; END;
  IF requested_company IS NOT NULL AND EXISTS (SELECT 1 FROM public.companies WHERE id=requested_company AND status='active') THEN
    INSERT INTO public.company_memberships(company_id,user_id,role,status)
    VALUES (requested_company,NEW.id,'usuario','pending') ON CONFLICT (company_id,user_id) DO NOTHING;
  END IF;
  RETURN NEW;
END; $$;

CREATE OR REPLACE FUNCTION public.get_user_permissions(user_id uuid)
RETURNS TABLE(permission_id text)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
  SELECT rp.permission_id
  FROM public.profiles p
  JOIN public.role_permissions rp ON rp.role_id = p.role_id
  WHERE p.id = auth.uid() AND user_id = auth.uid()
    AND p.approval_status = 'approved' AND p.is_active IS TRUE;
$$;

CREATE OR REPLACE FUNCTION public.review_company_membership(membership_id uuid, approve boolean, assigned_role text DEFAULT 'usuario')
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE target public.company_memberships%ROWTYPE;
BEGIN
  SELECT * INTO target FROM public.company_memberships WHERE id = membership_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Solicitud no encontrada'; END IF;
  IF NOT public.is_platform_admin() AND NOT public.has_company_access(target.company_id, true) THEN
    RAISE EXCEPTION 'No autorizado para administrar esta empresa';
  END IF;
  IF assigned_role NOT IN ('usuario','admin_empresa') OR (assigned_role='admin_empresa' AND NOT public.is_platform_admin()) THEN
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

-- RLS helper and trigger functions are server internals; expose only intended calls.
REVOKE ALL ON FUNCTION public.is_platform_admin() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.has_company_access(uuid, boolean) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.set_business_company_id() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.prevent_profile_privilege_escalation() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.get_user_permissions(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.review_company_membership(uuid, boolean, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_platform_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.has_company_access(uuid, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_permissions(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.review_company_membership(uuid, boolean, text) TO authenticated;

ALTER TABLE public.companies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.global_user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.company_memberships ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Acceso total a propiedades" ON public.propiedades;
DROP POLICY IF EXISTS "Acceso total a inquilinos" ON public.inquilinos;
DROP POLICY IF EXISTS "Acceso total a alquileres" ON public.alquileres;
DROP POLICY IF EXISTS "Acceso total a pagos" ON public.pagos;
DROP POLICY IF EXISTS "Acceso total a mantenimientos" ON public.mantenimientos;
DROP POLICY IF EXISTS "Acceso total a estados" ON public.estados;
DROP POLICY IF EXISTS "Lectura de perfiles para autenticados" ON public.profiles;
DROP POLICY IF EXISTS "Inserción de perfiles" ON public.profiles;

DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['propiedades','inquilinos','alquileres','pagos','mantenimientos'] LOOP
    EXECUTE format('CREATE POLICY tenant_select ON public.%I FOR SELECT TO authenticated USING (public.has_company_access(company_id, false))', t);
    EXECUTE format('CREATE POLICY tenant_insert ON public.%I FOR INSERT TO authenticated WITH CHECK (public.has_company_access(company_id, false))', t);
    EXECUTE format('CREATE POLICY tenant_update ON public.%I FOR UPDATE TO authenticated USING (public.has_company_access(company_id, false)) WITH CHECK (public.has_company_access(company_id, false))', t);
    EXECUTE format('CREATE POLICY tenant_delete ON public.%I FOR DELETE TO authenticated USING (public.has_company_access(company_id, false))', t);
  END LOOP;
END $$;

CREATE POLICY companies_read_member ON public.companies FOR SELECT TO authenticated
USING (status='active' AND (public.is_platform_admin() OR public.has_company_access(id, false)));
CREATE POLICY companies_public_signup_list ON public.companies FOR SELECT TO anon USING (status='active');
CREATE POLICY companies_admin_manage ON public.companies FOR ALL TO authenticated
USING (public.is_platform_admin()) WITH CHECK (public.is_platform_admin());

CREATE POLICY global_roles_self_read ON public.global_user_roles FOR SELECT TO authenticated
USING (user_id=auth.uid() OR public.is_platform_admin());
CREATE POLICY memberships_read_self_or_admin ON public.company_memberships FOR SELECT TO authenticated
USING (user_id=auth.uid() OR public.is_platform_admin() OR public.has_company_access(company_id, true));

CREATE POLICY profiles_read_self_or_admin ON public.profiles FOR SELECT TO authenticated
USING (id=auth.uid() OR public.is_platform_admin());
CREATE POLICY profiles_update_self ON public.profiles FOR UPDATE TO authenticated
USING (id=auth.uid()) WITH CHECK (id=auth.uid());

-- Lookup and RBAC catalog tables contain no tenant business data; require authentication.
DROP POLICY IF EXISTS "Lectura de roles para todos" ON public.roles;
CREATE POLICY roles_authenticated_read ON public.roles FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "Lectura de permisos para autenticados" ON public.permissions;
CREATE POLICY permissions_authenticated_read ON public.permissions FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "Lectura de rol_permisos para autenticados" ON public.role_permissions;
CREATE POLICY role_permissions_authenticated_read ON public.role_permissions FOR SELECT TO authenticated USING (true);
CREATE POLICY estados_authenticated_read ON public.estados FOR SELECT TO authenticated USING (true);

REVOKE ALL ON public.companies, public.global_user_roles, public.company_memberships FROM anon;
GRANT SELECT ON public.companies, public.global_user_roles, public.company_memberships TO authenticated;
GRANT SELECT ON public.companies TO anon;

