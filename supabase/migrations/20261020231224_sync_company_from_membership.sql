-- Resolve the tenant from the authenticated membership when mobile sync omits
-- company_id. Explicit tenant values remain server-validated.
CREATE OR REPLACE FUNCTION public.set_business_company_id()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public, auth, private
AS $$
DECLARE selected_company uuid;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Se requiere una sesión autenticada'; END IF;
  IF TG_OP = 'UPDATE' THEN
    selected_company := OLD.company_id;
  ELSIF NEW.company_id IS NOT NULL THEN
    IF private.has_company_access(NEW.company_id, false) THEN
      selected_company := NEW.company_id;
    ELSE
      RAISE EXCEPTION 'El usuario no pertenece a la empresa indicada';
    END IF;
  ELSE
    SELECT m.company_id INTO selected_company
    FROM public.company_memberships m
    JOIN public.companies c ON c.id = m.company_id
    WHERE m.user_id = auth.uid() AND m.status = 'approved' AND c.status = 'active'
      AND EXISTS (
        SELECT 1 FROM public.profiles p WHERE p.id = auth.uid()
          AND p.approval_status = 'approved' AND p.is_active IS TRUE
      )
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

REVOKE ALL ON FUNCTION public.set_business_company_id() FROM PUBLIC, anon, authenticated;
