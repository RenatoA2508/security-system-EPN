-- Bloqueo efectivo de usuarios: que un BLOQUEADO no pueda entrar de verdad.
--
-- El problema: `usuario_sistema.estado_usuario` era una columna decorativa.
-- Nadie la leia — ni tiene_permiso(), ni las politicas RLS, ni auth. Marcar a
-- alguien como BLOQUEADO le cambiaba la etiqueta en la pantalla de ADM y nada
-- mas: conservaba su JWT, sus permisos y su capacidad de iniciar sesion.
--
-- Se cierra por dos vias independientes, a proposito:
--   1. auth.users.banned_until -> GoTrue rechaza el login y la renovacion del
--      token. Ademas se borran sus sesiones vivas para echarlo ya.
--   2. Guard de estado_usuario = 'ACTIVO' dentro de tiene_permiso() y
--      permisos_efectivos() -> aunque conserve un JWT sin expirar, se queda sin
--      un solo permiso y RLS le niega todo. Efecto inmediato, sin esperar a que
--      caduque el token.
--
-- Con una sola via no basta: banned_until no invalida un JWT ya emitido (vive
-- hasta 1 h), y el guard por si solo no impide iniciar sesion.

-- ---------------------------------------------------------------------------
-- 1. Sincronizar estado_usuario -> auth.users
-- ---------------------------------------------------------------------------
-- ACTIVO es el unico estado que permite entrar. INACTIVO, BLOQUEADO y
-- DADO_DE_BAJA cortan el acceso; se distinguen entre si por intencion
-- administrativa, no por efecto tecnico.
--
-- El proyecto no borra filas (CLAUDE.md: sin DELETE fisico), asi que
-- DADO_DE_BAJA tampoco elimina de auth.users: es un ban permanente. La cuenta
-- sigue existiendo para que la bitacora y los eventos historicos conserven su
-- FK, que es justo lo que pide la regla.
create or replace function public.sincronizar_estado_auth()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Solo actuar si el estado cambio de verdad (en INSERT, old es null).
  if tg_op = 'UPDATE' and new.estado_usuario is not distinct from old.estado_usuario then
    return new;
  end if;

  if new.estado_usuario = 'ACTIVO' then
    -- Reactivar: se levanta el ban. Las sesiones no se restauran (no se puede):
    -- el usuario vuelve a iniciar sesion normalmente.
    update auth.users
       set banned_until = null
     where id = new.id_usuario
       and banned_until is not null;
  else
    -- 100 anios, que es lo que hace la Admin API de Supabase con
    -- ban_duration: '876000h'. No se usa 'infinity' porque GoTrue compara
    -- contra un timestamp concreto y el valor infinito ha dado problemas de
    -- serializacion en algunas versiones.
    update auth.users
       set banned_until = now() + interval '100 years'
     where id = new.id_usuario;

    -- Echarlo de las sesiones que ya tenia abiertas. Sin esto, banned_until
    -- solo impediria el proximo login: el JWT vigente seguiria sirviendo hasta
    -- expirar. Borrar la sesion invalida tambien su refresh token.
    delete from auth.refresh_tokens where user_id = new.id_usuario::text;
    delete from auth.sessions where user_id = new.id_usuario;

    -- Cerrar tambien las filas de auditoria de public.sesion, para que la
    -- ventana del administrador no lo siga mostrando dentro.
    update public.sesion
       set estado_sesion = 'CERRADA',
           fecha_cierre = now()
     where id_usuario = new.id_usuario
       and estado_sesion = 'ACTIVA';
  end if;

  return new;
end;
$$;

comment on function public.sincronizar_estado_auth() is
  'Refleja usuario_sistema.estado_usuario en auth.users.banned_until y corta las sesiones vivas cuando deja de estar ACTIVO.';

drop trigger if exists trg_sincronizar_estado_auth on public.usuario_sistema;
create trigger trg_sincronizar_estado_auth
after insert or update of estado_usuario on public.usuario_sistema
for each row execute function public.sincronizar_estado_auth();

-- ---------------------------------------------------------------------------
-- 2. Guard de estado en la resolucion de permisos
-- ---------------------------------------------------------------------------
-- Redefine tiene_permiso() y permisos_efectivos() de
-- 20260713190500_autenticacion.sql anadiendo el join con usuario_sistema. El
-- resto del cuerpo es identico: no se toca la logica de roles ni de vigencia.
--
-- Esto es lo que hace que la revocacion sea inmediata: los permisos se leen en
-- vivo en cada consulta (doc 01 §2, "no se copian al JWT"), asi que en cuanto
-- el estado deja de ser ACTIVO, la siguiente consulta del usuario ya no ve nada.
create or replace function public.tiene_permiso(p_codigo text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
      from public.usuario_sistema us
      join public.usuario_rol ur on ur.id_usuario = us.id_usuario
      join public.rol r on r.id_rol = ur.id_rol
      join public.rol_permiso rp on rp.id_rol = r.id_rol
      join public.permiso p on p.id_permiso = rp.id_permiso
     where us.id_usuario = auth.uid()
       and us.estado_usuario = 'ACTIVO'
       and ur.estado_asignacion = 'ACTIVO'
       and r.estado_rol = 'ACTIVO'
       and rp.estado_asignacion = 'ACTIVO'
       and p.estado_permiso = 'ACTIVO'
       and p.codigo_permiso = p_codigo
  );
$$;

comment on function public.tiene_permiso(text) is
  'True si el usuario autenticado esta ACTIVO y tiene el permiso vigente. Un usuario bloqueado/inactivo/dado de baja no tiene ninguno.';

create or replace function public.permisos_efectivos()
returns setof text
language sql
stable
security definer
set search_path = public
as $$
  select distinct p.codigo_permiso
    from public.usuario_sistema us
    join public.usuario_rol ur on ur.id_usuario = us.id_usuario
    join public.rol r on r.id_rol = ur.id_rol
    join public.rol_permiso rp on rp.id_rol = r.id_rol
    join public.permiso p on p.id_permiso = rp.id_permiso
   where us.id_usuario = auth.uid()
     and us.estado_usuario = 'ACTIVO'
     and ur.estado_asignacion = 'ACTIVO'
     and r.estado_rol = 'ACTIVO'
     and rp.estado_asignacion = 'ACTIVO'
     and p.estado_permiso = 'ACTIVO';
$$;

comment on function public.permisos_efectivos() is
  'Permisos del usuario autenticado. Vacio si su estado_usuario no es ACTIVO. allowed_modules() se apoya en esta.';

-- allowed_modules() y tiene_algun_modulo() se construyen sobre
-- permisos_efectivos(), asi que heredan el guard sin tocarlas.

-- ---------------------------------------------------------------------------
-- 3. Bloquear el registro de sesion de un usuario no activo
-- ---------------------------------------------------------------------------
-- Defensa en profundidad: si un bloqueado lograra autenticarse por alguna via,
-- que al menos no ensucie la tabla de auditoria con una sesion ACTIVA.
create or replace function public.registrar_sesion(p_ip_origen text default null, p_recordar_sesion boolean default false)
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

  select estado_usuario into v_estado
    from public.usuario_sistema
   where id_usuario = auth.uid();

  if v_estado is distinct from 'ACTIVO' then
    raise exception 'La cuenta no esta activa (estado: %)', coalesce(v_estado, 'desconocido')
      using errcode = 'insufficient_privilege';
  end if;

  select valor_parametro::integer into v_tiempo_sesion_min
    from public.parametro_sistema
   where codigo_parametro = 'TIEMPO_SESION_MIN';

  insert into public.sesion (id_usuario, fecha_inicio, fecha_expiracion, estado_sesion, ip_origen, recordar_sesion)
  values (
    auth.uid(),
    now(),
    now() + (coalesce(v_tiempo_sesion_min, 60) || ' minutes')::interval,
    'ACTIVA',
    p_ip_origen,
    p_recordar_sesion
  )
  returning * into v_row;

  update public.usuario_sistema set fecha_ultimo_login = now() where id_usuario = auth.uid();

  return v_row;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Reconciliar el estado actual
-- ---------------------------------------------------------------------------
-- Aplica el ban a quien ya estuviera marcado como no activo antes de que este
-- trigger existiera, y lo levanta a quien estuviera baneado en auth pero
-- ACTIVO aqui (deja ambos lados coherentes desde el primer dia).
do $$
declare
  r record;
begin
  for r in select id_usuario, estado_usuario from public.usuario_sistema loop
    if r.estado_usuario = 'ACTIVO' then
      update auth.users set banned_until = null where id = r.id_usuario and banned_until is not null;
    else
      update auth.users set banned_until = now() + interval '100 years' where id = r.id_usuario;
      delete from auth.refresh_tokens where user_id = r.id_usuario::text;
      delete from auth.sessions where user_id = r.id_usuario;
      update public.sesion set estado_sesion = 'CERRADA', fecha_cierre = now()
       where id_usuario = r.id_usuario and estado_sesion = 'ACTIVA';
    end if;
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 5. Permisos
-- ---------------------------------------------------------------------------
-- La funcion de trigger no la invoca nadie por RPC (patron de
-- 20260715020000_endurecer_permisos_funciones_trigger.sql).
revoke execute on function public.sincronizar_estado_auth() from public, anon, authenticated;

-- tiene_permiso y permisos_efectivos se recrearon: hay que re-conceder EXECUTE
-- (CREATE OR REPLACE conserva los grants, pero se deja explicito por si la
-- firma cambiara en el futuro).
revoke execute on function public.tiene_permiso(text), public.permisos_efectivos(), public.registrar_sesion(text, boolean) from public, anon;
grant execute on function public.tiene_permiso(text), public.permisos_efectivos(), public.registrar_sesion(text, boolean) to authenticated;
