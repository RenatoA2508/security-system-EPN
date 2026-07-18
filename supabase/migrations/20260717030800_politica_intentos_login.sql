-- Politica de intentos fallidos aplicable en el PLAN GRATUITO.
--
-- Contexto: 20260717030700 dejo escrito el Auth Hook de GoTrue, que es la forma
-- ideal de contar intentos (lo invoca el propio proveedor y no se puede
-- esquivar). Al intentar activarlo, la API respondio HTTP 402:
--   "The following auth hooks cannot be configured for this organization:
--    HOOK_PASSWORD_VERIFICATION_ATTEMPT"
-- Es una funcion de pago. El hook se conserva porque queda listo para el dia que
-- se contrate un plan superior: bastaria activarlo, sin tocar codigo.
--
-- Mientras tanto la politica se aplica desde la Edge Function `iniciar-sesion`,
-- que hace de proxy del login. Para que el bloqueo NO dependa de que el cliente
-- use esa funcion, al alcanzarse el maximo se escribe tambien
-- `auth.users.banned_until`: a partir de ese momento GoTrue rechaza el acceso
-- aunque alguien llame a /auth/v1/token directamente con la clave publica.
-- Como banned_until es una marca de tiempo, el DESBLOQUEO A LOS 15 MINUTOS es
-- automatico, sin tarea programada.
--
-- Limitacion honesta y documentada en docs/99: quien nunca use la Edge Function
-- e intente contra GoTrue directamente no incrementa el contador, asi que el
-- bloqueo no se dispara por esa via. Cerrarlo del todo exige el Auth Hook.

-- ---------------------------------------------------------------------------
-- 1. Politica central: una sola implementacion para los dos caminos
-- ---------------------------------------------------------------------------
create or replace function public.registrar_intento_login(p_id_usuario uuid, p_valido boolean)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_max integer;
  v_minutos integer;
  v_intentos integer;
  v_bloqueado timestamptz;
  v_estado text;
begin
  if p_id_usuario is null then
    return jsonb_build_object('bloqueado', false);
  end if;

  select coalesce(max(valor_parametro::integer), 5) into v_max
    from public.parametro_sistema where codigo_parametro = 'MAX_INTENTOS_LOGIN';
  select coalesce(max(valor_parametro::integer), 15) into v_minutos
    from public.parametro_sistema where codigo_parametro = 'TIEMPO_BLOQUEO_CUENTA_MIN';

  select intentos_fallidos, bloqueado_hasta, estado_usuario
    into v_intentos, v_bloqueado, v_estado
    from public.usuario_sistema
   where id_usuario = p_id_usuario;

  if not found then
    return jsonb_build_object('bloqueado', false);
  end if;

  -- (a) Bloqueo vigente: se informa sin volver a contar, para que insistir no
  -- prolongue el castigo indefinidamente.
  if v_bloqueado is not null and v_bloqueado > now() then
    return jsonb_build_object(
      'bloqueado', true,
      'bloqueado_hasta', v_bloqueado,
      'minutos_restantes', greatest(1, ceil(extract(epoch from (v_bloqueado - now())) / 60)::integer),
      'max_intentos', v_max
    );
  end if;

  -- (b) Bloqueo ya cumplido: se levanta solo.
  if v_bloqueado is not null then
    update public.usuario_sistema
       set intentos_fallidos = 0, bloqueado_hasta = null
     where id_usuario = p_id_usuario;
    -- Solo se levanta el ban si era el TEMPORAL: a un usuario bloqueado por el
    -- administrador (estado <> ACTIVO) no se le toca su ban permanente.
    if v_estado = 'ACTIVO' then
      update auth.users set banned_until = null where id = p_id_usuario;
    end if;
    v_intentos := 0;
  end if;

  -- (c) Credenciales correctas: se reinicia el contador.
  if p_valido then
    if coalesce(v_intentos, 0) <> 0 then
      update public.usuario_sistema
         set intentos_fallidos = 0, bloqueado_hasta = null
       where id_usuario = p_id_usuario;
    end if;
    return jsonb_build_object('bloqueado', false, 'intentos', 0);
  end if;

  -- (d) Credenciales incorrectas: se cuenta y, al llegar al maximo, se bloquea.
  update public.usuario_sistema
     set intentos_fallidos = coalesce(intentos_fallidos, 0) + 1,
         bloqueado_hasta = case
           when coalesce(intentos_fallidos, 0) + 1 >= v_max
             then now() + (v_minutos || ' minutes')::interval
           else bloqueado_hasta
         end
   where id_usuario = p_id_usuario
  returning intentos_fallidos, bloqueado_hasta into v_intentos, v_bloqueado;

  if v_bloqueado is not null and v_bloqueado > now() then
    -- ESTA es la linea que hace efectivo el bloqueo: GoTrue rechazara el login
    -- aunque no se pase por la Edge Function. Nunca se acorta un ban
    -- administrativo (100 anios) de un usuario que no esta ACTIVO.
    if v_estado = 'ACTIVO' then
      update auth.users set banned_until = v_bloqueado where id = p_id_usuario;
    end if;

    begin
      insert into public.bitacora_sistema
        (id_usuario, accion, modulo, entidad_afectada, id_entidad_afectada, resultado, descripcion)
      values (p_id_usuario, 'BLOQUEO_POR_INTENTOS_FALLIDOS', 'ADM', 'usuario_sistema', p_id_usuario::text, 'ERROR',
              format('Cuenta bloqueada automaticamente por %s intentos fallidos durante %s minutos.', v_intentos, v_minutos));
    exception when others then
      null; -- un fallo de auditoria no debe romper el inicio de sesion
    end;

    return jsonb_build_object(
      'bloqueado', true,
      'bloqueado_hasta', v_bloqueado,
      'minutos_restantes', v_minutos,
      'max_intentos', v_max,
      'recien_bloqueado', true
    );
  end if;

  return jsonb_build_object(
    'bloqueado', false,
    'intentos', v_intentos,
    'max_intentos', v_max,
    'intentos_restantes', greatest(0, v_max - coalesce(v_intentos, 0))
  );
end;
$$;

comment on function public.registrar_intento_login(uuid, boolean) is
  'Politica de intentos fallidos: cuenta, bloquea TIEMPO_BLOQUEO_CUENTA_MIN minutos al superar MAX_INTENTOS_LOGIN y refleja el bloqueo en auth.users.banned_until para que GoTrue lo aplique. Desbloqueo automatico por vencimiento.';

-- La invoca la Edge Function `iniciar-sesion` con service_role. Ningun cliente.
revoke execute on function public.registrar_intento_login(uuid, boolean) from public, anon, authenticated;
grant execute on function public.registrar_intento_login(uuid, boolean) to service_role;

-- ---------------------------------------------------------------------------
-- 2. El Auth Hook pasa a ser una envoltura de la misma politica
-- ---------------------------------------------------------------------------
-- Asi los dos caminos comparten implementacion y no pueden divergir. Hoy no se
-- invoca (requiere plan de pago); queda listo para activarse sin tocar codigo.
create or replace function public.hook_password_verification_attempt(event jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_estado jsonb;
begin
  v_estado := public.registrar_intento_login(
    nullif(event ->> 'user_id', '')::uuid,
    coalesce((event ->> 'valid')::boolean, false)
  );

  if coalesce((v_estado ->> 'bloqueado')::boolean, false) then
    return jsonb_build_object(
      'decision', 'reject',
      'message', format(
        'Cuenta bloqueada temporalmente por superar %s intentos fallidos. Podra intentarlo de nuevo en %s minuto(s) o solicitar el desbloqueo al administrador.',
        coalesce(v_estado ->> 'max_intentos', '5'),
        coalesce(v_estado ->> 'minutos_restantes', '15')
      )
    );
  end if;

  return jsonb_build_object('decision', 'continue');
exception when others then
  -- Fail-open: un error aqui jamas debe dejar el sistema sin acceso.
  return jsonb_build_object('decision', 'continue');
end;
$$;

comment on function public.hook_password_verification_attempt(jsonb) is
  'Auth Hook de GoTrue (requiere plan de pago). Envoltura de registrar_intento_login. Fail-open ante error inesperado.';

revoke execute on function public.hook_password_verification_attempt(jsonb) from public, anon, authenticated;
grant execute on function public.hook_password_verification_attempt(jsonb) to supabase_auth_admin;

-- ---------------------------------------------------------------------------
-- 3. El desbloqueo manual tambien levanta el ban de GoTrue
-- ---------------------------------------------------------------------------
create or replace function public.desbloquear_intentos_login(p_id_usuario uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_estado text;
begin
  if auth.uid() is null then
    raise exception 'Se requiere un usuario autenticado.' using errcode = 'insufficient_privilege';
  end if;
  if not public.tiene_permiso('ADM_USUARIO_DESBLOQUEAR') then
    raise exception 'No tiene permiso para desbloquear cuentas.' using errcode = 'insufficient_privilege';
  end if;

  select estado_usuario into v_estado from public.usuario_sistema where id_usuario = p_id_usuario;

  update public.usuario_sistema
     set intentos_fallidos = 0, bloqueado_hasta = null, fecha_modificacion = now()
   where id_usuario = p_id_usuario;

  -- Solo se levanta el ban temporal; un usuario bloqueado por el administrador
  -- sigue baneado hasta que se le reactive por su estado.
  if v_estado = 'ACTIVO' then
    update auth.users set banned_until = null where id = p_id_usuario;
  end if;

  insert into public.bitacora_sistema
    (id_usuario, accion, modulo, entidad_afectada, id_entidad_afectada, resultado, descripcion)
  values (auth.uid(), 'DESBLOQUEO_INTENTOS_FALLIDOS', 'ADM', 'usuario_sistema', p_id_usuario::text, 'EXITO',
          'Desbloqueo manual del contador de intentos fallidos.');
end;
$$;

revoke execute on function public.desbloquear_intentos_login(uuid) from public, anon;
grant execute on function public.desbloquear_intentos_login(uuid) to authenticated;
