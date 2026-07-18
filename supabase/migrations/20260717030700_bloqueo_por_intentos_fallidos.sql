-- Bloqueo automatico de la cuenta tras N intentos fallidos de inicio de sesion.
--
-- El problema: `usuario_sistema.intentos_fallidos` era una columna decorativa —
-- nadie la escribia nunca — y los parametros MAX_INTENTOS_LOGIN (5) y
-- TIEMPO_BLOQUEO_CUENTA_MIN (15) no los leia nadie. El sistema aceptaba intentos
-- de contrasena ilimitados: vulnerable a fuerza bruta.
--
-- POR QUE UN AUTH HOOK Y NO UN CONTADOR EN EL FRONTEND: el navegador habla
-- directamente con GoTrue (/auth/v1/token). Si el conteo viviera en el frontend
-- o en una Edge Function propia, un atacante llamaria a GoTrue directamente y se
-- saltaria el limite por completo. El hook `password_verification_attempt` lo
-- invoca GoTrue en CADA verificacion de contrasena, dentro de su propio flujo:
-- es el unico punto que no se puede esquivar con la clave publica.
--
-- DOS BLOQUEOS DISTINTOS, A PROPOSITO:
--   * estado_usuario = 'BLOQUEADO'  -> bloqueo administrativo PERMANENTE, ya
--     existente (20260717020418): banea en GoTrue hasta que un admin reactive.
--   * bloqueado_hasta              -> bloqueo TEMPORAL automatico por intentos
--     fallidos, que caduca solo a los TIEMPO_BLOQUEO_CUENTA_MIN minutos.
-- Mezclarlos haria que el bloqueo automatico exigiera intervencion manual.

-- ---------------------------------------------------------------------------
-- 1. Columna del bloqueo temporal
-- ---------------------------------------------------------------------------
alter table public.usuario_sistema
  add column if not exists bloqueado_hasta timestamptz;

comment on column public.usuario_sistema.bloqueado_hasta is
  'Fin del bloqueo TEMPORAL por intentos fallidos. NULL = sin bloqueo. Distinto de estado_usuario = BLOQUEADO, que es administrativo y permanente.';

create index if not exists idx_usuario_sistema_bloqueado
  on public.usuario_sistema (bloqueado_hasta)
  where bloqueado_hasta is not null;

-- ---------------------------------------------------------------------------
-- 2. El hook que GoTrue invoca en cada verificacion de contrasena
-- ---------------------------------------------------------------------------
-- Contrato de Supabase:
--   entrada: {"user_id": "<uuid>", "valid": true|false}
--   salida : {"decision": "continue"} | {"decision": "reject", "message": "..."}
--
-- FAIL-OPEN deliberado: si esta funcion lanzara una excepcion, GoTrue rechazaria
-- TODOS los inicios de sesion y dejaria el sistema inaccesible. Ante un error
-- inesperado se devuelve "continue", que solo significa "sin capa extra de
-- bloqueo": la contrasena la sigue verificando GoTrue, asi que no deja entrar a
-- nadie que no la sepa.
create or replace function public.hook_password_verification_attempt(event jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid;
  v_valido boolean;
  v_max integer;
  v_minutos integer;
  v_intentos integer;
  v_bloqueado timestamptz;
  v_estado text;
  v_restantes integer;
begin
  v_uid := nullif(event ->> 'user_id', '')::uuid;
  v_valido := coalesce((event ->> 'valid')::boolean, false);

  if v_uid is null then
    return jsonb_build_object('decision', 'continue');
  end if;

  select coalesce(max(valor_parametro::integer), 5) into v_max
    from public.parametro_sistema where codigo_parametro = 'MAX_INTENTOS_LOGIN';
  select coalesce(max(valor_parametro::integer), 15) into v_minutos
    from public.parametro_sistema where codigo_parametro = 'TIEMPO_BLOQUEO_CUENTA_MIN';

  select intentos_fallidos, bloqueado_hasta, estado_usuario
    into v_intentos, v_bloqueado, v_estado
    from public.usuario_sistema
   where id_usuario = v_uid;

  -- Sin perfil (p. ej. cuenta de servicio): no se aplica la politica.
  if not found then
    return jsonb_build_object('decision', 'continue');
  end if;

  -- (a) Bloqueo temporal vigente: se rechaza SIN volver a contar, para que
  -- seguir intentando no prolongue el castigo indefinidamente.
  if v_bloqueado is not null and v_bloqueado > now() then
    return jsonb_build_object(
      'decision', 'reject',
      'message', format(
        'Cuenta bloqueada temporalmente por superar %s intentos fallidos. Podra intentarlo de nuevo en %s minuto(s) o solicitar el desbloqueo al administrador.',
        v_max, greatest(1, ceil(extract(epoch from (v_bloqueado - now())) / 60)::integer)
      )
    );
  end if;

  -- (b) Bloqueo cumplido: se levanta solo (desbloqueo automatico).
  if v_bloqueado is not null then
    update public.usuario_sistema
       set intentos_fallidos = 0, bloqueado_hasta = null
     where id_usuario = v_uid;
    v_intentos := 0;
  end if;

  -- (c) Contrasena correcta: se reinicia el contador.
  if v_valido then
    if coalesce(v_intentos, 0) <> 0 then
      update public.usuario_sistema
         set intentos_fallidos = 0, bloqueado_hasta = null
       where id_usuario = v_uid;
    end if;
    return jsonb_build_object('decision', 'continue');
  end if;

  -- (d) Contrasena incorrecta: se cuenta y, al llegar al maximo, se bloquea.
  update public.usuario_sistema
     set intentos_fallidos = coalesce(intentos_fallidos, 0) + 1,
         bloqueado_hasta = case
           when coalesce(intentos_fallidos, 0) + 1 >= v_max
             then now() + (v_minutos || ' minutes')::interval
           else bloqueado_hasta
         end
   where id_usuario = v_uid
  returning intentos_fallidos, bloqueado_hasta into v_intentos, v_bloqueado;

  if v_bloqueado is not null and v_bloqueado > now() then
    -- Queda constancia del bloqueo automatico. Va en su propio bloque: un fallo
    -- de auditoria no debe tumbar el inicio de sesion.
    begin
      insert into public.bitacora_sistema
        (id_usuario, accion, modulo, entidad_afectada, id_entidad_afectada, resultado, descripcion)
      values (v_uid, 'BLOQUEO_POR_INTENTOS_FALLIDOS', 'ADM', 'usuario_sistema', v_uid::text, 'ERROR',
              format('Cuenta bloqueada automaticamente por %s intentos fallidos durante %s minutos.', v_intentos, v_minutos));
    exception when others then
      null;
    end;

    return jsonb_build_object(
      'decision', 'reject',
      'message', format(
        'Cuenta bloqueada temporalmente por superar %s intentos fallidos. Podra intentarlo de nuevo en %s minutos o solicitar el desbloqueo al administrador.',
        v_max, v_minutos
      )
    );
  end if;

  -- Aun quedan intentos: GoTrue devuelve su error habitual de credenciales.
  v_restantes := greatest(0, v_max - coalesce(v_intentos, 0));
  return jsonb_build_object('decision', 'continue', 'intentos_restantes', v_restantes);

exception when others then
  -- Ver nota FAIL-OPEN arriba.
  return jsonb_build_object('decision', 'continue');
end;
$$;

comment on function public.hook_password_verification_attempt(jsonb) is
  'Auth Hook de GoTrue: cuenta intentos fallidos y bloquea la cuenta TIEMPO_BLOQUEO_CUENTA_MIN minutos al superar MAX_INTENTOS_LOGIN. Fail-open ante error inesperado.';

-- Solo GoTrue puede invocarlo; jamas un cliente.
revoke execute on function public.hook_password_verification_attempt(jsonb) from public, anon, authenticated;
grant execute on function public.hook_password_verification_attempt(jsonb) to supabase_auth_admin;

-- ---------------------------------------------------------------------------
-- 3. Desbloqueo manual desde ADM
-- ---------------------------------------------------------------------------
create or replace function public.desbloquear_intentos_login(p_id_usuario uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Se requiere un usuario autenticado.' using errcode = 'insufficient_privilege';
  end if;
  if not public.tiene_permiso('ADM_USUARIO_DESBLOQUEAR') then
    raise exception 'No tiene permiso para desbloquear cuentas.' using errcode = 'insufficient_privilege';
  end if;

  update public.usuario_sistema
     set intentos_fallidos = 0, bloqueado_hasta = null, fecha_modificacion = now()
   where id_usuario = p_id_usuario;

  insert into public.bitacora_sistema
    (id_usuario, accion, modulo, entidad_afectada, id_entidad_afectada, resultado, descripcion)
  values (auth.uid(), 'DESBLOQUEO_INTENTOS_FALLIDOS', 'ADM', 'usuario_sistema', p_id_usuario::text, 'EXITO',
          'Desbloqueo manual del contador de intentos fallidos.');
end;
$$;

comment on function public.desbloquear_intentos_login(uuid) is
  'Reinicia el contador de intentos fallidos y levanta el bloqueo temporal. Exige ADM_USUARIO_DESBLOQUEAR.';

revoke execute on function public.desbloquear_intentos_login(uuid) from public, anon;
grant execute on function public.desbloquear_intentos_login(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 4. Reactivar a un usuario tambien limpia el bloqueo temporal
-- ---------------------------------------------------------------------------
-- Sin esto, un administrador podria reactivar la cuenta y el usuario seguiria
-- sin poder entrar hasta que caducara el bloqueo por intentos.
create or replace function public.limpiar_bloqueo_al_activar()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.estado_usuario = 'ACTIVO'
     and (old.estado_usuario is distinct from 'ACTIVO')
     and (new.bloqueado_hasta is not null or coalesce(new.intentos_fallidos, 0) <> 0) then
    new.bloqueado_hasta := null;
    new.intentos_fallidos := 0;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_limpiar_bloqueo_al_activar on public.usuario_sistema;
create trigger trg_limpiar_bloqueo_al_activar
before update of estado_usuario on public.usuario_sistema
for each row execute function public.limpiar_bloqueo_al_activar();

revoke execute on function public.limpiar_bloqueo_al_activar() from public, anon, authenticated;
