-- Triggers de normalizacion y CHECK de validacion sobre las tablas.
-- Depende de 20260716010000_funciones_validacion.sql (las funciones) y de
-- 20260716010100_saneamiento_datos.sql (los datos ya saneados).
--
-- Patron: el trigger normaliza SIEMPRE antes de que el CHECK juzgue. Un guardia
-- que teclea "0987654321" o "pdf-1234" no debe recibir un error: debe quedar
-- guardado "+593987654321" y "PDF1234". El CHECK solo rechaza lo que no se
-- puede interpretar.
--
-- Los CHECK marcados NOT VALID no revisan las filas ya existentes (hay datos
-- historicos que no se pueden reparar sin inventar informacion), pero SI se
-- aplican a todo INSERT y a todo UPDATE desde ahora.

-- ---------------------------------------------------------------------------
-- 1. persona
-- ---------------------------------------------------------------------------
create or replace function public.normalizar_persona()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.nombres := public.normalizar_espacios(new.nombres);
  new.apellidos := public.normalizar_espacios(new.apellidos);
  new.telefono_contacto := public.normalizar_telefono_ec(new.telefono_contacto);
  new.telefono_respaldo := public.normalizar_telefono_ec(new.telefono_respaldo);
  new.correo := lower(public.normalizar_espacios(new.correo));
  new.correo_respaldo := lower(public.normalizar_espacios(new.correo_respaldo));
  new.cedula := public.normalizar_espacios(new.cedula);
  new.codigo_unico := public.normalizar_espacios(new.codigo_unico);
  new.direccion_domicilio := public.normalizar_espacios(new.direccion_domicilio);

  -- fecha_nacimiento depende de current_date: no puede vivir en un CHECK
  -- (exige inmutabilidad), asi que se valida aqui.
  if not public.es_fecha_nacimiento_valida(new.fecha_nacimiento) then
    raise exception 'fecha_nacimiento invalida (%): debe ser pasada y de menos de 120 anios', new.fecha_nacimiento
      using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_normalizar_persona on public.persona;
create trigger trg_normalizar_persona
before insert or update on public.persona
for each row execute function public.normalizar_persona();

alter table public.persona drop constraint if exists persona_cedula_valida;
alter table public.persona add constraint persona_cedula_valida
  check (public.es_cedula_ecuatoriana(cedula));

alter table public.persona drop constraint if exists persona_nombres_validos;
alter table public.persona add constraint persona_nombres_validos
  check (public.es_nombre_persona(nombres));

alter table public.persona drop constraint if exists persona_apellidos_validos;
alter table public.persona add constraint persona_apellidos_validos
  check (public.es_nombre_persona(apellidos));

alter table public.persona drop constraint if exists persona_telefono_contacto_valido;
alter table public.persona add constraint persona_telefono_contacto_valido
  check (public.es_telefono_ec(telefono_contacto));

alter table public.persona drop constraint if exists persona_telefono_respaldo_valido;
alter table public.persona add constraint persona_telefono_respaldo_valido
  check (public.es_telefono_ec(telefono_respaldo));

alter table public.persona drop constraint if exists persona_correo_valido;
alter table public.persona add constraint persona_correo_valido
  check (public.es_correo(correo));

-- El correo de respaldo es, por definicion, el personal alternativo: se queda
-- libre aunque la persona sea interna (el remoto tiene un al@gmail.com asi).
alter table public.persona drop constraint if exists persona_correo_respaldo_valido;
alter table public.persona add constraint persona_correo_respaldo_valido
  check (public.es_correo(correo_respaldo));

-- Correo institucional solo para el personal INTERNO. Los externos (visitantes,
-- contratistas, proveedores) no tienen correo EPN por definicion: exigirselo
-- romperia el modulo GPE entero.
alter table public.persona drop constraint if exists persona_correo_institucional_si_interna;
alter table public.persona add constraint persona_correo_institucional_si_interna
  check (tipo_persona <> 'INTERNA' or public.es_correo_institucional_epn(correo));

-- El frontend ya ofrecia solo M/F (web/src/lib/catalogos.ts) pero la columna no
-- tenia CHECK: la API REST aceptaba cualquier cosa.
alter table public.persona drop constraint if exists persona_sexo_valido;
alter table public.persona add constraint persona_sexo_valido
  check (sexo is null or sexo in ('M', 'F'));

-- ---------------------------------------------------------------------------
-- 2. usuario_sistema
-- ---------------------------------------------------------------------------
create or replace function public.normalizar_usuario_sistema()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.nombre_usuario := lower(public.normalizar_espacios(new.nombre_usuario));
  new.correo_electronico := lower(public.normalizar_espacios(new.correo_electronico));
  return new;
end;
$$;

drop trigger if exists trg_normalizar_usuario_sistema on public.usuario_sistema;
create trigger trg_normalizar_usuario_sistema
before insert or update on public.usuario_sistema
for each row execute function public.normalizar_usuario_sistema();

-- nombre.apellido: minusculas, digitos, punto, guion y guion bajo. 3..50.
alter table public.usuario_sistema drop constraint if exists usuario_sistema_nombre_usuario_valido;
alter table public.usuario_sistema add constraint usuario_sistema_nombre_usuario_valido
  check (nombre_usuario ~ '^[a-z0-9]([a-z0-9._-]{1,48})[a-z0-9]$');

-- Quien inicia sesion en el sistema es siempre personal de la EPN.
alter table public.usuario_sistema drop constraint if exists usuario_sistema_correo_valido;
alter table public.usuario_sistema add constraint usuario_sistema_correo_valido
  check (public.es_correo_institucional_epn(correo_electronico));

alter table public.usuario_sistema drop constraint if exists usuario_sistema_intentos_fallidos_no_negativo;
alter table public.usuario_sistema add constraint usuario_sistema_intentos_fallidos_no_negativo
  check (intentos_fallidos >= 0);

-- ---------------------------------------------------------------------------
-- 3. empresa
-- ---------------------------------------------------------------------------
create or replace function public.normalizar_empresa()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.nombre := public.normalizar_espacios(new.nombre);
  new.ruc := public.normalizar_espacios(new.ruc);
  new.tipo_servicio := public.normalizar_espacios(new.tipo_servicio);
  return new;
end;
$$;

drop trigger if exists trg_normalizar_empresa on public.empresa;
create trigger trg_normalizar_empresa
before insert or update on public.empresa
for each row execute function public.normalizar_empresa();

alter table public.empresa drop constraint if exists empresa_ruc_valido;
alter table public.empresa add constraint empresa_ruc_valido
  check (public.es_ruc_ecuatoriano(ruc));

alter table public.empresa drop constraint if exists empresa_nombre_no_vacio;
alter table public.empresa add constraint empresa_nombre_no_vacio
  check (btrim(nombre) <> '');

-- tipo_servicio se deja como texto libre a proposito: no hay catalogo cerrado
-- en ningun documento del proyecto y el remoto ya usa valores en minusculas
-- ("Limpieza", "Seguridad"). Anotado en docs/99_DUDAS_PARA_EL_EQUIPO.md.

-- ---------------------------------------------------------------------------
-- 4. vehiculo
-- ---------------------------------------------------------------------------
-- Reemplaza a normalizar_placa_vehiculo() (20260713190000_adm_maestras.sql),
-- que solo hacia upper(). Ahora la placa se guarda en forma canonica sin guion
-- para que el OCR de placas pueda comparar por igualdad exacta.
create or replace function public.normalizar_placa_vehiculo()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.placa := public.normalizar_placa(new.placa);
  new.marca := public.normalizar_espacios(new.marca);
  new.modelo := public.normalizar_espacios(new.modelo);
  new.color := public.normalizar_espacios(new.color);
  return new;
end;
$$;

alter table public.vehiculo drop constraint if exists vehiculo_placa_valida;
alter table public.vehiculo add constraint vehiculo_placa_valida
  check (public.es_placa_ec(placa));

-- ---------------------------------------------------------------------------
-- 5. dispositivo
-- ---------------------------------------------------------------------------
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

drop trigger if exists trg_normalizar_dispositivo on public.dispositivo;
create trigger trg_normalizar_dispositivo
before insert or update on public.dispositivo
for each row execute function public.normalizar_dispositivo();

-- NOT VALID: el remoto tiene '00:14:2B:44:14:1', con un octeto incompleto. No
-- se puede reparar sin inventar el digito que falta.
alter table public.dispositivo drop constraint if exists dispositivo_mac_valida;
alter table public.dispositivo add constraint dispositivo_mac_valida
  check (public.es_mac(codigo_mac)) not valid;

alter table public.dispositivo drop constraint if exists dispositivo_ip_valida;
alter table public.dispositivo add constraint dispositivo_ip_valida
  check (public.es_ip(direccion_ip));

-- ---------------------------------------------------------------------------
-- 6. permiso y parametro_sistema
-- ---------------------------------------------------------------------------
-- Convencion MODULO_ENTIDAD_ACCION de CLAUDE.md. Verificado contra el remoto:
-- las 100+ filas de permiso ya la cumplen.
alter table public.permiso drop constraint if exists permiso_codigo_valido;
alter table public.permiso add constraint permiso_codigo_valido
  check (public.es_codigo_permiso(codigo_permiso));

alter table public.parametro_sistema drop constraint if exists parametro_sistema_codigo_valido;
alter table public.parametro_sistema add constraint parametro_sistema_codigo_valido
  check (codigo_parametro ~ '^[A-Z][A-Z0-9_]*$');

-- Sin esto, TIEMPO_SESION_MIN podria guardar 'abc' y solo reventaria dentro de
-- registrar_sesion(), en tiempo de ejecucion y lejos de la causa.
alter table public.parametro_sistema drop constraint if exists parametro_sistema_valor_coherente;
alter table public.parametro_sistema add constraint parametro_sistema_valor_coherente
  check (public.valor_parametro_coherente(tipo_dato, valor_parametro));

-- ---------------------------------------------------------------------------
-- 7. Rangos de fechas
-- ---------------------------------------------------------------------------
-- memorando ya tiene chk_memorando_fechas; aqui van los que faltaban.
alter table public.guardia_punto_control drop constraint if exists gpc_fechas_coherentes;
alter table public.guardia_punto_control add constraint gpc_fechas_coherentes
  check (fecha_fin is null or fecha_fin > fecha_inicio);

alter table public.persona_vehiculo drop constraint if exists persona_vehiculo_fechas_coherentes;
alter table public.persona_vehiculo add constraint persona_vehiculo_fechas_coherentes
  check (fecha_fin is null or fecha_fin > fecha_inicio);

-- NOTA deliberada: NO se exige horario_fin > horario_inicio en regla_acceso.
-- El turno NOCTURNO existe (docs/03 §linea 39) y una regla de 22:00 a 06:00 es
-- legitima; ese CHECK romperia un caso real del sistema.

-- ---------------------------------------------------------------------------
-- 8. Textos obligatorios que no pueden ser solo espacios
-- ---------------------------------------------------------------------------
-- El `required` del formulario deja pasar " ". El remoto ya tenia nombres con
-- espacio final y empresas con espacio inicial.
alter table public.zona drop constraint if exists zona_nombre_no_vacio;
alter table public.zona add constraint zona_nombre_no_vacio
  check (btrim(nombre_zona) <> '');

alter table public.punto_control drop constraint if exists punto_control_nombre_no_vacio;
alter table public.punto_control add constraint punto_control_nombre_no_vacio
  check (btrim(nombre_punto) <> '');

alter table public.regla_acceso drop constraint if exists regla_acceso_nombre_no_vacio;
alter table public.regla_acceso add constraint regla_acceso_nombre_no_vacio
  check (btrim(nombre_regla) <> '');

alter table public.memorando drop constraint if exists memorando_numero_no_vacio;
alter table public.memorando add constraint memorando_numero_no_vacio
  check (btrim(numero_memorando) <> '');

alter table public.autorizacion_visita_diaria drop constraint if exists autorizacion_motivo_no_vacio;
alter table public.autorizacion_visita_diaria add constraint autorizacion_motivo_no_vacio
  check (btrim(motivo) <> '');

alter table public.categoria_persona drop constraint if exists categoria_nombre_no_vacio;
alter table public.categoria_persona add constraint categoria_nombre_no_vacio
  check (btrim(nombre_categoria) <> '');

-- ---------------------------------------------------------------------------
-- 9. Permisos de las funciones de trigger
-- ---------------------------------------------------------------------------
-- Nadie las llama por RPC (patron de 20260715020000_endurecer_permisos_*).
revoke execute on function
  public.normalizar_persona(),
  public.normalizar_usuario_sistema(),
  public.normalizar_empresa(),
  public.normalizar_dispositivo(),
  public.normalizar_placa_vehiculo()
from public, anon, authenticated;
