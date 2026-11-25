alter table public.pagos
  add column if not exists creado_por text,
  add column if not exists editado_por text;

create or replace function private.set_payment_receipt_authorship()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  caller uuid := auth.uid();
  actor text;
begin
  -- Offline mobile payments keep the operator recorded before synchronization.
  if caller is not null and new."Origen" = 'movil'
      and new.usuario = '00000000-0000-0000-0000-000000000000'::uuid then
    new.creado_por := nullif(btrim(new.creado_por), '');
    new.editado_por := nullif(btrim(new.editado_por), '');
    if tg_op = 'UPDATE' then
      new.creado_por := old.creado_por;
      new.editado_por := coalesce(new.editado_por, old.editado_por);
    end if;
    return new;
  end if;

  if caller is not null then
    select coalesce(nullif(btrim(p."usuarioSesion"), ''), nullif(btrim(p.full_name), ''))
      into actor
    from public.profiles p
    where p.id = caller;
  end if;

  if tg_op = 'INSERT' then
    new.creado_por := actor;
    new.editado_por := null;
  else
    new.creado_por := old.creado_por;
    new.editado_por := coalesce(actor, old.editado_por);
  end if;
  return new;
end;
$$;

revoke all on function private.set_payment_receipt_authorship() from public, anon, authenticated;

create trigger set_payment_receipt_authorship
before insert or update on public.pagos
for each row execute function private.set_payment_receipt_authorship();

-- Alquilados_Test publishes a limited payment snapshot to mobile clients.
do $migration$
declare
  recorder regprocedure := to_regprocedure('private.record_mobile_crm_change(text,jsonb,boolean)');
  definition text;
  payment_fields text := $fields$when 'pagos' then array['idInquilino', 'idAlquiler', 'fechaPago', 'fechaVencimiento', 'monto', 'periodo', 'estado']$fields$;
begin
  if recorder is null then
    return;
  end if;

  definition := pg_get_functiondef(recorder);
  if strpos(definition, payment_fields) = 0 then
    raise exception 'Unexpected mobile payment feed projection';
  end if;

  execute replace(
    definition,
    payment_fields,
    left(payment_fields, -1) || $fields$, 'metodoPago', 'banco', 'creado_por', 'editado_por']$fields$
  );
end;
$migration$;
