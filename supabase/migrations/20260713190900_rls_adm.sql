-- Politicas RLS: modulo ADM (13 tablas).
-- Fuente: docs/02_MATRIZ_PERMISOS_RLS.md "Modulo ADM".

-- ===== persona =====
create policy persona_select_adm on public.persona
  for select using (auth.tiene_permiso('ADM_PERSONA_SELECT'));
create policy persona_select_gpi on public.persona
  for select using (auth.tiene_permiso('GPI_PERSONA_SELECT'));
create policy persona_select_gpe on public.persona
  for select using (auth.tiene_permiso('GPE_PERSONA_SELECT'));
-- CAC/GUA: sin codigo dedicado; se usa CAC_VALIDACION_EJECUTAR (docs/99 E6).
create policy persona_select_cac on public.persona
  for select using (auth.tiene_permiso('CAC_VALIDACION_EJECUTAR'));

-- GPI solo crea personal INTERNA; GPE y el guardia solo EXTERNA (§D6).
create policy persona_insert_gpi on public.persona
  for insert with check (auth.tiene_permiso('GPI_PERSONA_INSERT') and tipo_persona = 'INTERNA');
create policy persona_insert_gpe on public.persona
  for insert with check (auth.tiene_permiso('GPE_PERSONA_INSERT') and tipo_persona = 'EXTERNA');
create policy persona_insert_guardia on public.persona
  for insert with check (auth.tiene_permiso('CAC_PERSONA_EXTERNA_INSERT') and tipo_persona = 'EXTERNA');

create policy persona_update_adm on public.persona
  for update using (auth.tiene_permiso('ADM_PERSONA_UPDATE'))
  with check (auth.tiene_permiso('ADM_PERSONA_UPDATE'));
create policy persona_update_gpi on public.persona
  for update using (auth.tiene_permiso('GPI_PERSONA_UPDATE'))
  with check (auth.tiene_permiso('GPI_PERSONA_UPDATE'));
create policy persona_update_gpe on public.persona
  for update using (auth.tiene_permiso('GPE_PERSONA_UPDATE'))
  with check (auth.tiene_permiso('GPE_PERSONA_UPDATE'));

-- ===== empresa =====
-- Sin codigo GPI_EMPRESA_SELECT/GPE_EMPRESA_SELECT (docs/99 E6): se usa el
-- OR de los *_MODULO_ACCEDER que la fila permite (ADM, GPI, GPE).
create policy empresa_select on public.empresa
  for select using (
    auth.tiene_permiso('ADM_MODULO_ACCEDER')
    or auth.tiene_permiso('GPI_MODULO_ACCEDER')
    or auth.tiene_permiso('GPE_MODULO_ACCEDER')
  );
create policy empresa_insert_adm on public.empresa
  for insert with check (auth.tiene_permiso('ADM_EMPRESA_INSERT'));
create policy empresa_update_adm on public.empresa
  for update using (auth.tiene_permiso('ADM_EMPRESA_UPDATE'))
  with check (auth.tiene_permiso('ADM_EMPRESA_UPDATE'));

-- ===== categoria_persona =====
-- L universal para los 7 roles (docs/99 E6): auth.tiene_algun_modulo().
create policy categoria_persona_select on public.categoria_persona
  for select using (auth.tiene_algun_modulo());
create policy categoria_persona_insert_adm on public.categoria_persona
  for insert with check (auth.tiene_permiso('ADM_CATEGORIA_INSERT'));
create policy categoria_persona_update_adm on public.categoria_persona
  for update using (auth.tiene_permiso('ADM_CATEGORIA_UPDATE'))
  with check (auth.tiene_permiso('ADM_CATEGORIA_UPDATE'));

-- ===== usuario_sistema =====
-- "Cuenta propia unicamente" (doc01 §3): cualquier usuario autenticado ve su
-- propia fila; ADM_USUARIO_SELECT da visibilidad total (ADMIN y DIR via wildcard).
create policy usuario_sistema_select on public.usuario_sistema
  for select using (id_usuario = auth.uid() or auth.tiene_permiso('ADM_USUARIO_SELECT'));
create policy usuario_sistema_insert_adm on public.usuario_sistema
  for insert with check (auth.tiene_permiso('ADM_USUARIO_INSERT'));
create policy usuario_sistema_update_adm on public.usuario_sistema
  for update using (auth.tiene_permiso('ADM_USUARIO_UPDATE'))
  with check (auth.tiene_permiso('ADM_USUARIO_UPDATE'));

-- ===== sesion =====
-- Sin codigo ADM_SESION_SELECT (docs/99 E6): se reutiliza ADM_USUARIO_SELECT,
-- misma fila L/L/L2.../L2 que usuario_sistema en la matriz. Sin INSERT/UPDATE
-- por politica: la unica via de escritura es la RPC registrar_sesion
-- (SECURITY DEFINER, bloque 2), que bypassea RLS como dueña de la tabla.
create policy sesion_select on public.sesion
  for select using (id_usuario = auth.uid() or auth.tiene_permiso('ADM_USUARIO_SELECT'));

-- ===== rol / permiso / usuario_rol / rol_permiso =====
create policy rol_select on public.rol
  for select using (auth.tiene_permiso('ADM_ROL_SELECT'));
create policy rol_insert_adm on public.rol
  for insert with check (auth.tiene_permiso('ADM_ROL_INSERT'));
create policy rol_update_adm on public.rol
  for update using (auth.tiene_permiso('ADM_ROL_UPDATE'))
  with check (auth.tiene_permiso('ADM_ROL_UPDATE'));

create policy permiso_select on public.permiso
  for select using (auth.tiene_permiso('ADM_PERMISO_SELECT'));
create policy permiso_insert_adm on public.permiso
  for insert with check (auth.tiene_permiso('ADM_PERMISO_INSERT'));
create policy permiso_update_adm on public.permiso
  for update using (auth.tiene_permiso('ADM_PERMISO_UPDATE'))
  with check (auth.tiene_permiso('ADM_PERMISO_UPDATE'));

create policy usuario_rol_select on public.usuario_rol
  for select using (auth.tiene_permiso('ADM_USUARIO_ROL_SELECT'));
create policy usuario_rol_insert_adm on public.usuario_rol
  for insert with check (auth.tiene_permiso('ADM_USUARIO_ROL_INSERT'));
create policy usuario_rol_update_adm on public.usuario_rol
  for update using (auth.tiene_permiso('ADM_USUARIO_ROL_UPDATE'))
  with check (auth.tiene_permiso('ADM_USUARIO_ROL_UPDATE'));

create policy rol_permiso_select on public.rol_permiso
  for select using (auth.tiene_permiso('ADM_ROL_PERMISO_SELECT'));
create policy rol_permiso_insert_adm on public.rol_permiso
  for insert with check (auth.tiene_permiso('ADM_ROL_PERMISO_INSERT'));
create policy rol_permiso_update_adm on public.rol_permiso
  for update using (auth.tiene_permiso('ADM_ROL_PERMISO_UPDATE'))
  with check (auth.tiene_permiso('ADM_ROL_PERMISO_UPDATE'));

-- ===== parametro_sistema =====
-- L universal (docs/99 E6): auth.tiene_algun_modulo().
create policy parametro_sistema_select on public.parametro_sistema
  for select using (auth.tiene_algun_modulo());
create policy parametro_sistema_insert_adm on public.parametro_sistema
  for insert with check (auth.tiene_permiso('ADM_PARAMETRO_INSERT'));
create policy parametro_sistema_update_adm on public.parametro_sistema
  for update using (auth.tiene_permiso('ADM_PARAMETRO_UPDATE'))
  with check (auth.tiene_permiso('ADM_PARAMETRO_UPDATE'));

-- ===== bitacora_sistema =====
-- Sin INSERT por politica para ningun rol: solo triggers/funciones
-- SECURITY DEFINER escriben aqui (bloque 5). UPDATE ya revocado a nivel de tabla.
create policy bitacora_sistema_select on public.bitacora_sistema
  for select using (auth.tiene_permiso('ADM_BITACORA_SELECT'));

-- ===== vehiculo =====
-- CAC sin codigo dedicado (docs/99 E6): se usa CAC_EVENTO_SELECT.
create policy vehiculo_select on public.vehiculo
  for select using (
    auth.tiene_permiso('ADM_VEHICULO_SELECT')
    or auth.tiene_permiso('GPI_VEHICULO_SELECT')
    or auth.tiene_permiso('GPE_VEHICULO_SELECT')
    or auth.tiene_permiso('CAC_EVENTO_SELECT')
  );
create policy vehiculo_insert_adm on public.vehiculo
  for insert with check (auth.tiene_permiso('ADM_VEHICULO_INSERT'));
create policy vehiculo_insert_gpi on public.vehiculo
  for insert with check (auth.tiene_permiso('GPI_VEHICULO_INSERT'));
create policy vehiculo_insert_gpe on public.vehiculo
  for insert with check (auth.tiene_permiso('GPE_VEHICULO_INSERT'));
-- Solo ADM actualiza/da de baja (§3.1 nota de consolidacion): GPI/GPE sin UPDATE.
create policy vehiculo_update_adm on public.vehiculo
  for update using (auth.tiene_permiso('ADM_VEHICULO_UPDATE'))
  with check (auth.tiene_permiso('ADM_VEHICULO_UPDATE'));

-- ===== persona_vehiculo =====
create policy persona_vehiculo_select on public.persona_vehiculo
  for select using (
    auth.tiene_permiso('ADM_PERSONA_VEHICULO_SELECT')
    or auth.tiene_permiso('GPI_PERSONA_VEHICULO_SELECT')
    or auth.tiene_permiso('GPE_PERSONA_VEHICULO_SELECT')
    or auth.tiene_acceso_operativo_cac()
  );
create policy persona_vehiculo_insert_adm on public.persona_vehiculo
  for insert with check (auth.tiene_permiso('ADM_PERSONA_VEHICULO_INSERT'));
create policy persona_vehiculo_insert_gpi on public.persona_vehiculo
  for insert with check (auth.tiene_permiso('GPI_PERSONA_VEHICULO_INSERT'));
create policy persona_vehiculo_insert_gpe on public.persona_vehiculo
  for insert with check (auth.tiene_permiso('GPE_PERSONA_VEHICULO_INSERT'));
create policy persona_vehiculo_update_adm on public.persona_vehiculo
  for update using (auth.tiene_permiso('ADM_PERSONA_VEHICULO_UPDATE'))
  with check (auth.tiene_permiso('ADM_PERSONA_VEHICULO_UPDATE'));
create policy persona_vehiculo_update_gpi on public.persona_vehiculo
  for update using (auth.tiene_permiso('GPI_PERSONA_VEHICULO_UPDATE'))
  with check (auth.tiene_permiso('GPI_PERSONA_VEHICULO_UPDATE'));
create policy persona_vehiculo_update_gpe on public.persona_vehiculo
  for update using (auth.tiene_permiso('GPE_PERSONA_VEHICULO_UPDATE'))
  with check (auth.tiene_permiso('GPE_PERSONA_VEHICULO_UPDATE'));
