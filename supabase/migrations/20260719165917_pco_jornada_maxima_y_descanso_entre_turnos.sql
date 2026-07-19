-- "Todo tiene que funcionar como en la vida real": hasta ahora nada impedía registrar un turno
-- de catorce horas seguidas, ni encadenar dos turnos sin descanso entre ellos. Los dos datos
-- sembrados lo demostraban (14 h y 10 h).
--
-- Referencia: Código del Trabajo del Ecuador — jornada ordinaria de 8 h diarias y 40 semanales
-- (art. 47), ampliable con horas extra hasta un máximo de 12 h al día (art. 55). El descanso
-- entre jornadas se fija aquí en 12 h, que es el criterio habitual en vigilancia.
--
-- Los dos límites viven en parametro_sistema, no en el código: son política laboral y pueden
-- cambiar sin tocar una migración.
insert into public.parametro_sistema
  (codigo_parametro, nombre_parametro, descripcion, modulo_aplicacion, tipo_dato, valor_parametro, estado_parametro, editable)
values
  ('JORNADA_MAXIMA_GUARDIA_HORAS', 'Jornada máxima del guardia',
   'Horas máximas que puede durar un turno, o la suma de turnos de un mismo día (art. 55: 8 ordinarias + 4 extra).',
   'SEGURIDAD', 'ENTERO', '12', 'ACTIVO', true),
  ('DESCANSO_MINIMO_GUARDIA_HORAS', 'Descanso mínimo entre jornadas',
   'Horas de descanso continuo que debe tener un guardia entre el final de su jornada y el inicio de la siguiente.',
   'SEGURIDAD', 'ENTERO', '12', 'ACTIVO', true)
on conflict (codigo_parametro) do nothing;

/* Duración de un turno en minutos, contemplando el cruce de medianoche.
   OJO: esta primera versión está MAL (devuelve -960 para el turno nocturno). Se corrige en
   20260719170008; se conserva aquí porque ya está en el historial del remoto. */
create or replace function public.duracion_turno_min(p_inicio time, p_fin time)
returns int
language sql
immutable
set search_path = public
as $$
  select case
           when p_inicio is null or p_fin is null then null
           when p_fin > p_inicio then (extract(epoch from (p_fin - p_inicio)) / 60)::int
           else (extract(epoch from ((p_fin + interval '24 hour') - p_inicio)) / 60)::int
         end;
$$;

create or replace function public.validar_jornada_guardia()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_max_min      int;
  v_descanso_min int;
  v_dur          int;
  v_ventana      int;
  v_hay_nocturno boolean;
begin
  if new.estado_asignacion <> 'ACTIVA' or new.hora_inicio is null or new.hora_fin is null then
    return new;
  end if;

  -- Igual que en el resto de reglas de esta ronda: no revalidar ediciones que no tocan el turno,
  -- la vigencia ni el estado, para no congelar las filas anteriores a la regla.
  if tg_op = 'UPDATE'
     and new.hora_inicio       is not distinct from old.hora_inicio
     and new.hora_fin          is not distinct from old.hora_fin
     and new.fecha_inicio      is not distinct from old.fecha_inicio
     and new.fecha_fin         is not distinct from old.fecha_fin
     and new.estado_asignacion is not distinct from old.estado_asignacion then
    return new;
  end if;

  select coalesce(max(valor_parametro::int), 12) * 60 into v_max_min
    from public.parametro_sistema where codigo_parametro = 'JORNADA_MAXIMA_GUARDIA_HORAS';
  select coalesce(max(valor_parametro::int), 12) * 60 into v_descanso_min
    from public.parametro_sistema where codigo_parametro = 'DESCANSO_MINIMO_GUARDIA_HORAS';

  -- 1. Ningún turno suelto puede pasar de la jornada máxima.
  v_dur := public.duracion_turno_min(new.hora_inicio, new.hora_fin);
  if v_dur > v_max_min then
    raise exception 'Un turno no puede durar % horas: el máximo es % (jornada ordinaria más horas extra).',
      round(v_dur / 60.0, 1), v_max_min / 60
      using errcode = 'check_violation';
  end if;

  -- 2. Si el guardia tiene además otras asignaciones vigentes esos mismos días, trabaja todos
  --    esos turnos cada día. Lo que debe respetarse entonces es la ventana que ocupan de punta a
  --    punta: lo que sobra hasta las 24 h es su descanso continuo entre jornadas.
  --
  --    Con algún turno que cruza medianoche esa ventana no está bien definida (la jornada pisa
  --    dos días naturales), así que ahí se aplica solo la regla 1 y el solapamiento. Anotado en
  --    §V30: si aparecen turnos nocturnos combinados con otros, hay que modelar el día laboral.
  select bool_or(g.hora_fin <= g.hora_inicio) or (new.hora_fin <= new.hora_inicio)
    into v_hay_nocturno
    from public.guardia_punto_control g
   where g.id_usuario = new.id_usuario
     and g.id_asignacion is distinct from new.id_asignacion
     and g.estado_asignacion = 'ACTIVA'
     and g.hora_inicio is not null and g.hora_fin is not null
     and g.fecha_inicio <= coalesce(new.fecha_fin, 'infinity'::timestamptz)
     and coalesce(g.fecha_fin, 'infinity'::timestamptz) >= new.fecha_inicio;

  if coalesce(v_hay_nocturno, true) then
    return new;
  end if;

  select (extract(epoch from (max(f) - min(i))) / 60)::int
    into v_ventana
    from (
      select new.hora_inicio as i, new.hora_fin as f
      union all
      select g.hora_inicio, g.hora_fin
        from public.guardia_punto_control g
       where g.id_usuario = new.id_usuario
         and g.id_asignacion is distinct from new.id_asignacion
         and g.estado_asignacion = 'ACTIVA'
         and g.hora_inicio is not null and g.hora_fin is not null
         and g.fecha_inicio <= coalesce(new.fecha_fin, 'infinity'::timestamptz)
         and coalesce(g.fecha_fin, 'infinity'::timestamptz) >= new.fecha_inicio
    ) t;

  if v_ventana is not null and (1440 - v_ventana) < v_descanso_min then
    raise exception 'Con ese turno, al guardia solo le quedarían % horas de descanso entre jornadas; el mínimo es %.',
      round((1440 - v_ventana) / 60.0, 1), v_descanso_min / 60
      using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_validar_jornada_guardia on public.guardia_punto_control;
create trigger trg_validar_jornada_guardia
  before insert or update on public.guardia_punto_control
  for each row execute function public.validar_jornada_guardia();

revoke execute on function public.validar_jornada_guardia() from public, anon, authenticated;
revoke execute on function public.duracion_turno_min(time, time) from public, anon;
grant  execute on function public.duracion_turno_min(time, time) to authenticated;
