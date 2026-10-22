-- The tenant-aware permission checks now run inside private RLS helpers.
-- Keep the legacy global permission RPC unavailable through PostgREST.
REVOKE ALL ON FUNCTION public.get_user_permissions(uuid) FROM PUBLIC, anon, authenticated;
