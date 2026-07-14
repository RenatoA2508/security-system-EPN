-- scripts/pruebas_rls_por_rol.sql
--
-- Verificación CONDUCTUAL de RLS (doc 02): impersona a un usuario real cambiando
-- a rol `authenticated` y fijando el claim JWT `sub`, luego observa qué filas ve /
-- qué escrituras se permiten. Es la contraparte "en vivo" de la validación de la
-- matriz como dato que hace scripts/pruebas_cobertura_docs.sql (módulo F).
--
-- Requiere las dos cuentas de arranque sembradas (admin + guardia demo). Resuelve
-- sus UUID por rol, así corre igual en local y en el remoto.
--
-- Cada bloque termina en ROLLBACK: no modifica la base. En el módulo G4 se ESPERA
-- que el INSERT falle con "new row violates row-level security policy": eso es un
-- ÉXITO de la prueba (la política WITH CHECK del guardia rechaza personas INTERNAS).
--
-- Ejecutar en cloud vía MCP (execute_sql) bloque por bloque, o en local:
--   psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -f scripts/pruebas_rls_por_rol.sql

\echo '=== G1 — GUARDIA_SEGURIDAD: visibilidad de filas (RLS SELECT) ==='
-- Espera: ve categoria_persona y persona (L); 0 en rol, registro_biometrico y
-- permiso (sin acceso, aunque existan filas); allowed_modules = {CAC}.
begin;
select set_config('request.jwt.claims',
  (select json_build_object('sub', us.id_usuario, 'role','authenticated')::text
     from public.usuario_sistema us
     join public.usuario_rol ur on ur.id_usuario=us.id_usuario and ur.estado_asignacion='ACTIVO'
     join public.rol r on r.id_rol=ur.id_rol and r.nombre_rol='GUARDIA_SEGURIDAD' limit 1),
  true);
set local role authenticated;
select
  'GUARDIA_SEGURIDAD'                                as rol_simulado,
  (select count(*) from public.categoria_persona)   as ve_categoria_persona,  -- >0 (L)
  (select count(*) from public.persona)             as ve_persona,            -- >0 (L)
  (select count(*) from public.rol)                 as ve_rol,                -- 0 (sin acceso)
  (select count(*) from public.registro_biometrico) as ve_biometrico,         -- 0 (sin permiso)
  (select count(*) from public.permiso)             as ve_permiso,            -- 0 (sin acceso)
  public.allowed_modules()                          as allowed_modules;       -- {CAC}
rollback;

\echo '=== G2 — ADMINISTRADOR_SISTEMA: visibilidad de filas (RLS SELECT) ==='
-- Espera: ve rol (7), permiso (100), registro_biometrico (metadatos), usuario_sistema;
-- allowed_modules = {ADM}.
begin;
select set_config('request.jwt.claims',
  (select json_build_object('sub', us.id_usuario, 'role','authenticated')::text
     from public.usuario_sistema us
     join public.usuario_rol ur on ur.id_usuario=us.id_usuario and ur.estado_asignacion='ACTIVO'
     join public.rol r on r.id_rol=ur.id_rol and r.nombre_rol='ADMINISTRADOR_SISTEMA' limit 1),
  true);
set local role authenticated;
select
  'ADMINISTRADOR_SISTEMA'                            as rol_simulado,
  (select count(*) from public.rol)                 as ve_rol,          -- 7 (L)
  (select count(*) from public.permiso)             as ve_permiso,      -- 100 (L)
  (select count(*) from public.registro_biometrico) as ve_biometrico,   -- metadatos (L)
  (select count(*) from public.usuario_sistema)     as ve_usuarios,     -- (L C A)
  public.allowed_modules()                          as allowed_modules; -- {ADM}
rollback;

\echo '=== G3 — GUARDIA crea persona EXTERNA: DEBE permitirse (D6/D20) ==='
begin;
select set_config('request.jwt.claims',
  (select json_build_object('sub', us.id_usuario, 'role','authenticated')::text
     from public.usuario_sistema us
     join public.usuario_rol ur on ur.id_usuario=us.id_usuario and ur.estado_asignacion='ACTIVO'
     join public.rol r on r.id_rol=ur.id_rol and r.nombre_rol='GUARDIA_SEGURIDAD' limit 1),
  true);
set local role authenticated;
insert into public.persona(tipo_persona,id_categoria,cedula,nombres,apellidos,correo,estado)
  select 'EXTERNA', id_categoria, '1700000950','GuardiaCrea','Externa','gce@ex.com','ACTIVO'
    from public.categoria_persona where codigo_categoria='VISITANTE'
returning tipo_persona as guardia_creo_externa;  -- espera: EXTERNA
rollback;

\echo '=== G4 — GUARDIA crea persona INTERNA: DEBE ser RECHAZADO por RLS (D6/D20) ==='
-- Se espera el ERROR: new row violates row-level security policy for table "persona".
begin;
select set_config('request.jwt.claims',
  (select json_build_object('sub', us.id_usuario, 'role','authenticated')::text
     from public.usuario_sistema us
     join public.usuario_rol ur on ur.id_usuario=us.id_usuario and ur.estado_asignacion='ACTIVO'
     join public.rol r on r.id_rol=ur.id_rol and r.nombre_rol='GUARDIA_SEGURIDAD' limit 1),
  true);
set local role authenticated;
insert into public.persona(tipo_persona,id_categoria,cedula,nombres,apellidos,correo,estado)
  select 'INTERNA', id_categoria, '1700000951','GuardiaCrea','Interna','gci@epn.edu.ec','ACTIVO'
    from public.categoria_persona where codigo_categoria='DOCENTE'
returning tipo_persona as no_deberia_pasar;
rollback;
