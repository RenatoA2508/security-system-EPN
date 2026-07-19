-- PCO §"Hay que asignar un guardia de los que están creados y estos únicamente podrán entrar a
-- su usuario durante su turno."
--
-- Para poder responder "¿este guardia está en turno ahora?" hacía falta dejar de guardar el
-- turno como texto libre (§V10). La columna `turno` contenía tanto "07:00–17:00" como
-- "MATUTINO": imposible de comparar contra un reloj. Ahora las horas son la fuente de verdad y
-- `turno` pasa a ser el texto derivado de ellas, para no romper a quien ya lo lee.

alter table public.guardia_punto_control
  add column if not exists hora_inicio time,
  add column if not exists hora_fin    time;

-- Migración de los textos existentes. Acepta el guion largo (–) y el corto (-), que es lo que
-- hay sembrado. Lo que no encaje (p. ej. "MATUTINO") queda en null y se corrige a mano.
update public.guardia_punto_control
   set hora_inicio = substring(turno from '^\s*(\d{1,2}:\d{2})')::time,
       hora_fin    = substring(turno from '[–-]\s*(\d{1,2}:\d{2})\s*$')::time
 where turno ~ '^\s*\d{1,2}:\d{2}\s*[–-]\s*\d{1,2}:\d{2}\s*$'
   and (hora_inicio is null or hora_fin is null);

-- Un turno de 00:00 a 00:00 no significa nada; y un turno abierto por un extremo tampoco.
alter table public.guardia_punto_control drop constraint if exists gpc_turno_completo;
alter table public.guardia_punto_control add constraint gpc_turno_completo
  check ((hora_inicio is null) = (hora_fin is null) and (hora_inicio is distinct from hora_fin))
  not valid;

/* ¿Cae `p_momento` dentro del turno? Soporta el turno nocturno que cruza medianoche
   (22:00–06:00), donde hora_fin < hora_inicio y el intervalo son dos tramos. */
create or replace function public.esta_en_turno(p_inicio time, p_fin time, p_momento time)
returns boolean
language sql
immutable
as $$
  select case
           when p_inicio is null or p_fin is null then null
           when p_inicio < p_fin then p_momento >= p_inicio and p_momento < p_fin
           else p_momento >= p_inicio or p_momento < p_fin   -- cruza medianoche
         end;
$$;

comment on function public.esta_en_turno(time, time, time) is
  'Cierto si el momento cae dentro del turno. Contempla el turno nocturno que cruza medianoche.';

/* Hora actual en Ecuador. Mismo motivo que hoy_ecuador() (§D52): el servidor va en UTC y
   Ecuador cinco horas por detrás, así que a las 19:00 de aquí allí son las 14:00. Comparar el
   turno contra un reloj en UTC daría "fuera de turno" a un guardia que sí está trabajando. */
create or replace function public.hora_ecuador()
returns time
language sql
stable
as $$
  select (now() at time zone 'America/Guayaquil')::time;
$$;

comment on function public.hora_ecuador() is
  'Hora local de Ecuador. Nunca comparar turnos contra now()::time, que va en UTC.';

/* Mantiene el texto `turno` derivado de las horas, para que no puedan discrepar. */
create or replace function public.sincronizar_texto_turno()
returns trigger
language plpgsql
as $$
begin
  if new.hora_inicio is not null and new.hora_fin is not null then
    new.turno := to_char(new.hora_inicio, 'HH24:MI') || '–' || to_char(new.hora_fin, 'HH24:MI');
  end if;
  return new;
end;
$$;

drop trigger if exists trg_sincronizar_texto_turno on public.guardia_punto_control;
create trigger trg_sincronizar_texto_turno
  before insert or update on public.guardia_punto_control
  for each row execute function public.sincronizar_texto_turno();
