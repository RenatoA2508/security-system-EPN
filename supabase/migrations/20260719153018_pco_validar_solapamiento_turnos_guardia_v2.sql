-- Corrige la versión anterior: usaba `timerange`, que no existe en PostgreSQL (los rangos
-- integrados no cubren `time`). Se compara en minutos desde medianoche, que además hace
-- explícito el desdoble del turno nocturno.

/* Tramos que ocupa un turno dentro de un día, en minutos desde medianoche. Un turno normal da
   un tramo; uno que cruza medianoche (22:00–06:00) da dos: [1320,1440) y [0,360). */
create or replace function public.tramos_turno(p_inicio time, p_fin time)
returns table(desde int, hasta int)
language sql
immutable
as $$
  with m as (
    select extract(epoch from p_inicio)::int / 60 as ini,
           extract(epoch from p_fin)::int     / 60 as fin
  )
  select ini, fin  from m where ini < fin
  union all
  select ini, 1440 from m where ini > fin
  union all
  select 0,   fin  from m where ini > fin and fin > 0;
$$;

comment on function public.tramos_turno(time, time) is
  'Tramos que ocupa un turno en minutos desde medianoche. El turno nocturno devuelve dos filas.';

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
     and g.id_asignacion is distinct from new.id_asignacion
     and g.estado_asignacion = 'ACTIVA'
     and g.hora_inicio is not null
     and g.hora_fin is not null
     -- las vigencias en días se pisan
     and g.fecha_inicio <= coalesce(new.fecha_fin, 'infinity'::timestamptz)
     and coalesce(g.fecha_fin, 'infinity'::timestamptz) >= new.fecha_inicio
     -- y algún tramo horario del turno existente se pisa con alguno del entrante
     and exists (
       select 1
         from public.tramos_turno(g.hora_inicio,   g.hora_fin)   ex
         join public.tramos_turno(new.hora_inicio, new.hora_fin) en
           on ex.desde < en.hasta and en.desde < ex.hasta
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
