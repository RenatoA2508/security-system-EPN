-- Guardas contra dejar el sistema sin dueño.
--
-- El problema: `admin` es HOY el unico usuario con ADM_USUARIO_DESBLOQUEAR,
-- ADM_USUARIO_UPDATE y ADM_USUARIO_INSERT (verificado contra el remoto). Si se
-- bloquea a si mismo no queda nadie que pueda desbloquearlo. Mientras
-- estado_usuario era decorativo esto no se notaba; con el bloqueo efectivo de
-- 20260716030000 (banned_until + corte de sesiones) seria un cierre
-- permanente: ni siquiera podria volver a iniciar sesion.
--
-- Se resuelve en la BD y no en la interfaz: esconder el boton en el frontend no
-- impide el mismo UPDATE por la API REST, que esta expuesta.

-- ---------------------------------------------------------------------------
-- 1. Guarda
-- ---------------------------------------------------------------------------
-- Dos reglas, ambas sobre el cambio de estado_usuario:
--   a) Nadie cambia el estado de su propia cuenta. Ni bloquearse, ni darse de
--      baja, ni inactivarse. Un administrador que quiere irse le pide a otro
--      que lo haga; asi siempre queda un tercero con la llave.
--   b) No se puede sacar de ACTIVO al ultimo ADMINISTRADOR_SISTEMA activo.
--
-- La regla (b) mira roles, no permisos: el rol ADMINISTRADOR_SISTEMA es quien
-- tiene por definicion la gestion de usuarios (doc 01 §3), y comprobarlo por
-- rol es estable aunque manana se reasignen permisos sueltos.
create or replace function public.proteger_administracion()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admins_activos integer;
  v_es_admin boolean;
begin
  -- Solo interesa sacar a alguien de ACTIVO.
  if new.estado_usuario = 'ACTIVO' or new.estado_usuario is not distinct from old.estado_usuario then
    return new;
  end if;

  -- (a) Autobloqueo. auth.uid() es null cuando corre una migracion, el seed o
  -- una Edge Function con service_role: en esos casos no aplica.
  if auth.uid() is not null and auth.uid() = new.id_usuario then
    raise exception 'No puedes cambiar el estado de tu propia cuenta. Pidele a otro administrador que lo haga.'
      using errcode = 'insufficient_privilege',
            hint = 'Esta guarda evita que el sistema se quede sin ningun administrador con acceso.';
  end if;

  -- (b) Ultimo administrador activo.
  select exists (
    select 1
      from public.usuario_rol ur
      join public.rol r on r.id_rol = ur.id_rol
     where ur.id_usuario = new.id_usuario
       and ur.estado_asignacion = 'ACTIVO'
       and r.nombre_rol = 'ADMINISTRADOR_SISTEMA'
       and r.estado_rol = 'ACTIVO'
  ) into v_es_admin;

  if v_es_admin then
    select count(distinct us.id_usuario)
      into v_admins_activos
      from public.usuario_sistema us
      join public.usuario_rol ur on ur.id_usuario = us.id_usuario
      join public.rol r on r.id_rol = ur.id_rol
     where us.estado_usuario = 'ACTIVO'
       and us.id_usuario <> new.id_usuario
       and ur.estado_asignacion = 'ACTIVO'
       and r.nombre_rol = 'ADMINISTRADOR_SISTEMA'
       and r.estado_rol = 'ACTIVO';

    if v_admins_activos = 0 then
      raise exception 'No se puede dejar el sistema sin ningun administrador activo: % es el ultimo.', new.nombre_usuario
        using errcode = 'insufficient_privilege',
              hint = 'Crea o activa otra cuenta con rol ADMINISTRADOR_SISTEMA antes de bloquear esta.';
    end if;
  end if;

  return new;
end;
$$;

comment on function public.proteger_administracion() is
  'Impide que un usuario cambie el estado de su propia cuenta y que se saque de ACTIVO al ultimo ADMINISTRADOR_SISTEMA.';

-- BEFORE: tiene que abortar antes de que trg_sincronizar_estado_auth (AFTER)
-- llegue a escribir banned_until y a borrar las sesiones.
drop trigger if exists trg_proteger_administracion on public.usuario_sistema;
create trigger trg_proteger_administracion
before update of estado_usuario on public.usuario_sistema
for each row execute function public.proteger_administracion();

-- ---------------------------------------------------------------------------
-- 2. Misma proteccion sobre el rol
-- ---------------------------------------------------------------------------
-- Quitarle el rol ADMINISTRADOR_SISTEMA al ultimo admin deja el sistema igual
-- de huerfano que bloquearlo, y esa via no pasa por estado_usuario.
create or replace function public.proteger_rol_administrador()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_es_rol_admin boolean;
  v_admins_restantes integer;
begin
  select r.nombre_rol = 'ADMINISTRADOR_SISTEMA' into v_es_rol_admin
    from public.rol r where r.id_rol = old.id_rol;

  if not coalesce(v_es_rol_admin, false) then
    return new;
  end if;

  -- Solo si la asignacion deja de estar activa.
  if new.estado_asignacion = 'ACTIVO' then
    return new;
  end if;

  select count(distinct us.id_usuario)
    into v_admins_restantes
    from public.usuario_sistema us
    join public.usuario_rol ur on ur.id_usuario = us.id_usuario
    join public.rol r on r.id_rol = ur.id_rol
   where us.estado_usuario = 'ACTIVO'
     and us.id_usuario <> old.id_usuario
     and ur.estado_asignacion = 'ACTIVO'
     and r.nombre_rol = 'ADMINISTRADOR_SISTEMA'
     and r.estado_rol = 'ACTIVO';

  if v_admins_restantes = 0 then
    raise exception 'No se puede revocar el rol de administrador al ultimo ADMINISTRADOR_SISTEMA activo.'
      using errcode = 'insufficient_privilege',
            hint = 'Asigna el rol a otra cuenta activa antes de revocar esta.';
  end if;

  return new;
end;
$$;

comment on function public.proteger_rol_administrador() is
  'Impide revocar el rol ADMINISTRADOR_SISTEMA al ultimo usuario activo que lo tiene.';

drop trigger if exists trg_proteger_rol_administrador on public.usuario_rol;
create trigger trg_proteger_rol_administrador
before update of estado_asignacion on public.usuario_rol
for each row execute function public.proteger_rol_administrador();

-- ---------------------------------------------------------------------------
-- 3. Permisos
-- ---------------------------------------------------------------------------
revoke execute on function public.proteger_administracion(), public.proteger_rol_administrador()
from public, anon, authenticated;
