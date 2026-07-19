-- PCO §"cuando aparezca el combo Zona padre, no tiene sentido que aparezcan todas las zonas
-- registradas, solamente las que realmente son padres. La jerarquía va de esta manera:
-- Campus -> Edificio -> Parqueadero".
--
-- El trigger anterior exigía que el padre de CUALQUIER zona fuese un CAMPUS, así que dejaba
-- colgar un parqueadero directamente del campus. Ahora cada tipo tiene un único padre válido:
--   CAMPUS      -> sin padre (es la raíz)
--   EDIFICIO    -> CAMPUS
--   PARQUEADERO -> EDIFICIO
--
-- Dato heredado: "Parqueadero Subsuelo EARME" cuelga hoy del campus y no existe un edificio
-- EARME sembrado al que reasignarlo. En vez de inventar el edificio o de romper la fila, la
-- regla nueva se exige al insertar y al cambiar el vínculo, pero no al editar el nombre o el
-- estado de una zona que ya existía así. Queda anotado en 99_DUDAS_PARA_EL_EQUIPO.md (§V22).
create or replace function public.validar_jerarquia_zona()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tipo_padre  text;
  v_tipo_espera text;
begin
  -- Al editar una zona sin tocar su tipo ni su padre no se revalida la jerarquía: si no, las
  -- filas anteriores a esta regla quedarían congeladas y no se les podría ni corregir el nombre.
  if tg_op = 'UPDATE'
     and new.id_zona_padre is not distinct from old.id_zona_padre
     and new.tipo_zona is not distinct from old.tipo_zona then
    return new;
  end if;

  v_tipo_espera := case new.tipo_zona
                     when 'EDIFICIO'    then 'CAMPUS'
                     when 'PARQUEADERO' then 'EDIFICIO'
                   end;

  if new.tipo_zona = 'CAMPUS' then
    if new.id_zona_padre is not null then
      raise exception 'Un campus es la zona raíz: no puede depender de otra zona.'
        using errcode = 'check_violation';
    end if;
    return new;
  end if;

  if new.id_zona_padre is null then
    raise exception 'Una zona de tipo % debe depender de una zona de tipo %.', new.tipo_zona, v_tipo_espera
      using errcode = 'check_violation';
  end if;

  select z.tipo_zona into v_tipo_padre from public.zona z where z.id_zona = new.id_zona_padre;

  if v_tipo_padre is distinct from v_tipo_espera then
    raise exception 'La zona padre de un % debe ser de tipo %, no %.',
      new.tipo_zona, v_tipo_espera, coalesce(v_tipo_padre, 'inexistente')
      using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

comment on function public.validar_jerarquia_zona() is
  'Impone la jerarquía CAMPUS -> EDIFICIO -> PARQUEADERO. No revalida ediciones que no tocan el tipo ni el padre, para no bloquear filas anteriores a la regla.';
