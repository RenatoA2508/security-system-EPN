-- Restaura la versión original de normalizar_dispositivo, que la migración anterior había
-- reemplazado por error perdiendo dos comportamientos: el autoformato de la MAC (que reconstruye
-- "AABBCCDDEEFF" como "AA:BB:CC:DD:EE:FF") y el `set search_path`.
--
-- Revisado el caso: `dispositivo` no tiene ningún campo de texto libre más allá de MAC e IP, así
-- que el hueco de normalización que señalaba el traspaso de sesión no existe realmente aquí —
-- MAC e IP ya estaban cubiertas. No hacía falta tocar esta función.
create or replace function public.normalizar_dispositivo()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_hex text;
begin
  v_hex := upper(regexp_replace(coalesce(new.codigo_mac, ''), '[^0-9A-Fa-f]', '', 'g'));
  if length(v_hex) = 12 then
    new.codigo_mac := array_to_string(
      array(select substr(v_hex, g, 2) from generate_series(1, 12, 2) as g), ':');
  end if;
  new.direccion_ip := public.normalizar_espacios(new.direccion_ip);
  return new;
end;
$$;

revoke execute on function public.normalizar_dispositivo() from public, anon, authenticated;
