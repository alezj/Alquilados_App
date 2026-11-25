-- Extends the mobile payment RPC in Alquilados_Test. Production uses Data API writes.
create or replace function mobile_payment_private.write_payment(
  p_company_id uuid,
  p_operation_id uuid,
  p_command jsonb
) returns bigint
language plpgsql
security definer
set search_path = ''
as $$
<<payment_operation>>
declare
  caller uuid := auth.uid();
  action text := p_command->>'action';
  payment_id bigint := (p_command->>'payment_id')::bigint;
  tenant_id bigint := (p_command->>'tenant_id')::bigint;
  rental_id bigint := (p_command->>'rental_id')::bigint;
  expected_revision bigint := (p_command->>'revision')::bigint;
  current_revision bigint;
  amount numeric := (p_command->>'amount')::numeric;
  payment_date text := p_command->>'date';
  payment_status text;
  payment_method text := nullif(btrim(p_command->>'method'), '');
  payment_bank text := nullif(btrim(p_command->>'bank'), '');
  requires_bank boolean;
  previous_request mobile_payment_private.requests%rowtype;
  current_payment public.pagos%rowtype;
begin
  if caller is null or not private.can_read_mobile_crm_feed(p_company_id) then
    raise exception using errcode = '42501', message = 'Tu cuenta no tiene acceso a los pagos de esta empresa.';
  end if;
  if p_operation_id is null or jsonb_typeof(p_command) is distinct from 'object'
      or action is null or action not in ('create', 'update', 'status', 'delete') then
    raise exception using errcode = '22023', message = 'La operación del pago es inválida.';
  end if;

  insert into mobile_payment_private.requests(company_id, operation_id, command)
  values (p_company_id, p_operation_id, p_command)
  on conflict do nothing;
  if not found then
    select * into strict previous_request from mobile_payment_private.requests r
    where r.company_id = p_company_id and r.operation_id = p_operation_id;
    if previous_request.command <> p_command then
      raise exception using errcode = 'PT409', message = 'El número de operación ya pertenece a un pago diferente.';
    end if;
    return previous_request.payment_id;
  end if;

  if action <> 'create' then
    select * into current_payment from public.pagos p
    where (p.company_id = p_company_id or (p.company_id is null and exists (
        select from public.mobile_crm_change_feed f
        where f.company_id = p_company_id and f.resource = 'pagos'
          and f.remote_id = p.id and f.record is not null
      ))) and p.id = payment_id and (p.usuario = caller
      or (p."Origen" = 'movil' and p.usuario = '00000000-0000-0000-0000-000000000000'))
    for update;
    if not found then
      raise exception using errcode = 'PT404', message = 'El pago ya no está disponible en el CRM.';
    end if;

    select f.revision into current_revision
    from public.mobile_crm_change_feed f
    where f.company_id = p_company_id and f.resource = 'pagos'
      and f.remote_id = payment_id and f.record is not null;
    if current_revision is null or current_revision is distinct from expected_revision then
      raise exception using errcode = 'PT409', message = 'El pago cambió en el CRM. Actualiza la lista y revisa el pago antes de reintentar.';
    end if;
    if action = 'update' and current_payment."idInquilino" is distinct from tenant_id then
      rental_id := null;
    else
      rental_id := current_payment."idAlquiler";
    end if;
  end if;

  if action <> 'delete' then
    payment_status := case p_command->>'status'
      when 'pendiente' then 'Pendiente'
      when 'pagado' then 'Pagado'
      when 'vencido' then 'Atrasado'
    end;
    if payment_status is null then
      raise exception using errcode = '22023', message = 'El estado del pago es inválido.';
    end if;
    if action = 'create' or action = 'update' or payment_status = 'Pagado' then
      if payment_date is null or payment_date !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
          or not pg_input_is_valid(payment_date, 'date') then
        raise exception using errcode = '22023', message = 'Selecciona una fecha de pago válida.';
      end if;
    end if;
    if action = 'create' or action = 'update' then
      if amount is null or not (amount > 0 and amount < 10000000000)
          or round(amount, 2) <> amount then
        raise exception using errcode = '22023', message = 'Ingresa un monto positivo con hasta dos decimales.';
      end if;
      if not exists (select from public.inquilinos i where (i.company_id = p_company_id or (i.company_id is null and exists (
        select from public.mobile_crm_change_feed f
        where f.company_id = p_company_id and f.resource = 'inquilinos'
          and f.remote_id = i.id and f.record is not null
      ))) and i.id = tenant_id and
          (i.usuario = caller or (i."Origen" = 'movil' and i.usuario = '00000000-0000-0000-0000-000000000000'))) then
        raise exception using errcode = '22023', message = 'Selecciona un inquilino que exista en el CRM de esta empresa.';
      end if;
      if p_command ? 'method' then
        select f.requiere_banco into requires_bank
        from public.formas_pago f
        where f.company_id = p_company_id and f.activa and f.nombre = payment_method;

        if not found then
          raise exception using errcode = '22023', message = 'Selecciona una forma de pago activa de tu empresa.';
        end if;
        if requires_bank and not exists (
          select from public.bancos b
          where b.company_id = p_company_id and b.activo and b.nombre = payment_bank
        ) then
          raise exception using errcode = '22023', message = 'Selecciona un banco activo de tu empresa.';
        end if;
        if not requires_bank then
          payment_bank := null;
        end if;
      end if;
      if rental_id is not null and not exists (select from public.alquileres a
          where (a.company_id = p_company_id or (a.company_id is null and exists (
        select from public.mobile_crm_change_feed f
        where f.company_id = p_company_id and f.resource = 'alquileres'
          and f.remote_id = a.id and f.record is not null
      ))) and a.id = rental_id and a."inquilinoID" = tenant_id and
            (a.usuario = caller or (a."Origen" = 'movil' and a.usuario = '00000000-0000-0000-0000-000000000000'))) then
        raise exception using errcode = '22023', message = 'El alquiler y el inquilino deben corresponder en el CRM.';
      end if;
    end if;
  end if;

  if action = 'create' then
    insert into public.pagos (company_id, "Origen", usuario, "idInquilino", "idAlquiler", periodo,
      "fechaPago", "fechaVencimiento", monto, estado, "metodoPago", banco)
    values (p_company_id, 'movil', caller, tenant_id, rental_id, left(payment_date, 7),
      case when payment_status = 'Pagado' then payment_date else '' end,
      payment_date, amount, payment_status, case when p_command ? 'method' then payment_method end,
      case when p_command ? 'method' then payment_bank end)
    returning id into payment_id;
  elsif action = 'update' then
    update public.pagos set "idInquilino" = tenant_id, "idAlquiler" = rental_id, monto = amount,
      "metodoPago" = case when p_command ? 'method' then payment_method else "metodoPago" end,
      banco = case when p_command ? 'method' then payment_bank else banco end,
      "fechaPago" = case when payment_status = 'Pagado' then payment_date else '' end,
      "fechaVencimiento" = case when payment_status = 'Pagado'
        then coalesce(nullif("fechaVencimiento", ''), payment_date) else payment_date end,
      periodo = coalesce(nullif(periodo, ''), left(payment_date, 7)),
      estado = payment_status
    where company_id is not distinct from current_payment.company_id and id = payment_id
      and usuario = current_payment.usuario and "Origen" = current_payment."Origen";
  elsif action = 'status' then
    update public.pagos set estado = payment_status,
      "fechaPago" = case when payment_status = 'Pagado' then
        case when lower(estado) in ('pagado','paid','completado','completada') and "fechaPago" <> ''
          then "fechaPago" else payment_date end
        else '' end
    where company_id is not distinct from current_payment.company_id and id = payment_id
      and usuario = current_payment.usuario and "Origen" = current_payment."Origen";
  else
    delete from public.pagos where company_id is not distinct from current_payment.company_id and id = payment_id
      and usuario = current_payment.usuario and "Origen" = current_payment."Origen";
  end if;

  update mobile_payment_private.requests
  set payment_id = payment_operation.payment_id
  where company_id = p_company_id and operation_id = p_operation_id;
  return payment_id;
end;
$$;

