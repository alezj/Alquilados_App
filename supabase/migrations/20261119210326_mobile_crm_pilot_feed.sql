create schema if not exists private;

create table private.mobile_crm_pilot (
  company_id uuid primary key references public.companies(id),
  reader_id uuid not null unique references auth.users(id),
  revision bigint not null default 0
);

revoke all on private.mobile_crm_pilot from public, anon, authenticated;

create table public.mobile_crm_change_feed (
  company_id uuid not null references private.mobile_crm_pilot(company_id),
  revision bigint not null,
  resource text not null check (resource in ('propiedades', 'inquilinos', 'alquileres', 'pagos')),
  remote_id bigint not null,
  record jsonb,
  primary key (company_id, resource, remote_id),
  unique (company_id, revision)
);

alter table public.mobile_crm_change_feed enable row level security;
revoke all on public.mobile_crm_change_feed from public, anon, authenticated;
grant select on public.mobile_crm_change_feed to authenticated;

create function private.can_read_mobile_crm_feed(target_company uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from private.mobile_crm_pilot s
    join public.companies c on c.id = s.company_id and c.status = 'active'
    join public.profiles p on p.id = s.reader_id
      and p.approval_status = 'approved' and p.is_active
    join public.company_memberships m on m.company_id = s.company_id
      and m.user_id = s.reader_id and m.status = 'approved'
    where s.company_id = target_company and s.reader_id = (select auth.uid())
  );
$$;

revoke all on function private.can_read_mobile_crm_feed(uuid) from public, anon, authenticated;
grant execute on function private.can_read_mobile_crm_feed(uuid) to authenticated;
create policy mobile_crm_pilot_read on public.mobile_crm_change_feed
  for select to authenticated using (private.can_read_mobile_crm_feed(company_id));

create function private.record_mobile_crm_change(resource_name text, source jsonb, removed boolean)
returns void
language plpgsql
set search_path = ''
as $$
declare
  scope_company uuid;
  next_revision bigint;
  fields text[];
  snapshot jsonb;
  caller uuid := auth.uid();
begin
  -- The legacy test schema has no tenant column. Only the explicitly enrolled
  -- account and its verified legacy mobile rows belong to this pilot.
  select p.company_id into scope_company
  from private.mobile_crm_pilot p
  where (source->>'usuario' = p.reader_id::text
      or (source->>'Origen' = 'movil'
          and source->>'usuario' = '00000000-0000-0000-0000-000000000000'))
    and (caller = p.reader_id
      or (caller is null and session_user in ('postgres', 'supabase_admin')));
  if scope_company is null then
    return;
  end if;

  if not removed then
    fields := array['id', 'Origen', 'usuario', 'created_at'] ||
      case resource_name
        when 'propiedades' then array['nombre', 'direccion', 'estado', 'precioMensual', 'notas']
        when 'inquilinos' then array['nombreApellido', 'correo', 'email', 'fechaInicioContrato', 'fechaPagos', 'telefono']
        when 'alquileres' then array['propiedadID', 'inquilinoID', 'fechaInicio', 'fechaFin', 'importe', 'montoPago', 'cantidadDepositos', 'diaPago', 'diasProrroga', 'cantidadMeses', 'estado']
        when 'pagos' then array['idInquilino', 'idAlquiler', 'fechaPago', 'fechaVencimiento', 'monto', 'periodo', 'estado']
      end;
    select jsonb_object_agg(key, value) into snapshot
    from jsonb_each(source) where key = any(fields);
  end if;

  -- Holding the counter row until commit prevents a later visible revision
  -- from overtaking an earlier uncommitted revision of this feed.
  update private.mobile_crm_pilot set revision = revision + 1
  where company_id = scope_company returning revision into next_revision;

  insert into public.mobile_crm_change_feed(company_id, revision, resource, remote_id, record)
  values (scope_company, next_revision, resource_name, (source->>'id')::bigint, snapshot)
  on conflict (company_id, resource, remote_id) do update
    set revision = excluded.revision, record = excluded.record;
end;
$$;

revoke all on function private.record_mobile_crm_change(text, jsonb, boolean) from public, anon, authenticated;

create function private.capture_mobile_crm_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    perform private.record_mobile_crm_change(tg_table_name, to_jsonb(old), true);
  else
    if tg_op = 'UPDATE' and (old.id, old."Origen", old.usuario)
        is distinct from (new.id, new."Origen", new.usuario) then
      perform private.record_mobile_crm_change(tg_table_name, to_jsonb(old), true);
    end if;
    perform private.record_mobile_crm_change(tg_table_name, to_jsonb(new), false);
  end if;
  return null;
end;
$$;

revoke all on function private.capture_mobile_crm_change() from public, anon, authenticated;

create trigger capture_mobile_crm_change after insert or update or delete on public.propiedades
for each row execute function private.capture_mobile_crm_change();
create trigger capture_mobile_crm_change after insert or update or delete on public.inquilinos
for each row execute function private.capture_mobile_crm_change();
create trigger capture_mobile_crm_change after insert or update or delete on public.alquileres
for each row execute function private.capture_mobile_crm_change();
create trigger capture_mobile_crm_change after insert or update or delete on public.pagos
for each row execute function private.capture_mobile_crm_change();

-- An administrator enrolls and backfills the verified account separately in
-- Alquilados_Test. Applying this migration alone never enrolls an account.
