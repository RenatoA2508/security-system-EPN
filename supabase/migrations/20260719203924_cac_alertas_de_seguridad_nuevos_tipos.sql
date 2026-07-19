-- CAC RF-CA-023: la lista de eventos que deben generar alerta incluye tres casos que el
-- catalogo de tipo_alerta no contemplaba:
--   - "Intento de ingreso por una garita no autorizada"  -> GARITA_NO_AUTORIZADA
--     (antes caia en el cajon de sastre PERSONA_NO_AUTORIZADA y era indistinguible de un
--      bloqueo de la persona, que es un problema completamente distinto para el guardia)
--   - "Intento de ingreso de una persona desconocida"    -> PERSONA_DESCONOCIDA
--   - "placa no registrada o no asociada al usuario"     -> PLACA_NO_RECONOCIDA
-- Y RNF-CA-005 anade la denegacion por doble autenticacion incompleta.

alter table public.alerta_seguridad
  drop constraint alerta_seguridad_tipo_alerta_check;

alter table public.alerta_seguridad
  add constraint alerta_seguridad_tipo_alerta_check
  check (tipo_alerta in (
    'BIOMETRIA_FALLIDA', 'PERSONA_NO_AUTORIZADA', 'MEMORANDO_VENCIDO', 'FUERA_DE_HORARIO',
    'PUNTO_SALIDA_INCORRECTO', 'DISPOSITIVO_NO_RECONOCIDO', 'VEHICULO_NO_AUTORIZADO',
    'VEHICULO_PERMANENCIA_EXCEDIDA', 'VEHICULO_ABANDONADO',
    'PERSONA_DESCONOCIDA', 'GARITA_NO_AUTORIZADA', 'PLACA_NO_RECONOCIDA',
    'DOBLE_AUTENTICACION_FALLIDA'
  ));

-- El trigger deriva el tipo de alerta del prefijo canonico del motivo. Se amplia la lista de
-- codigos reconocidos y se gradua el nivel de riesgo por tipo: hasta ahora todo era MEDIO
-- salvo el vehiculo, y un desconocido intentando entrar no es lo mismo que un docente que
-- llega diez minutos tarde.
create or replace function public.generar_alerta_desde_evento_denegado()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_codigo text;
  v_tipo_alerta text;
  v_nivel_riesgo text;
  -- Tipos que pueden nacer de una denegacion de acceso en el flujo CAC.
  -- (VEHICULO_PERMANENCIA_EXCEDIDA / VEHICULO_ABANDONADO no: esos los genera el job pg_cron.
  --  DISPOSITIVO_NO_RECONOCIDO tampoco: se resuelve antes de crear el evento, ver E11.2.)
  v_tipos_validos text[] := array[
    'BIOMETRIA_FALLIDA', 'PERSONA_NO_AUTORIZADA', 'MEMORANDO_VENCIDO',
    'FUERA_DE_HORARIO', 'PUNTO_SALIDA_INCORRECTO', 'VEHICULO_NO_AUTORIZADO',
    'PERSONA_DESCONOCIDA', 'GARITA_NO_AUTORIZADA', 'PLACA_NO_RECONOCIDA',
    'DOBLE_AUTENTICACION_FALLIDA'
  ];
begin
  if new.resultado <> 'DENEGADO' then
    return new;
  end if;

  -- Prefijo canonico antes del primer ':'. split_part devuelve el string completo si no hay
  -- ':', de modo que un motivo de texto libre no coincide con ningun codigo y cae al default.
  v_codigo := upper(trim(split_part(coalesce(new.motivo_resultado, ''), ':', 1)));

  if v_codigo = any(v_tipos_validos) then
    v_tipo_alerta := v_codigo;
  else
    v_tipo_alerta := 'PERSONA_NO_AUTORIZADA';
  end if;

  v_nivel_riesgo := case v_tipo_alerta
    -- Alguien no identificado o una placa que no existe en el sistema: es lo que un guardia
    -- tiene que mirar primero.
    when 'PERSONA_DESCONOCIDA' then 'ALTO'
    when 'PLACA_NO_RECONOCIDA' then 'ALTO'
    when 'VEHICULO_NO_AUTORIZADO' then 'ALTO'
    when 'DOBLE_AUTENTICACION_FALLIDA' then 'ALTO'
    -- Persona conocida a la que la configuracion no deja pasar: incidencia, no amenaza.
    when 'FUERA_DE_HORARIO' then 'BAJO'
    when 'GARITA_NO_AUTORIZADA' then 'BAJO'
    else 'MEDIO'
  end;

  insert into public.alerta_seguridad (id_evento, tipo_alerta, nivel_riesgo, estado_alerta)
  values (new.id_evento, v_tipo_alerta, v_nivel_riesgo, 'PENDIENTE');

  return new;
end;
$function$;
