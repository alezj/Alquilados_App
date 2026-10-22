-- Allow tenant admins to review only profiles of users in their own company.
DROP POLICY IF EXISTS profiles_company_admin_read ON public.profiles;
CREATE POLICY profiles_company_admin_read ON public.profiles FOR SELECT TO authenticated
USING (EXISTS (
  SELECT 1 FROM public.company_memberships target_membership
  WHERE target_membership.user_id = profiles.id
    AND private.has_company_access(target_membership.company_id, true)
));
