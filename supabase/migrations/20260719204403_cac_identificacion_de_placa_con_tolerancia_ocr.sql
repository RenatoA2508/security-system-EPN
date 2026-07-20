-- CAC RF-CA-015 / RF-CA-018: resolver la placa LEIDA por la camara contra los vehiculos
-- registrados, y decidir si esa placa autoriza a la persona que la conduce.
--
-- El problema real de un OCR sobre una placa metalica: no falla al azar, falla de forma
-- sistematica confundiendo caracteres que se parecen (O/0, I/1, S/5, B/8, Z/2, G/6). Una
-- comparacion exacta rechaza "PDF1Z34" cuando la placa es "PDF1234", y el guardia acaba
-- tecleando todo a mano — que es justo lo que el requisito quiere evitar.
--
-- Dos correcciones, en este orden:
--
--  1. CORRECCION POSICIONAL (`corregir_placa_ocr`). La placa ecuatoriana tiene forma fija:
--     tres letras y luego tres o cuatro digitos. Un digito leido en las tres primeras
--     posiciones es necesariamente un error de OCR, y una letra leida en la parte numerica
--     tambien. Se corrige por posicion, sin ambiguedad y sin mirar la base de datos.
--     Resuelve la mayoria de las lecturas sucias y no puede convertir una placa en otra
--     placa valida distinta, porque solo toca caracteres que estaban en la clase equivocada.
--
--  2. TOLERANCIA DIFUSA (`identificar_placa`). Lo que quede sin resolver se compara con
--     levenshtein contra las placas registradas. Aqui si se puede confundir un vehiculo con
--     otro, asi que la tolerancia solo se aplica cuando UNA sola placa registrada queda a esa
--     distancia: si hay dos candidatas, la funcion devuelve ambigua = true y no elige. Elegir
--     "la mas parecida" entre dos seria autorizar a un vehiculo por parecido, que es
--     exactamente lo que RF-CA-015 prohibe.

create extension if not exists fuzzystrmatch with schema extensions;

-- ---------------------------------------------------------------------------
-- 1. Correccion posicional de la lectura
-- ---------------------------------------------------------------------------
create or replace function public.corregir_placa_ocr(p_placa text)
returns text
language plpgsql
immutable
set search_path to 'public'
as $$
declare
  v_placa text;
  v_salida text := '';
  v_ch text;
  i int;
begin
  v_placa := public.normalizar_placa(coalesce(p_placa, ''));

  -- Solo se corrige lo que ya tiene la longitud de una placa ordinaria (6 o 7). Fuera de eso
  -- la lectura esta demasiado rota como para arreglarla adivinando.
  if length(v_placa) not in (6, 7) then
    return v_placa;
  end if;

  for i in 1..length(v_placa) loop
    v_ch := substr(v_placa, i, 1);

    if i <= 3 then
      -- Zona de letras: un digito aqui es un error de lectura.
      v_ch := case v_ch
        when '0' then 'O' when '1' then 'I' when '2' then 'Z' when '5' then 'S'
        when '6' then 'G' when '8' then 'B' else v_ch end;
    else
      -- Zona de digitos: una letra aqui es un error de lectura.
      v_ch := case v_ch
        when 'O' then '0' when 'Q' then '0' when 'D' then '0'
        when 'I' then '1' when 'L' then '1'
        when 'Z' then '2' when 'S' then '5' when 'G' then '6' when 'B' then '8'
        else v_ch end;
    end if;

    v_salida := v_salida || v_ch;
  end loop;

  return v_salida;
end;
$$;

comment on function public.corregir_placa_ocr(text) is
  'Corrige confusiones de OCR por posicion segun la forma de la placa ecuatoriana (3 letras + 3/4 digitos). No consulta la base: es una normalizacion pura.';

-- ---------------------------------------------------------------------------
-- 2. Identificacion contra los vehiculos registrados
-- ---------------------------------------------------------------------------
create or replace function public.identificar_placa(p_placa_leida text)
returns table (
  id_vehiculo uuid,
  placa varchar,
  estado_vehiculo text,
  distancia int,
  corregida boolean,
  ambigua boolean
)
language plpgsql
stable
security definer
set search_path to 'public', 'extensions'
as $$
declare
  v_cruda text;
  v_corregida text;
  v_tolerancia int;
  v_candidatas int;
begin
  v_cruda := public.normalizar_placa(coalesce(p_placa_leida, ''));
  if v_cruda = '' then
    return;
  end if;

  v_corregida := public.corregir_placa_ocr(v_cruda);

  -- (a) Coincidencia exacta con la lectura tal cual.
  return query
    select v.id_vehiculo, v.placa, v.estado_vehiculo, 0, false, false
      from public.vehiculo v
     where v.placa = v_cruda
     limit 1;
  if found then return; end if;

  -- (b) Coincidencia exacta tras la correccion posicional.
  if v_corregida <> v_cruda then
    return query
      select v.id_vehiculo, v.placa, v.estado_vehiculo, 0, true, false
        from public.vehiculo v
       where v.placa = v_corregida
       limit 1;
    if found then return; end if;
  end if;

  -- (c) Tolerancia difusa, solo si no hay empate.
  select coalesce(max(ps.valor_parametro::int), 1) into v_tolerancia
    from public.parametro_sistema ps
   where ps.codigo_parametro = 'TOLERANCIA_PLACA_CARACTERES'
     and ps.estado_parametro = 'ACTIVO';

  if v_tolerancia <= 0 then
    return;
  end if;

  select count(*) into v_candidatas
    from public.vehiculo v
   where v.placa is not null
     and v.estado_vehiculo <> 'DADO_DE_BAJA'
     and extensions.levenshtein(v.placa::text, v_corregida) <= v_tolerancia;

  if v_candidatas = 0 then
    return;
  end if;

  if v_candidatas > 1 then
    -- Dos placas registradas igual de parecidas a la lectura. No se elige ninguna: se avisa
    -- al guardia para que lea la placa con sus ojos.
    return query select null::uuid, null::varchar, null::text, null::int, true, true;
    return;
  end if;

  return query
    select v.id_vehiculo, v.placa, v.estado_vehiculo,
           extensions.levenshtein(v.placa::text, v_corregida), true, false
      from public.vehiculo v
     where v.placa is not null
       and v.estado_vehiculo <> 'DADO_DE_BAJA'
       and extensions.levenshtein(v.placa::text, v_corregida) <= v_tolerancia
     limit 1;
end;
$$;

comment on function public.identificar_placa(text) is
  'RF-CA-015: resuelve una placa leida por OCR a un vehiculo registrado. Devuelve ambigua = true si mas de una placa queda dentro de la tolerancia, en cuyo caso no elige ninguna.';

revoke all on function public.identificar_placa(text) from public;
grant execute on function public.identificar_placa(text) to authenticated, service_role;
revoke all on function public.corregir_placa_ocr(text) from public;
grant execute on function public.corregir_placa_ocr(text) to authenticated, service_role;
