-- ADM · Un solo rol activo por cuenta, y nadie se quita a sí mismo el de administrador.
--
-- (1) SOLAPAMIENTO DE ROLES
--
-- El modelo permitía varios roles activos y eso producía un fallo real, no teórico:
-- `guardia_demo` tenía GUARDIA_SEGURIDAD + RESPONSABLE_PERSONAL_INTERNO, y como la vista
-- de Garita REEMPLAZA toda la aplicación (App.tsx: `esGuardia ? <GuardiaView/> : …`), esa
-- cuenta no podía entrar a GPI de ninguna manera. El rol extra no daba acceso a nada: solo
-- creaba la duda de "¿qué ventana se abre?".
--
-- El multi-rol existe en sistemas reales, pero siempre con un selector visible de "actúas
-- como X". Lo que no existe en ninguno es una precedencia implícita e invisible como esta.
-- El equipo eligió la vía simple: una cuenta, un rol. Quien necesite dos funciones, dos
-- cuentas.
--
-- (2) AUTO-REVOCACIÓN DEL ROL DE ADMINISTRADOR
--
-- `proteger_rol_administrador` ya existía, pero solo cubría al ÚLTIMO administrador. Con
-- dos administradores, cualquiera podía revocarse el suyo y perder el acceso a ADM sin
-- posibilidad de deshacerlo por sí mismo. Es el mismo agujero que `proteger_administracion`
-- ya tapaba para el estado de la cuenta (§a), pero nadie lo había tapado para el rol.
--
-- Hoy `admin` es el único administrador, así que la guarda del último lo salvaba por
-- casualidad. Eso no es una protección: es una coincidencia.

-- ---------------------------------------------------------------------------
-- 1. Dejar los datos en el invariante ANTES de imponerlo.
-- ---------------------------------------------------------------------------
-- guardia_demo se queda con GUARDIA_SEGURIDAD, que es para lo que se usa (la Garita).
-- El rol de GPI que tenía de más lo cubre lenin.amangandi.
update public.usuario_rol ur
   set estado_asignacion = 'REVOCADO',
       fecha_revocacion = now(),
       observacion = coalesce(observacion || ' · ', '') ||
                     'Revocado al imponer un solo rol activo por cuenta: la vista de Garita ocupa toda la pantalla, así que este rol no daba acceso a nada.'
  from public.usuario_sistema us, public.rol r
 where ur.id_usuario = us.id_usuario
   and r.id_rol = ur.id_rol
   and ur.estado_asignacion = 'ACTIVO'
   and us.nombre_usuario = 'guardia_demo'
   and r.nombre_rol <> 'GUARDIA_SEGURIDAD';

-- ---------------------------------------------------------------------------
-- 2. El invariante, en la base y no solo en la pantalla.
-- ---------------------------------------------------------------------------
create unique index if not exists usuario_rol_un_activo_por_usuario
  on public.usuario_rol (id_usuario)
  where estado_asignacion = 'ACTIVO';

comment on index public.usuario_rol_un_activo_por_usuario is
  'Una cuenta, un rol activo. Ver migración adm_rol_unico_y_autorevocacion.';

-- ---------------------------------------------------------------------------
-- 3. Cambiar de rol es una operación atómica: revocar el anterior y asignar el nuevo.
--    Sin esto, el índice único obliga a la interfaz a hacer dos escrituras y a dejar la
--    cuenta sin rol si la segunda falla.
-- ---------------------------------------------------------------------------
create or replace function public.asignar_rol_unico(p_id_usuario uuid, p_id_rol uuid, p_observacion text default null)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_id_asignacion uuid;
begin
  if not public.tiene_permiso('ADM_USUARIO_ROL_INSERT') then
    raise exception 'No tienes permiso para asignar roles.'
      using errcode = 'insufficient_privilege';
  end if;

  -- Ya lo tiene activo: no se toca nada y se devuelve la asignación existente.
  select ur.id_usuario_rol into v_id_asignacion
    from public.usuario_rol ur
   where ur.id_usuario = p_id_usuario
     and ur.id_rol = p_id_rol
     and ur.estado_asignacion = 'ACTIVO';
  if found then
    return v_id_asignacion;
  end if;

  -- El trigger proteger_rol_administrador se encarga de impedir que esto deje al sistema
  -- sin administrador o que alguien se quite el suyo.
  update public.usuario_rol
     set estado_asignacion = 'REVOCADO',
         fecha_revocacion = now(),
         observacion = coalesce(observacion || ' · ', '') || 'Sustituido al asignar otro rol.'
   where id_usuario = p_id_usuario
     and estado_asignacion = 'ACTIVO';

  insert into public.usuario_rol (id_usuario, id_rol, estado_asignacion, observacion)
  values (p_id_usuario, p_id_rol, 'ACTIVO', p_observacion)
  returning id_usuario_rol into v_id_asignacion;

  return v_id_asignacion;
end;
$$;

comment on function public.asignar_rol_unico(uuid, uuid, text) is
  'Cambia el rol de una cuenta en una sola operación: revoca el activo y asigna el nuevo.';

revoke all on function public.asignar_rol_unico(uuid, uuid, text) from public, anon;
grant execute on function public.asignar_rol_unico(uuid, uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 4. La guarda que faltaba: nadie se revoca su propio rol de administrador.
-- ---------------------------------------------------------------------------
create or replace function public.proteger_rol_administrador()
returns trigger
language plpgsql
security definer
set search_path = ''
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

  -- Solo si la asignación deja de estar activa.
  if new.estado_asignacion = 'ACTIVO' then
    return new;
  end if;

  -- (a) Auto-revocación. auth.uid() es null en migraciones, seed o service_role.
  --     Un administrador que se quita el rol pierde ADM y ya no puede devolvérselo:
  --     depende de que otro se lo restituya. Es una puerta que solo se abre por fuera.
  if auth.uid() is not null and auth.uid() = old.id_usuario then
    raise exception 'No puedes quitarte a ti mismo el rol de administrador del sistema.'
      using errcode = 'insufficient_privilege',
            hint = 'Si necesitas ceder la administración, pídele a otro administrador que te lo revoque después de asignárselo a él.';
  end if;

  -- (b) Último administrador activo.
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
    raise exception 'No se puede revocar el rol de administrador al último ADMINISTRADOR_SISTEMA activo.'
      using errcode = 'insufficient_privilege',
            hint = 'Asigna el rol a otra cuenta activa antes de revocar esta.';
  end if;

  return new;
end;
$$;
