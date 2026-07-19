-- Corrige un fallo de la migración anterior detectado al probar el turno nocturno.
--
-- `duracion_turno_min('22:00','06:00')` devolvía **-16 horas** en vez de 8. La causa: sumar un
-- intervalo de 24 h a un valor `time` no lo desplaza al día siguiente, lo envuelve — en aritmética
-- de `time`, 06:00 + 24 h vuelve a ser 06:00. Así que la resta daba 06:00 - 22:00 = -16 h.
--
-- El efecto no era cosmético: una duración negativa nunca supera el máximo, así que **cualquier
-- turno que cruzara medianoche se saltaba la validación de jornada**. Un turno de 22:00 a 21:00
-- (23 horas) se habría aceptado sin protestar.
--
-- Se calcula ahora sobre los minutos desde medianoche, igual que `tramos_turno`, sin aritmética
-- de intervalos sobre `time`.
create or replace function public.duracion_turno_min(p_inicio time, p_fin time)
returns int
language sql
immutable
set search_path = public
as $$
  select case
           when p_inicio is null or p_fin is null then null
           else ((extract(epoch from p_fin)::int / 60)
                 - (extract(epoch from p_inicio)::int / 60)
                 + 1440) % 1440
         end;
$$;

comment on function public.duracion_turno_min(time, time) is
  'Duración de un turno en minutos. El turno nocturno (22:00-06:00) mide 480, no -960. No usar aritmética de intervalos sobre time: envuelve a las 24 h.';
