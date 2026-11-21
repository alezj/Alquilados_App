do $migration$
declare
  definition text;
begin
  select pg_get_functiondef('mobile_payment_private.write_payment(uuid,uuid,jsonb)'::regprocedure)
  into definition;
  if strpos(definition, 'set payment_id = write_payment.payment_id') = 0 then
    raise exception 'Unexpected payment function definition';
  end if;
  execute replace(
    replace(definition, E'\ndeclare\n', E'\n<<payment_operation>>\ndeclare\n'),
    'set payment_id = write_payment.payment_id',
    'set payment_id = payment_operation.payment_id'
  );
end;
$migration$;
