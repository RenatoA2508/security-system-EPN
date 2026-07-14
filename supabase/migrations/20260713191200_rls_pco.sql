-- Politicas RLS: modulo PCO (incluye guardia_punto_control, §D11).
-- Fuente: docs/02_MATRIZ_PERMISOS_RLS.md "Modulo PCO".

-- ===== zona =====
-- CAC y GUA sin restriccion de fila en esta tabla (a diferencia de
-- dispositivo/guardia_punto_control): se usa el helper operativo generico.
create policy zona_select on public.zona
  for select using (
    auth.tiene_permiso('ADM_MODULO_ACCEDER')
    or auth.tiene_permiso('PCO_ZONA_SELECT')
    or auth.tiene_acceso_operativo_cac()
  );
create policy zona_insert_pco on public.zona
  for insert with check (auth.tiene_permiso('PCO_ZONA_INSERT'));
create policy zona_update_pco on public.zona
  for update using (auth.tiene_permiso('PCO_ZONA_UPDATE'))
  with check (auth.tiene_permiso('PCO_ZONA_UPDATE'));

-- ===== punto_control =====
create policy punto_control_select on public.punto_control
  for select using (
    auth.tiene_permiso('ADM_MODULO_ACCEDER')
    or auth.tiene_permiso('PCO_PUNTO_CONTROL_SELECT')
    or auth.tiene_acceso_operativo_cac()
  );
create policy punto_control_insert_pco on public.punto_control
  for insert with check (auth.tiene_permiso('PCO_PUNTO_CONTROL_INSERT'));
create policy punto_control_update_pco on public.punto_control
  for update using (auth.tiene_permiso('PCO_PUNTO_CONTROL_UPDATE'))
  with check (auth.tiene_permiso('PCO_PUNTO_CONTROL_UPDATE'));

-- ===== dispositivo =====
-- CAC (supervisor) sin restriccion; GUA (footnote7) solo dispositivos de sus
-- puntos de control activos.
create policy dispositivo_select_amplio on public.dispositivo
  for select using (
    auth.tiene_permiso('ADM_MODULO_ACCEDER')
    or auth.tiene_permiso('PCO_DISPOSITIVO_SELECT')
    or auth.tiene_permiso('CAC_EVENTO_SELECT')
  );
create policy dispositivo_select_guardia on public.dispositivo
  for select using (
    auth.tiene_permiso('CAC_EVENTO_SELECT_PUNTO_ASIGNADO')
    and dispositivo.id_punto_control in (select auth.puntos_control_asignados())
  );
create policy dispositivo_insert_pco on public.dispositivo
  for insert with check (auth.tiene_permiso('PCO_DISPOSITIVO_INSERT'));
create policy dispositivo_update_pco on public.dispositivo
  for update using (auth.tiene_permiso('PCO_DISPOSITIVO_UPDATE'))
  with check (auth.tiene_permiso('PCO_DISPOSITIVO_UPDATE'));

-- ===== guardia_punto_control (§D11) =====
-- PCO y CAC administran asignaciones (RESPONSABLE_CONTROL_ACCESOS tambien
-- organiza la operacion diaria); el guardia solo ve las suyas (footnote7) y
-- nunca puede auto-asignarse (sin INSERT/UPDATE para GUA).
create policy guardia_punto_control_select_amplio on public.guardia_punto_control
  for select using (
    auth.tiene_permiso('ADM_MODULO_ACCEDER')
    or auth.tiene_permiso('PCO_ASIGNACION_SELECT')
    or auth.tiene_permiso('CAC_ASIGNACION_SELECT')
  );
create policy guardia_punto_control_select_propia on public.guardia_punto_control
  for select using (
    auth.tiene_permiso('CAC_ASIGNACION_SELECT_PROPIA')
    and guardia_punto_control.id_usuario = auth.uid()
  );
create policy guardia_punto_control_insert_pco on public.guardia_punto_control
  for insert with check (auth.tiene_permiso('PCO_ASIGNACION_INSERT'));
create policy guardia_punto_control_insert_cac on public.guardia_punto_control
  for insert with check (auth.tiene_permiso('CAC_ASIGNACION_INSERT'));
create policy guardia_punto_control_update_pco on public.guardia_punto_control
  for update using (auth.tiene_permiso('PCO_ASIGNACION_UPDATE'))
  with check (auth.tiene_permiso('PCO_ASIGNACION_UPDATE'));
create policy guardia_punto_control_update_cac on public.guardia_punto_control
  for update using (auth.tiene_permiso('CAC_ASIGNACION_UPDATE'))
  with check (auth.tiene_permiso('CAC_ASIGNACION_UPDATE'));
