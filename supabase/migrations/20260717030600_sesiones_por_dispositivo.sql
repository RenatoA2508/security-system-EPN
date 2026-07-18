-- Sesiones correctas con VARIOS dispositivos abiertos a la vez (req 29).
--
-- Problema que corrige: las funciones de sesion operaban "por usuario", no "por
-- sesion". Con un PC y un celular conectados al mismo tiempo:
--   * cerrar_sesion() cerraba la sesion ACTIVA mas reciente del usuario, que
--     podia ser la del OTRO dispositivo. Cerrar sesion en el celular marcaba como
--     CERRADA la fila del PC, que seguia trabajando.
--   * tocar_sesion() refrescaba fecha_ultima_actividad de TODAS las sesiones del
--     usuario, asi que la actividad en el PC mantenia viva la del celular y el
--     timeout de inactividad por dispositivo nunca se cumplia.
--
-- Solucion: el cliente recuerda el id_sesion que le devolvio registrar_sesion() y
-- lo pasa al cerrar y al renovar actividad. Se conserva el comportamiento
-- anterior cuando no se envia id (compatibilidad con clientes que no lo manden).
--
-- Ademas se guarda un nombre de dispositivo legible ("Chrome en Windows") para
-- que la pantalla de Sesiones muestre desde donde se abrio cada una.

-- ---------------------------------------------------------------------------
-- 1. registrar_sesion: guarda tambien el dispositivo legible
-- ---------------------------------------------------------------------------
drop function if exists public.registrar_sesion(text, boolean, text);

create or replace function public.registrar_sesion(
  p_ip_origen text default null,
  p_recordar_sesion boolean default false,
  p_user_agent text default null,
  p_dispositivo text default null
)
returns public.sesion
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tiempo_sesion_min integer;
  v_estado text;
  v_row public.sesion;
begin
  if auth.uid() is null then
    raise exception 'registrar_sesion requiere un usuario autenticado';
  end if;

  select estado_usuario into v_estado from public.usuario_sistema where id_usuario = auth.uid();
  if v_estado is distinct from 'ACTIVO' then
    raise exception 'La cuenta no esta activa (estado: %)', coalesce(v_estado, 'desconocido')
      using errcode = 'insufficient_privilege';
  end if;

  select valor_parametro::integer into v_tiempo_sesion_min
    from public.parametro_sistema where codigo_parametro = 'TIEMPO_SESION_MIN';

  insert into public.sesion
    (id_usuario, fecha_inicio, fecha_ultima_actividad, fecha_expiracion, estado_sesion,
     ip_origen, recordar_sesion, user_agent, dispositivo_nombre)
  values (
    auth.uid(), now(), now(),
    now() + (coalesce(v_tiempo_sesion_min, 60) || ' minutes')::interval,
    'ACTIVA', p_ip_origen, coalesce(p_recordar_sesion, false),
    p_user_agent, public.normalizar_espacios(p_dispositivo)
  )
  returning * into v_row;

  update public.usuario_sistema set fecha_ultimo_login = now() where id_usuario = auth.uid();
  return v_row;
end;
$$;

comment on function public.registrar_sesion(text, boolean, text, text) is
  'Registra la sesion de auditoria al iniciar sesion: ultima actividad, recordar_sesion, user agent y dispositivo legible. Devuelve la fila para que el cliente recuerde su id_sesion.';

-- ---------------------------------------------------------------------------
-- 2. cerrar_sesion: cierra SOLO la sesion de este dispositivo
-- ---------------------------------------------------------------------------
drop function if exists public.cerrar_sesion();

create or replace function public.cerrar_sesion(p_id_sesion uuid default null)
returns public.sesion
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_row public.sesion;
begin
  if auth.uid() is null then
    raise exception 'cerrar_sesion requiere un usuario autenticado';
  end if;

  if p_id_sesion is not null then
    -- Solo esa sesion, y solo si es del propio usuario. SIN respaldo: si ya
    -- estaba cerrada, no se debe cerrar por error la de otro dispositivo.
    select s.id_sesion into v_id
      from public.sesion s
     where s.id_sesion = p_id_sesion
       and s.id_usuario = auth.uid()
       and s.estado_sesion = 'ACTIVA';
  else
    -- Cliente antiguo que no envia id: se conserva el comportamiento previo.
    select s.id_sesion into v_id
      from public.sesion s
     where s.id_usuario = auth.uid() and s.estado_sesion = 'ACTIVA'
     order by s.fecha_inicio desc
     limit 1;
  end if;

  if v_id is null then
    return null; -- nada que cerrar no es un error (pudo expirar antes)
  end if;

  update public.sesion
     set estado_sesion = 'CERRADA', fecha_cierre = now(), motivo_cierre = 'LOGOUT'
   where id_sesion = v_id
  returning * into v_row;

  return v_row;
end;
$$;

comment on function public.cerrar_sesion(uuid) is
  'Cierra la sesion indicada (si es del usuario autenticado). Sin id, cierra la mas reciente. Req 29: no debe afectar a otros dispositivos.';

-- ---------------------------------------------------------------------------
-- 3. tocar_sesion: renueva la actividad SOLO de este dispositivo
-- ---------------------------------------------------------------------------
drop function if exists public.tocar_sesion();

create or replace function public.tocar_sesion(p_id_sesion uuid default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    return;
  end if;

  if p_id_sesion is not null then
    update public.sesion set fecha_ultima_actividad = now()
     where id_sesion = p_id_sesion
       and id_usuario = auth.uid()
       and estado_sesion = 'ACTIVA';
  else
    update public.sesion set fecha_ultima_actividad = now()
     where id_usuario = auth.uid() and estado_sesion = 'ACTIVA';
  end if;
end;
$$;

comment on function public.tocar_sesion(uuid) is
  'Renueva fecha_ultima_actividad de la sesion indicada. Sin id, de todas las del usuario (compatibilidad). Req 29.';

-- ---------------------------------------------------------------------------
-- 4. Permisos
-- ---------------------------------------------------------------------------
revoke execute on function public.registrar_sesion(text, boolean, text, text) from public, anon;
grant execute on function public.registrar_sesion(text, boolean, text, text) to authenticated;

revoke execute on function public.cerrar_sesion(uuid) from public, anon;
grant execute on function public.cerrar_sesion(uuid) to authenticated;

revoke execute on function public.tocar_sesion(uuid) from public, anon;
grant execute on function public.tocar_sesion(uuid) to authenticated;
