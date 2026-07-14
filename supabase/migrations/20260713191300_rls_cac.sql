-- Politicas RLS: modulo CAC.
-- Fuente: docs/02_MATRIZ_PERMISOS_RLS.md "Modulo CAC".

-- ===== regla_acceso =====
-- El guardia NO tiene CAC_REGLA_* ("no puede editar las reglas que lo
-- autorizan"); su lectura se resuelve via CAC_VALIDACION_EJECUTAR.
create policy regla_acceso_select on public.regla_acceso
  for select using (
    public.tiene_permiso('ADM_MODULO_ACCEDER')
    or public.tiene_permiso('CAC_REGLA_SELECT')
    or public.tiene_permiso('CAC_VALIDACION_EJECUTAR')
  );
create policy regla_acceso_insert_cac on public.regla_acceso
  for insert with check (public.tiene_permiso('CAC_REGLA_INSERT'));
create policy regla_acceso_update_cac on public.regla_acceso
  for update using (public.tiene_permiso('CAC_REGLA_UPDATE'))
  with check (public.tiene_permiso('CAC_REGLA_UPDATE'));

-- ===== evento_acceso =====
-- Historico: sin UPDATE para nadie (ya revocado a nivel de tabla). El
-- registro automatico (DISP) pasa por la Edge Function con service_role,
-- que bypassea RLS por diseño; no necesita politica propia.
create policy evento_acceso_select_amplio on public.evento_acceso
  for select using (
    public.tiene_permiso('ADM_MODULO_ACCEDER')
    or public.tiene_permiso('GPI_MODULO_ACCEDER')
    or public.tiene_permiso('GPE_MODULO_ACCEDER')
    or public.tiene_permiso('CAC_EVENTO_SELECT')
  );

-- SQL exacto de docs/02_MATRIZ_PERMISOS_RLS.md nota 8 (guardia: solo su punto
-- de control asignado; sin asignacion activa, no ve ningun evento).
create policy evento_guardia_select on public.evento_acceso
  for select using (
    public.tiene_permiso('CAC_EVENTO_SELECT_PUNTO_ASIGNADO')
    and evento_acceso.id_punto_control in (
      select gpc.id_punto_control
        from public.guardia_punto_control gpc
       where gpc.id_usuario = auth.uid()
         and gpc.estado_asignacion = 'ACTIVA'
    )
  );

-- Registro manual de entrada/salida: exclusivo del guardia (docs/99 E8; el
-- supervisor CAC solo tiene L, sin C, segun la matriz por tabla).
create policy evento_acceso_insert_guardia on public.evento_acceso
  for insert with check (public.tiene_permiso('CAC_EVENTO_INSERT'));

-- ===== alerta_seguridad =====
-- Nadie tiene INSERT por politica (§D4): nacen exclusivamente de triggers /
-- funciones SECURITY DEFINER (bloque 5), que al pertenecer al dueño de la
-- tabla bypassean RLS.
create policy alerta_seguridad_select_amplio on public.alerta_seguridad
  for select using (
    public.tiene_permiso('ADM_MODULO_ACCEDER')
    or (public.tiene_permiso('CAC_ALERTA_SELECT') and public.tiene_permiso('CAC_EVENTO_SELECT'))
  );

-- El guardia (footnote8) solo ve alertas de su punto de control asignado;
-- CAC_ALERTA_SELECT lo tienen tanto CAC como GUA, asi que el discriminador es
-- CAC_EVENTO_SELECT_PUNTO_ASIGNADO (exclusivo del guardia).
create policy alerta_seguridad_select_guardia on public.alerta_seguridad
  for select using (
    public.tiene_permiso('CAC_ALERTA_SELECT')
    and public.tiene_permiso('CAC_EVENTO_SELECT_PUNTO_ASIGNADO')
    and exists (
      select 1
        from public.evento_acceso ea
       where ea.id_evento = alerta_seguridad.id_evento
         and ea.id_punto_control in (select public.puntos_control_asignados())
    )
  );

-- Solo el Supervisor CAC atiende alertas (§D4).
create policy alerta_seguridad_update_cac on public.alerta_seguridad
  for update using (public.tiene_permiso('CAC_ALERTA_ATENDER'))
  with check (public.tiene_permiso('CAC_ALERTA_ATENDER'));
