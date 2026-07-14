-- Generacion automatica de alerta_seguridad a partir de un evento_acceso
-- DENEGADO (§D4: nadie crea alertas a mano, nacen de un trigger).
--
-- Clasificacion DETERMINISTA (resolucion de la duda E9): quien deniega el
-- acceso ya sabe por que. La convencion es que `motivo_resultado` empieza con
-- un codigo canonico (uno de los valores del catalogo tipo_alerta, §D16)
-- seguido de ": " y el detalle legible, p. ej.:
--   'BIOMETRIA_FALLIDA: confidence 0.40 < umbral 0.85'
-- El trigger toma el prefijo antes del primer ':' y, si es un tipo_alerta
-- valido para denegaciones, lo usa tal cual (sin adivinanzas). Si el motivo no
-- trae un codigo reconocible (p. ej. un guardia que registra un DENEGADO
-- manual con texto libre), cae al valor por defecto PERSONA_NO_AUTORIZADA.
-- La Edge Function registrar-evento-acceso emite siempre estos codigos.

create or replace function public.generar_alerta_desde_evento_denegado()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_codigo text;
  v_tipo_alerta text;
  v_nivel_riesgo text;
  -- tipos de alerta que pueden nacer de una denegacion de acceso en el flujo
  -- CAC. (VEHICULO_PERMANENCIA_EXCEDIDA / VEHICULO_ABANDONADO no: esos los
  -- genera el job pg_cron, no una denegacion. DISPOSITIVO_NO_RECONOCIDO
  -- tampoco: se resuelve antes de crear evento, ver E11.2.)
  v_tipos_validos text[] := array[
    'BIOMETRIA_FALLIDA', 'PERSONA_NO_AUTORIZADA', 'MEMORANDO_VENCIDO',
    'FUERA_DE_HORARIO', 'PUNTO_SALIDA_INCORRECTO', 'VEHICULO_NO_AUTORIZADO'
  ];
begin
  if new.resultado <> 'DENEGADO' then
    return new;
  end if;

  -- Prefijo canonico antes del primer ':'. split_part devuelve el string
  -- completo si no hay ':', de modo que un motivo de texto libre no coincide
  -- con ningun codigo y cae al default.
  v_codigo := upper(trim(split_part(coalesce(new.motivo_resultado, ''), ':', 1)));

  if v_codigo = any(v_tipos_validos) then
    v_tipo_alerta := v_codigo;
  else
    v_tipo_alerta := 'PERSONA_NO_AUTORIZADA';
  end if;

  v_nivel_riesgo := case v_tipo_alerta
    when 'VEHICULO_NO_AUTORIZADO' then 'ALTO'
    else 'MEDIO'
  end;

  insert into public.alerta_seguridad (id_evento, tipo_alerta, nivel_riesgo, estado_alerta)
  values (new.id_evento, v_tipo_alerta, v_nivel_riesgo, 'PENDIENTE');

  return new;
end;
$$;

create trigger trg_generar_alerta_evento_denegado
after insert on public.evento_acceso
for each row execute function public.generar_alerta_desde_evento_denegado();
