-- PCO RF §"Validación de Formato de Ubicación": E[edificio]/P[piso]/E[espacio de tres dígitos],
-- por ejemplo E20/P3/E004.
--
-- De momento solo la función, sin columna: ninguna entidad de PCO tiene hoy un campo de
-- ubicación y decidir en cuál va es del equipo (§V24). Queda lista para engancharla como CHECK
-- en cuanto se decida, con el espejo en web/src/lib/validacion.ts.
create or replace function public.es_ubicacion_epn(p_texto text)
returns boolean
language sql
immutable
as $$
  select p_texto ~ '^E[1-9][0-9]{0,2}/P[0-9]{1,2}/E[0-9]{3}$';
$$;

comment on function public.es_ubicacion_epn(text) is
  'Nomenclatura oficial de espacios de la EPN: E<edificio>/P<piso>/E<espacio de 3 dígitos>, p. ej. E20/P3/E004.';

/* Normaliza una ubicación tecleada: mayúsculas, sin espacios y con el espacio rellenado a tres
   dígitos, para que "e20 / p3 / e4" acabe siendo "E20/P3/E004" en vez de un error. */
create or replace function public.normalizar_ubicacion_epn(p_texto text)
returns text
language plpgsql
immutable
as $$
declare
  v text;
  v_partes text[];
begin
  if p_texto is null then return null; end if;
  v := upper(regexp_replace(p_texto, '\s', '', 'g'));
  v_partes := regexp_match(v, '^E([0-9]+)/P([0-9]+)/E([0-9]+)$');
  if v_partes is null then return v; end if;
  return 'E' || ltrim(v_partes[1], '0') || '/P' || ltrim(v_partes[2], '0')
      || '/E' || lpad(ltrim(v_partes[3], '0'), 3, '0');
end;
$$;

comment on function public.normalizar_ubicacion_epn(text) is
  'Lleva una ubicación tecleada a la forma canónica E20/P3/E004 antes de validarla.';

-- ATENCIÓN: esta migración incluía además una reescritura de `normalizar_dispositivo()` que
-- resultó ser una regresión — perdía el autoformato de la MAC ("AABBCCDDEEFF" ->
-- "AA:BB:CC:DD:EE:FF") y el `set search_path`. Se revierte en la migración siguiente
-- (20260719153134). Aquí ya no se toca esa función.
