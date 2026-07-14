-- Autenticacion: bootstrap auth.users -> usuario_sistema, resolucion de
-- permisos efectivos y registro de sesion.
-- Fuente: docs/01_AUTENTICACION_Y_ROLES.md §2, docs/02_MATRIZ_PERMISOS_RLS.md,
-- docs/03_DECISIONES_Y_CORRECCIONES.md §D12, §D14.

-- §D12: el trigger no puede adivinar la persona; viaja en raw_user_meta_data.
-- Orden obligatorio: primero se crea la persona, despues la cuenta de Auth.
create or replace function public.crear_usuario_sistema()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id_persona uuid;
  v_nombre_usuario text;
begin
  v_id_persona := (new.raw_user_meta_data ->> 'id_persona')::uuid;
  v_nombre_usuario := new.raw_user_meta_data ->> 'nombre_usuario';

  if v_id_persona is null then
    raise exception 'raw_user_meta_data.id_persona es obligatorio para crear usuario_sistema (auth.users.id=%)', new.id;
  end if;

  if v_nombre_usuario is null then
    raise exception 'raw_user_meta_data.nombre_usuario es obligatorio para crear usuario_sistema (auth.users.id=%)', new.id;
  end if;

  insert into public.usuario_sistema (id_usuario, id_persona, nombre_usuario, correo_electronico, estado_usuario)
  values (new.id, v_id_persona, v_nombre_usuario, new.email, 'ACTIVO');

  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.crear_usuario_sistema();

-- correo_electronico va "espejado" desde auth.users.email (§2 doc 01).
create or replace function public.sincronizar_correo_usuario_sistema()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.email is distinct from old.email then
    update public.usuario_sistema
       set correo_electronico = new.email,
           fecha_modificacion = now()
     where id_usuario = new.id;
  end if;
  return new;
end;
$$;

create trigger on_auth_user_email_updated
after update on auth.users
for each row execute function public.sincronizar_correo_usuario_sistema();

-- public.tiene_permiso: resuelve auth.uid() -> usuario_sistema -> usuario_rol
-- (activos) -> rol_permiso (activos) -> permiso (activo). STABLE + SECURITY
-- DEFINER: las politicas RLS la invocan sin poder ver rol_permiso/permiso
-- directamente. No copia permisos al JWT: se leen en vivo (revocacion
-- inmediata, §2 doc 01).
create or replace function public.tiene_permiso(p_codigo text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
      from public.usuario_rol ur
      join public.rol r on r.id_rol = ur.id_rol
      join public.rol_permiso rp on rp.id_rol = r.id_rol
      join public.permiso p on p.id_permiso = rp.id_permiso
     where ur.id_usuario = auth.uid()
       and ur.estado_asignacion = 'ACTIVO'
       and r.estado_rol = 'ACTIVO'
       and rp.estado_asignacion = 'ACTIVO'
       and p.estado_permiso = 'ACTIVO'
       and p.codigo_permiso = p_codigo
  );
$$;

grant execute on function public.tiene_permiso(text) to authenticated;

-- public.permisos_efectivos: conjunto completo de codigo_permiso del usuario
-- actual (docs/01_AUTENTICACION_Y_ROLES.md §2). Base para allowed_modules.
create or replace function public.permisos_efectivos()
returns setof text
language sql
stable
security definer
set search_path = public
as $$
  select distinct p.codigo_permiso
    from public.usuario_rol ur
    join public.rol r on r.id_rol = ur.id_rol
    join public.rol_permiso rp on rp.id_rol = r.id_rol
    join public.permiso p on p.id_permiso = rp.id_permiso
   where ur.id_usuario = auth.uid()
     and ur.estado_asignacion = 'ACTIVO'
     and r.estado_rol = 'ACTIVO'
     and rp.estado_asignacion = 'ACTIVO'
     and p.estado_permiso = 'ACTIVO';
$$;

grant execute on function public.permisos_efectivos() to authenticated;

-- allowed_modules: un modulo entra solo si el usuario tiene su permiso
-- *_MODULO_ACCEDER (docs/01_AUTENTICACION_Y_ROLES.md §2).
create or replace function public.allowed_modules()
returns text[]
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(array_agg(distinct split_part(codigo_permiso, '_', 1)), array[]::text[])
    from public.permisos_efectivos() as codigo_permiso
   where codigo_permiso like '%\_MODULO\_ACCEDER' escape '\';
$$;

grant execute on function public.allowed_modules() to authenticated;

-- registrar_sesion: RPC llamada justo despues del login exitoso (§D14).
-- Ninguna fila de sesion se inserta por INSERT directo (ver matriz RLS, sin
-- columna C para sesion): la unica via es esta funcion SECURITY DEFINER.
create or replace function public.registrar_sesion(p_ip_origen text default null, p_recordar_sesion boolean default false)
returns public.sesion
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tiempo_sesion_min integer;
  v_row public.sesion;
begin
  if auth.uid() is null then
    raise exception 'registrar_sesion requiere un usuario autenticado';
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

grant execute on function public.registrar_sesion(text, boolean) to authenticated;
