-- Hallazgo de esta ronda, no venía en el documento: la cuenta frank.jumbo tiene dos asignaciones
-- ACTIVAS solapadas —06:00–20:00 en la Garita del Subsuelo EARME y 14:00–20:00 en otra— con
-- fechas que también se pisan. Un guardia no puede estar en dos garitas a la vez, y con el turno
-- ya estructurado esto por fin se puede comprobar.
--
-- OJO: esta versión NO funciona. Usa `timerange`, que no existe en PostgreSQL (los rangos
-- integrados no cubren `time`). Se conserva porque ya está en el historial del remoto; la
-- corrección va en 20260719153018_..._v2.sql, que reemplaza la función por completo.
create or replace function public.validar_solapamiento_turno_guardia()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_choque record;
begin
  if new.estado_asignacion <> 'ACTIVA' or new.hora_inicio is null or new.hora_fin is null then
    return new;
  end if;

  if tg_op = 'UPDATE'
     and new.hora_inicio       is not distinct from old.hora_inicio
     and new.hora_fin          is not distinct from old.hora_fin
     and new.fecha_inicio      is not distinct from old.fecha_inicio
     and new.fecha_fin         is not distinct from old.fecha_fin
     and new.estado_asignacion is not distinct from old.estado_asignacion then
    return new;
  end if;

  select g.id_asignacion, g.turno, p.nombre_punto
    into v_choque
    from public.guardia_punto_control g
    join public.punto_control p on p.id_punto_control = g.id_punto_control
   where g.id_usuario = new.id_usuario
     and g.id_asignacion <> new.id_asignacion
     and g.estado_asignacion = 'ACTIVA'
     and g.hora_inicio is not null
     and g.fecha_inicio <= coalesce(new.fecha_fin, 'infinity'::timestamptz)
     and coalesce(g.fecha_fin, 'infinity'::timestamptz) >= new.fecha_inicio
     and exists (
       select 1
         from unnest(case when g.hora_inicio < g.hora_fin
                          then array[timerange(g.hora_inicio, g.hora_fin)]
                          else array[timerange(g.hora_inicio, '24:00'::time), timerange('00:00'::time, g.hora_fin)]
                     end) as existente(r)
         join unnest(case when new.hora_inicio < new.hora_fin
                          then array[timerange(new.hora_inicio, new.hora_fin)]
                          else array[timerange(new.hora_inicio, '24:00'::time), timerange('00:00'::time, new.hora_fin)]
                     end) as entrante(r) on existente.r && entrante.r
     )
   limit 1;

  if found then
    raise exception 'Ese guardia ya cubre el turno % en "%". Un guardia no puede estar en dos puntos de control a la vez.',
      v_choque.turno, v_choque.nombre_punto
      using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_validar_solapamiento_turno on public.guardia_punto_control;
create trigger trg_validar_solapamiento_turno
  before insert or update on public.guardia_punto_control
  for each row execute function public.validar_solapamiento_turno_guardia();
