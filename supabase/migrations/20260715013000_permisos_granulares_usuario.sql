-- Feedback ADM (docs/Req_Front/ADM_Nuevos_Requerimientos.md §7.2): las operaciones sensibles
-- sobre usuario_sistema estaban concentradas en ADM_USUARIO_UPDATE, dificultando mínimo
-- privilegio y auditoría específica. Se agregan permisos granulares para bloquear, desbloquear,
-- activar y dar de baja un usuario. "Restablecer contraseña" de otra cuenta requiere la Auth Admin
-- API (service_role) y se resuelve con una Edge Function nueva, no con RLS sobre esta tabla.
--
-- Asignar/revocar rol NO se duplica aquí: ya existen ADM_USUARIO_ROL_INSERT/UPDATE sobre la
-- tabla usuario_rol, que ya son granulares por sí mismos (tabla separada de usuario_sistema).

insert into public.permiso (codigo_permiso, descripcion)
values
  ('ADM_USUARIO_BLOQUEAR', 'Bloquear una cuenta de usuario del sistema'),
  ('ADM_USUARIO_DESBLOQUEAR', 'Desbloquear una cuenta de usuario del sistema'),
  ('ADM_USUARIO_ACTIVAR', 'Reactivar una cuenta de usuario del sistema'),
  ('ADM_USUARIO_DAR_BAJA', 'Dar de baja una cuenta de usuario del sistema'),
  ('ADM_USUARIO_RESETEAR_PASSWORD', 'Forzar el restablecimiento de contraseña de otra cuenta')
on conflict (codigo_permiso) do nothing;

insert into public.rol_permiso (id_rol, id_permiso, estado_asignacion)
select r.id_rol, p.id_permiso, 'ACTIVO'
from public.rol r
cross join public.permiso p
where r.nombre_rol = 'ADMINISTRADOR_SISTEMA'
  and p.codigo_permiso in ('ADM_USUARIO_BLOQUEAR', 'ADM_USUARIO_DESBLOQUEAR', 'ADM_USUARIO_ACTIVAR', 'ADM_USUARIO_DAR_BAJA', 'ADM_USUARIO_RESETEAR_PASSWORD')
  and not exists (
    select 1 from public.rol_permiso existente
    where existente.id_rol = r.id_rol and existente.id_permiso = p.id_permiso
  );

-- Políticas RLS adicionales (permissive: coexisten con usuario_sistema_update_adm) para que cada
-- transición de estado pueda autorizarse de forma independiente sin requerir ADM_USUARIO_UPDATE.
create policy usuario_sistema_bloquear on public.usuario_sistema
  for update using (tiene_permiso('ADM_USUARIO_BLOQUEAR')) with check (tiene_permiso('ADM_USUARIO_BLOQUEAR'));
create policy usuario_sistema_desbloquear on public.usuario_sistema
  for update using (tiene_permiso('ADM_USUARIO_DESBLOQUEAR')) with check (tiene_permiso('ADM_USUARIO_DESBLOQUEAR'));
create policy usuario_sistema_activar on public.usuario_sistema
  for update using (tiene_permiso('ADM_USUARIO_ACTIVAR')) with check (tiene_permiso('ADM_USUARIO_ACTIVAR'));
create policy usuario_sistema_dar_baja on public.usuario_sistema
  for update using (tiene_permiso('ADM_USUARIO_DAR_BAJA')) with check (tiene_permiso('ADM_USUARIO_DAR_BAJA'));
