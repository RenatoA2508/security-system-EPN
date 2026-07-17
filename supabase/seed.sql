-- Seed de bootstrap (SOLO desarrollo local, via `supabase db reset`).
--
-- Los datos de seguridad (rol, permiso, rol_permiso, categoria_persona,
-- parametro_sistema) YA NO viven aqui: se movieron a la migracion
-- 20260713192400_datos_seguridad.sql para que existan en todos los entornos
-- (el remoto se siembra via db push, no via este seed).
--
-- Este archivo solo crea las cuentas de arranque (§D13 admin + guardia demo)
-- insertando directamente en auth.users, patron que funciona en el stack
-- LOCAL. En el proyecto REMOTO estas dos cuentas se crean con la Auth Admin
-- API (ver scripts/seed_remoto.mjs), que garantiza usuarios validos para
-- GoTrue -- resolviendo la duda E5. El estado final (mismos UUIDs y filas)
-- es identico por ambas vias.

-- ================= BOOTSTRAP: PRIMER ADMINISTRADOR (§D13) =================
-- El ADMINISTRADOR_SISTEMA no tiene INSERT sobre persona (§D5): sin este seed
-- nadie podria crear la primera cuenta. Se inserta persona + auth.users (el
-- trigger on_auth_user_created crea usuario_sistema automaticamente) +
-- usuario_rol. UUIDs fijos para que el seed sea idempotente en cada reset.
do $$
declare
  v_admin_persona_id uuid := '00000000-0000-0000-0000-000000000001';
  v_admin_user_id uuid := '00000000-0000-0000-0000-000000000002';
  v_id_categoria_admin uuid;
  v_id_rol_admin uuid;
begin
  select id_categoria into v_id_categoria_admin
    from public.categoria_persona where codigo_categoria = 'ADMINISTRATIVO';

  insert into public.persona (
    id_persona, tipo_persona, id_categoria, cedula, nombres, apellidos, correo, estado
  ) values (
    v_admin_persona_id, 'INTERNA', v_id_categoria_admin, '1750000000',
    'Administrador', 'del Sistema', 'admin@epn.edu.ec', 'ACTIVO'
  )
  on conflict (id_persona) do nothing;

  if not exists (select 1 from auth.users where id = v_admin_user_id) then
    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
      confirmation_token, recovery_token, email_change_token_new, email_change
    ) values (
      '00000000-0000-0000-0000-000000000000',
      v_admin_user_id,
      'authenticated',
      'authenticated',
      'admin@epn.edu.ec',
      -- Contraseña placeholder de arranque; requiere_cambio_password se fuerza
      -- a true abajo. DEBE rotarse antes de cualquier despliegue real.
      extensions.crypt('CambiarInmediatamente#2026', extensions.gen_salt('bf')),
      now(),
      '{"provider":"email","providers":["email"]}',
      jsonb_build_object('id_persona', v_admin_persona_id, 'nombre_usuario', 'admin'),
      now(), now(),
      '', '', '', ''
    );
    -- El trigger on_auth_user_created (bloque 2) inserta automaticamente la
    -- fila correspondiente en usuario_sistema.
  end if;

  update public.usuario_sistema
     set requiere_cambio_password = true
   where id_usuario = v_admin_user_id;

  select id_rol into v_id_rol_admin from public.rol where nombre_rol = 'ADMINISTRADOR_SISTEMA';

  insert into public.usuario_rol (id_usuario, id_rol, estado_asignacion, fecha_asignacion)
  select v_admin_user_id, v_id_rol_admin, 'ACTIVO', now()
  where not exists (
    select 1 from public.usuario_rol
     where id_usuario = v_admin_user_id and id_rol = v_id_rol_admin and estado_asignacion = 'ACTIVO'
  );
end $$;

-- ================= BOOTSTRAP: GUARDIA DEMO + guardia_punto_control (§D11) ==
-- Sin al menos una fila de guardia_punto_control, la vista operativa del
-- guardia queda vacia en la demo. Se crea tambien una zona/punto_control
-- minimos para poder anclarla.
do $$
declare
  v_guardia_persona_id uuid := '00000000-0000-0000-0000-000000000003';
  v_guardia_user_id uuid := '00000000-0000-0000-0000-000000000004';
  v_zona_campus_id uuid := '00000000-0000-0000-0000-000000000005';
  v_punto_control_id uuid := '00000000-0000-0000-0000-000000000006';
  v_admin_user_id uuid := '00000000-0000-0000-0000-000000000002';
  v_id_categoria_trabajador uuid;
  v_id_rol_guardia uuid;
begin
  select id_categoria into v_id_categoria_trabajador
    from public.categoria_persona where codigo_categoria = 'TRABAJADOR';

  insert into public.persona (
    id_persona, tipo_persona, id_categoria, cedula, nombres, apellidos, correo, estado
  ) values (
    v_guardia_persona_id, 'INTERNA', v_id_categoria_trabajador, '1750000018',
    'Guardia', 'Demo', 'guardia.demo@epn.edu.ec', 'ACTIVO'
  )
  on conflict (id_persona) do nothing;

  if not exists (select 1 from auth.users where id = v_guardia_user_id) then
    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
      confirmation_token, recovery_token, email_change_token_new, email_change
    ) values (
      '00000000-0000-0000-0000-000000000000',
      v_guardia_user_id,
      'authenticated',
      'authenticated',
      'guardia.demo@epn.edu.ec',
      extensions.crypt('CambiarInmediatamente#2026', extensions.gen_salt('bf')),
      now(),
      '{"provider":"email","providers":["email"]}',
      jsonb_build_object('id_persona', v_guardia_persona_id, 'nombre_usuario', 'guardia_demo'),
      now(), now(),
      '', '', '', ''
    );
  end if;

  update public.usuario_sistema
     set requiere_cambio_password = true
   where id_usuario = v_guardia_user_id;

  select id_rol into v_id_rol_guardia from public.rol where nombre_rol = 'GUARDIA_SEGURIDAD';

  insert into public.usuario_rol (id_usuario, id_rol, estado_asignacion, fecha_asignacion)
  select v_guardia_user_id, v_id_rol_guardia, 'ACTIVO', now()
  where not exists (
    select 1 from public.usuario_rol
     where id_usuario = v_guardia_user_id and id_rol = v_id_rol_guardia and estado_asignacion = 'ACTIVO'
  );

  insert into public.zona (id_zona, nombre_zona, tipo_zona, estado_zona)
  values (v_zona_campus_id, 'Campus EPN (demo)', 'CAMPUS', 'ACTIVA')
  on conflict (id_zona) do nothing;

  insert into public.punto_control (id_punto_control, id_zona, nombre_punto, estado_punto)
  values (v_punto_control_id, v_zona_campus_id, 'Garita Principal (demo)', 'ACTIVO')
  on conflict (id_punto_control) do nothing;

  insert into public.guardia_punto_control (
    id_usuario, id_punto_control, turno, estado_asignacion, id_usuario_registro
  )
  select v_guardia_user_id, v_punto_control_id, 'MATUTINO', 'ACTIVA', v_admin_user_id
  where not exists (
    select 1 from public.guardia_punto_control
     where id_usuario = v_guardia_user_id
       and id_punto_control = v_punto_control_id
       and estado_asignacion = 'ACTIVA'
  );
end $$;
