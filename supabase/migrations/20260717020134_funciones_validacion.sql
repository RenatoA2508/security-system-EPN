-- Funciones de validacion y normalizacion de datos de entrada.
-- Se aplican como CHECK en 20260716010200_constraints_validacion.sql y se
-- replican en el frontend (web/src/lib/validacion.ts) para que el error se vea
-- antes de enviar. La BD es la ultima linea de defensa: la API REST de Supabase
-- esta expuesta y cualquier cliente con un token valido podria insertar sin
-- pasar nunca por el formulario.
--
-- Todas son IMMUTABLE y sin acceso a tablas: se pueden usar dentro de un CHECK.

-- ---------------------------------------------------------------------------
-- 1. Cedula ecuatoriana
-- ---------------------------------------------------------------------------
-- Algoritmo del Registro Civil:
--   a) 10 digitos exactos.
--   b) Los dos primeros son el codigo de provincia: 01..24, o 30 para los
--      documentos emitidos en el exterior (extranjeros residentes).
--   c) El tercer digito es < 6 para personas naturales (6 = sector publico,
--      9 = persona juridica; ninguno de los dos es cedula de una persona).
--   d) Digito verificador (el decimo) por modulo 10: los 9 primeros digitos se
--      multiplican por los coeficientes 2,1,2,1,2,1,2,1,2; a todo producto > 9
--      se le resta 9; se suman; el verificador es (10 - suma % 10) % 10.
create or replace function public.es_cedula_ecuatoriana(p_cedula text)
returns boolean
language plpgsql
immutable
set search_path = public
as $$
declare
  v_provincia integer;
  v_suma integer := 0;
  v_producto integer;
  i integer;
begin
  -- La obligatoriedad la decide NOT NULL, no esta funcion.
  if p_cedula is null then
    return true;
  end if;

  if p_cedula !~ '^[0-9]{10}$' then
    return false;
  end if;

  v_provincia := substr(p_cedula, 1, 2)::integer;
  if not (v_provincia between 1 and 24) and v_provincia <> 30 then
    return false;
  end if;

  if substr(p_cedula, 3, 1)::integer >= 6 then
    return false;
  end if;

  for i in 1..9 loop
    v_producto := substr(p_cedula, i, 1)::integer * (case when i % 2 = 1 then 2 else 1 end);
    if v_producto > 9 then
      v_producto := v_producto - 9;
    end if;
    v_suma := v_suma + v_producto;
  end loop;

  return ((10 - (v_suma % 10)) % 10) = substr(p_cedula, 10, 1)::integer;
end;
$$;

comment on function public.es_cedula_ecuatoriana(text) is
  'Cedula ecuatoriana: 10 digitos, provincia 01-24/30, tercer digito < 6 y digito verificador modulo 10.';

-- ---------------------------------------------------------------------------
-- 2. RUC ecuatoriano
-- ---------------------------------------------------------------------------
-- 13 digitos. El tercer digito define el tipo de contribuyente y con el cambia
-- tanto el algoritmo del verificador como la posicion en que vive:
--   < 6 : persona natural  -> los 10 primeros son una cedula valida (modulo 10),
--                             seguidos del establecimiento (001, 002, ...).
--   = 6 : sector publico   -> verificador en la posicion 9, modulo 11 con
--                             coeficientes 3,2,7,6,5,4,3,2; establecimiento de
--                             4 digitos (0001...).
--   = 9 : sociedad privada -> verificador en la posicion 10, modulo 11 con
--                             coeficientes 4,3,2,7,6,5,4,3,2; establecimiento 001.
-- En modulo 11 un residuo 0 da verificador 0; un verificador que diera 10 hace
-- invalido al RUC (no existe un digito 10).
create or replace function public.es_ruc_ecuatoriano(p_ruc text)
returns boolean
language plpgsql
immutable
set search_path = public
as $$
declare
  v_provincia integer;
  v_tercero integer;
  v_suma integer := 0;
  v_producto integer;
  v_dv integer;
  v_coef integer[];
  i integer;
begin
  if p_ruc is null then
    return true;
  end if;

  if p_ruc !~ '^[0-9]{13}$' then
    return false;
  end if;

  v_provincia := substr(p_ruc, 1, 2)::integer;
  if not (v_provincia between 1 and 24) and v_provincia <> 30 then
    return false;
  end if;

  v_tercero := substr(p_ruc, 3, 1)::integer;

  -- Persona natural: cedula valida + numero de establecimiento.
  if v_tercero < 6 then
    return public.es_cedula_ecuatoriana(substr(p_ruc, 1, 10))
       and substr(p_ruc, 11, 3) ~ '^[0-9]{3}$'
       and substr(p_ruc, 11, 3)::integer >= 1;

  -- Sector publico.
  elsif v_tercero = 6 then
    v_coef := array[3, 2, 7, 6, 5, 4, 3, 2];
    for i in 1..8 loop
      v_suma := v_suma + (substr(p_ruc, i, 1)::integer * v_coef[i]);
    end loop;
    v_dv := v_suma % 11;
    v_dv := case when v_dv = 0 then 0 else 11 - v_dv end;
    if v_dv = 10 then
      return false;
    end if;
    return v_dv = substr(p_ruc, 9, 1)::integer
       and substr(p_ruc, 10, 4) ~ '^[0-9]{4}$'
       and substr(p_ruc, 10, 4)::integer >= 1;

  -- Sociedad privada / extranjera sin cedula.
  elsif v_tercero = 9 then
    v_coef := array[4, 3, 2, 7, 6, 5, 4, 3, 2];
    for i in 1..9 loop
      v_suma := v_suma + (substr(p_ruc, i, 1)::integer * v_coef[i]);
    end loop;
    v_dv := v_suma % 11;
    v_dv := case when v_dv = 0 then 0 else 11 - v_dv end;
    if v_dv = 10 then
      return false;
    end if;
    return v_dv = substr(p_ruc, 10, 1)::integer
       and substr(p_ruc, 11, 3) ~ '^[0-9]{3}$'
       and substr(p_ruc, 11, 3)::integer >= 1;
  end if;

  -- 7 y 8 no son tipos de contribuyente asignados.
  return false;
end;
$$;

comment on function public.es_ruc_ecuatoriano(text) is
  'RUC ecuatoriano: 13 digitos; verificador modulo 10 (natural), modulo 11 (publico y sociedad) segun el tercer digito.';

-- ---------------------------------------------------------------------------
-- 3. Telefono ecuatoriano (E.164)
-- ---------------------------------------------------------------------------
-- Normaliza a +593XXXXXXXXX descartando espacios, guiones y parentesis:
--   0987654321       -> +593987654321  (celular; se cae el 0 troncal)
--   022345678        -> +59322345678   (fijo de Quito)
--   593987654321     -> +593987654321
--   +593 98 765 4321 -> +593987654321
-- Si no reconoce el patron devuelve la entrada intacta, para que el CHECK falle
-- con un error visible en vez de guardar un numero corrupto en silencio.
create or replace function public.normalizar_telefono_ec(p_telefono text)
returns text
language plpgsql
immutable
set search_path = public
as $$
declare
  v text;
begin
  if p_telefono is null or btrim(p_telefono) = '' then
    return null;
  end if;

  v := regexp_replace(p_telefono, '[^0-9+]', '', 'g');
  v := regexp_replace(v, '(.)\++', '\1', 'g'); -- el "+" solo vale al inicio

  if v ~ '^\+593[0-9]{8,9}$' then
    return v;
  elsif v ~ '^593[0-9]{8,9}$' then
    return '+' || v;
  elsif v ~ '^0[0-9]{8,9}$' then
    return '+593' || substr(v, 2);
  elsif v ~ '^9[0-9]{8}$' then
    return '+593' || v;  -- celular sin 0 troncal
  elsif v ~ '^[2-7][0-9]{7}$' then
    return '+593' || v;  -- fijo sin 0 troncal
  end if;

  return p_telefono;
end;
$$;

comment on function public.normalizar_telefono_ec(text) is
  'Normaliza un telefono ecuatoriano a E.164 (+593...). Devuelve la entrada intacta si no reconoce el patron.';

-- Valida el telefono ya normalizado:
--   celular: +593 9XXXXXXXX   (9 digitos, empieza en 9)
--   fijo:    +593 [2-7]XXXXXXX (8 digitos, codigo de provincia 2..7)
create or replace function public.es_telefono_ec(p_telefono text)
returns boolean
language sql
immutable
set search_path = public
as $$
  select p_telefono is null
      or p_telefono ~ '^\+5939[0-9]{8}$'
      or p_telefono ~ '^\+593[2-7][0-9]{7}$';
$$;

comment on function public.es_telefono_ec(text) is
  'Telefono ecuatoriano en E.164: celular +5939XXXXXXXX o fijo +593[2-7]XXXXXXX.';

-- ---------------------------------------------------------------------------
-- 4. Correo electronico
-- ---------------------------------------------------------------------------
-- Patron deliberadamente conservador (no pretende cubrir el RFC 5322): exige
-- usuario@dominio.tld sin espacios y con TLD de al menos 2 letras. Atrapa el
-- error de digitacion real sin rechazar direcciones legitimas.
create or replace function public.es_correo(p_correo text)
returns boolean
language sql
immutable
set search_path = public
as $$
  select p_correo is null
      or p_correo ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$';
$$;

comment on function public.es_correo(text) is
  'Formato de correo electronico: usuario@dominio.tld.';

-- Correo institucional de la EPN. Acepta epn.edu.ec, cualquier subdominio
-- (ej. fis.epn.edu.ec) y cec.edu.ec: el Centro de Educacion Continua es parte
-- de la EPN y su personal se registra como INTERNA (hay una fila asi en el
-- proyecto remoto: hernan.avellaneda@cec.edu.ec).
create or replace function public.es_correo_institucional_epn(p_correo text)
returns boolean
language sql
immutable
set search_path = public
as $$
  select p_correo is null
      or (public.es_correo(p_correo)
          and lower(p_correo) ~ '@([a-z0-9-]+\.)*(epn|cec)\.edu\.ec$');
$$;

comment on function public.es_correo_institucional_epn(text) is
  'Correo institucional EPN: dominio epn.edu.ec (con o sin subdominio) o cec.edu.ec.';

-- ---------------------------------------------------------------------------
-- 5. Placa vehicular ecuatoriana
-- ---------------------------------------------------------------------------
-- Formato oficial de la ANT: 3 letras + 3 o 4 digitos (ABC-123 / ABC-1234).
--   1a letra: provincia de matriculacion (las 24 asignadas; D y F no se usan).
--   2a letra: tipo de servicio. NO se valida a proposito: es E en los vehiculos
--             del gobierno central y M en los de un GAD, y la EPN es una
--             universidad publica -> sus vehiculos institucionales llevan placa
--             estatal. Restringirla bloquearia a la propia Politecnica.
--   3a letra: correlativa que asigna el sistema.
-- Quedan fuera las diplomaticas (CC/CD/OI/AT/IT), que usan otro formato.
--
-- Canonico SIN guion (ABC1234): es la clave con la que el OCR de placas
-- comparara contra la BD. Normalizando ambos lados a la misma forma, el match
-- es una igualdad exacta y no depende de si la camara distinguio el guion.
create or replace function public.normalizar_placa(p_placa text)
returns text
language sql
immutable
set search_path = public
as $$
  select case
    when p_placa is null or btrim(p_placa) = '' then null
    else upper(regexp_replace(p_placa, '[^A-Za-z0-9]', '', 'g'))
  end;
$$;

comment on function public.normalizar_placa(text) is
  'Forma canonica de una placa: mayusculas, sin guiones ni espacios (ABC1234). Es la clave de comparacion del OCR.';

create or replace function public.es_placa_ec(p_placa text)
returns boolean
language sql
immutable
set search_path = public
as $$
  select p_placa is null
      or public.normalizar_placa(p_placa) ~ '^[ABUCXHOEWGILRMVNQSPKTZYJ][A-Z]{2}[0-9]{3,4}$';
$$;

comment on function public.es_placa_ec(text) is
  'Placa ecuatoriana: 3 letras + 3 o 4 digitos; la primera letra es una de las 24 provincias. La segunda (tipo de servicio) no se restringe: E/M son placas del Estado.';

-- Presentacion con guion para la UI y los reportes (ABC1234 -> ABC-1234).
create or replace function public.formatear_placa(p_placa text)
returns text
language sql
immutable
set search_path = public
as $$
  select case
    when public.normalizar_placa(p_placa) is null then null
    when public.normalizar_placa(p_placa) ~ '^[A-Z]{3}[0-9]{3,4}$'
      then substr(public.normalizar_placa(p_placa), 1, 3) || '-' || substr(public.normalizar_placa(p_placa), 4)
    else public.normalizar_placa(p_placa)
  end;
$$;

comment on function public.formatear_placa(text) is
  'Presenta una placa canonica con guion (ABC1234 -> ABC-1234). Solo para mostrar; la columna guarda la forma canonica.';

-- ---------------------------------------------------------------------------
-- 6. Identidad de dispositivos: MAC e IP
-- ---------------------------------------------------------------------------
create or replace function public.es_mac(p_mac text)
returns boolean
language sql
immutable
set search_path = public
as $$
  select p_mac is null
      or p_mac ~ '^[0-9A-F]{2}(:[0-9A-F]{2}){5}$';
$$;

comment on function public.es_mac(text) is
  'MAC en formato canonico AA:BB:CC:DD:EE:FF (mayusculas, separada por ":").';

-- Se apoya en el cast a inet en vez de una regex: Postgres ya sabe que es una
-- IP valida, e incluye IPv6 gratis. La excepcion se atrapa porque un CHECK que
-- lanza error en vez de devolver false aborta el INSERT con un mensaje ilegible.
create or replace function public.es_ip(p_ip text)
returns boolean
language plpgsql
immutable
set search_path = public
as $$
begin
  if p_ip is null then
    return true;
  end if;
  perform p_ip::inet;
  return true;
exception
  when others then
    return false;
end;
$$;

comment on function public.es_ip(text) is
  'Direccion IP valida (IPv4 o IPv6), verificada con el cast a inet de Postgres.';

-- ---------------------------------------------------------------------------
-- 7. Nombres de persona
-- ---------------------------------------------------------------------------
-- Letras (con tildes y ñ), espacios, guiones, apostrofes y puntos. Sin digitos.
-- No se usa [[:alpha:]] porque su resultado depende del locale de la BD y aqui
-- hace falta un patron identico al del frontend.
create or replace function public.es_nombre_persona(p_nombre text)
returns boolean
language sql
immutable
set search_path = public
as $$
  select p_nombre is null
      or (btrim(p_nombre) ~ '^[A-Za-zÁÉÍÓÚÜÑáéíóúüñ][A-Za-zÁÉÍÓÚÜÑáéíóúüñ ''.-]*$'
          and length(btrim(p_nombre)) >= 2);
$$;

comment on function public.es_nombre_persona(text) is
  'Nombre o apellido: solo letras (con tildes y ñ), espacios, guion, apostrofe y punto; minimo 2 caracteres.';

-- Colapsa espacios repetidos y recorta los de los extremos ("Victor  Hugo " ->
-- "Victor Hugo"). El proyecto remoto ya tiene filas con espacio final.
create or replace function public.normalizar_espacios(p_texto text)
returns text
language sql
immutable
set search_path = public
as $$
  select case
    when p_texto is null then null
    when btrim(regexp_replace(p_texto, '\s+', ' ', 'g')) = '' then null
    else btrim(regexp_replace(p_texto, '\s+', ' ', 'g'))
  end;
$$;

comment on function public.normalizar_espacios(text) is
  'Recorta los extremos y colapsa espacios repetidos. Devuelve NULL si solo habia espacios.';

-- ---------------------------------------------------------------------------
-- 8. Fecha de nacimiento
-- ---------------------------------------------------------------------------
-- Sin edad minima a proposito: el CEC de la EPN dicta cursos a menores de edad
-- (persona_interna_detalle.curso los contempla), asi que un minimo de 15 o 18
-- rechazaria registros legitimos. Solo se descarta lo imposible.
--
-- STABLE, no IMMUTABLE: depende de current_date. Por eso NO puede ir en un
-- CHECK (Postgres exige inmutabilidad ahi, y marcarla immutable seria mentir:
-- el valor cambia cada dia y un restore revalidaria con otra fecha). Se aplica
-- desde el trigger de persona.
create or replace function public.es_fecha_nacimiento_valida(p_fecha date)
returns boolean
language sql
stable
set search_path = public
as $$
  select p_fecha is null
      or (p_fecha <= current_date and p_fecha > current_date - interval '120 years');
$$;

comment on function public.es_fecha_nacimiento_valida(date) is
  'Fecha de nacimiento no futura y de menos de 120 anios. Sin edad minima: el CEC registra menores.';

-- ---------------------------------------------------------------------------
-- 9. Codigos internos
-- ---------------------------------------------------------------------------
-- Convencion de CLAUDE.md: MODULO_ENTIDAD_ACCION, modulo de la lista cerrada.
create or replace function public.es_codigo_permiso(p_codigo text)
returns boolean
language sql
immutable
set search_path = public
as $$
  select p_codigo is null
      or p_codigo ~ '^(ADM|GPI|GPE|PCO|CAC)_[A-Z0-9]+(_[A-Z0-9]+)+$';
$$;

comment on function public.es_codigo_permiso(text) is
  'Codigo de permiso MODULO_ENTIDAD_ACCION con modulo en ADM/GPI/GPE/PCO/CAC (convencion de CLAUDE.md).';

-- Valor de parametro_sistema coherente con su propio tipo_dato declarado: hoy
-- TIEMPO_SESION_MIN podria guardar 'abc' y solo reventaria dentro de
-- registrar_sesion(), en tiempo de ejecucion y lejos de la causa.
create or replace function public.valor_parametro_coherente(p_tipo_dato text, p_valor text)
returns boolean
language plpgsql
immutable
set search_path = public
as $$
begin
  if p_valor is null or p_tipo_dato is null then
    return true;
  end if;

  -- Los nombres son los del CHECK ya existente en parametro_sistema.tipo_dato:
  -- ENTERO, TEXTO, BOOLEANO, DECIMAL, FECHA (no INTEGER/BOOLEAN/DATE).
  case p_tipo_dato
    when 'ENTERO' then perform p_valor::integer;
    when 'DECIMAL' then perform p_valor::numeric;
    when 'BOOLEANO' then
      if lower(p_valor) not in ('true', 'false') then
        return false;
      end if;
    when 'FECHA' then perform p_valor::date;
    else return true; -- TEXTO y cualquier tipo futuro: sin restriccion
  end case;

  return true;
exception
  when others then
    return false;
end;
$$;

comment on function public.valor_parametro_coherente(text, text) is
  'Verifica que parametro_sistema.valor_parametro castee al tipo declarado en tipo_dato.';

-- ---------------------------------------------------------------------------
-- 10. Permisos de ejecucion (patron de 20260713192300_hardening_funciones.sql)
-- ---------------------------------------------------------------------------
-- Son IMMUTABLE y no tocan tablas. Se exponen a authenticated (el frontend
-- podria validar via RPC) pero nunca a anon ni a public.
revoke execute on function
  public.es_cedula_ecuatoriana(text),
  public.es_ruc_ecuatoriano(text),
  public.normalizar_telefono_ec(text),
  public.es_telefono_ec(text),
  public.es_correo(text),
  public.es_correo_institucional_epn(text),
  public.normalizar_placa(text),
  public.es_placa_ec(text),
  public.formatear_placa(text),
  public.es_mac(text),
  public.es_ip(text),
  public.es_nombre_persona(text),
  public.normalizar_espacios(text),
  public.es_fecha_nacimiento_valida(date),
  public.es_codigo_permiso(text),
  public.valor_parametro_coherente(text, text)
from public, anon;

grant execute on function
  public.es_cedula_ecuatoriana(text),
  public.es_ruc_ecuatoriano(text),
  public.normalizar_telefono_ec(text),
  public.es_telefono_ec(text),
  public.es_correo(text),
  public.es_correo_institucional_epn(text),
  public.normalizar_placa(text),
  public.es_placa_ec(text),
  public.formatear_placa(text),
  public.es_mac(text),
  public.es_ip(text),
  public.es_nombre_persona(text),
  public.normalizar_espacios(text),
  public.es_fecha_nacimiento_valida(date),
  public.es_codigo_permiso(text),
  public.valor_parametro_coherente(text, text)
to authenticated;
