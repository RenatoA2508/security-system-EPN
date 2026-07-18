-- crear_vehiculo_con_propietario: los parametros realmente opcionales pasan a
-- tener DEFAULT null.
--
-- Motivo: en la version original solo p_tipo_relacion, p_fecha_inicio y
-- p_motivo_sin_placa tenian DEFAULT. Placa, marca, modelo y color eran
-- obligatorios en la firma aunque el negocio los admite nulos (una bicicleta no
-- tiene placa; marca/modelo/color son opcionales). Eso obligaba al cliente a
-- enviar null explicito y, al generar los tipos TypeScript desde la base, se
-- tipaban como `string` no nulo: el frontend no podia expresar "sin placa".
--
-- El orden de los parametros cambia (los obligatorios primero), asi que la firma
-- anterior se elimina ANTES de crear la nueva: mientras coexisten, cualquier
-- referencia sin lista de argumentos (COMMENT, GRANT) seria ambigua.
drop function if exists public.crear_vehiculo_con_propietario(text, text, text, text, text, uuid, text, timestamptz, text);

create or replace function public.crear_vehiculo_con_propietario(
  p_tipo_vehiculo text,
  p_id_persona uuid,
  p_placa text default null,
  p_marca text default null,
  p_modelo text default null,
  p_color text default null,
  p_tipo_relacion text default 'PROPIETARIO',
  p_fecha_inicio timestamptz default now(),
  p_motivo_sin_placa text default null
)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_id_vehiculo uuid;
  v_id_relacion uuid;
  v_uid uuid := auth.uid();
  v_persona record;
begin
  if v_uid is null then
    raise exception 'Se requiere un usuario autenticado.' using errcode = 'insufficient_privilege';
  end if;

  if p_id_persona is null then
    raise exception 'Debe indicar la persona propietaria (busquela por cedula).' using errcode = 'check_violation';
  end if;

  select id_persona, estado, nombres, apellidos into v_persona
    from public.persona
   where id_persona = p_id_persona;

  if v_persona.id_persona is null then
    raise exception 'No se encontro la persona o no tienes permiso para verla.' using errcode = 'no_data_found';
  end if;
  if v_persona.estado <> 'ACTIVO' then
    raise exception 'La persona esta % : no se le puede asociar un vehiculo.', v_persona.estado using errcode = 'check_violation';
  end if;

  insert into public.vehiculo (placa, tipo_vehiculo, marca, modelo, color, motivo_sin_placa, id_usuario_registro)
  values (p_placa, p_tipo_vehiculo, p_marca, p_modelo, p_color, p_motivo_sin_placa, v_uid)
  returning id_vehiculo into v_id_vehiculo;

  insert into public.persona_vehiculo (id_persona, id_vehiculo, tipo_relacion, fecha_inicio, estado_relacion, id_usuario_registro)
  values (p_id_persona, v_id_vehiculo, coalesce(p_tipo_relacion, 'PROPIETARIO'), coalesce(p_fecha_inicio, now()), 'ACTIVA', v_uid)
  returning id_persona_vehiculo into v_id_relacion;

  return jsonb_build_object(
    'id_vehiculo', v_id_vehiculo,
    'id_persona_vehiculo', v_id_relacion,
    'persona', v_persona.nombres || ' ' || v_persona.apellidos
  );
end;
$$;

comment on function public.crear_vehiculo_con_propietario(text, uuid, text, text, text, text, text, timestamptz, text) is
  'Crea vehiculo y persona_vehiculo en una transaccion (req 35). SECURITY INVOKER: respeta RLS. Rollback total si falla la asociacion.';

revoke execute on function public.crear_vehiculo_con_propietario(text, uuid, text, text, text, text, text, timestamptz, text) from public, anon;
grant execute on function public.crear_vehiculo_con_propietario(text, uuid, text, text, text, text, text, timestamptz, text) to authenticated;
