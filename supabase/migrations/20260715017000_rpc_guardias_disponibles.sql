-- Feedback PCO (#11): "un Responsable de Módulo no puede ser guardia" en la asignación —
-- el formulario mostraba TODOS los usuario_sistema porque PCO no puede leer usuario_rol
-- (RLS: solo ADM/DIR, doc 02). Esta función expone únicamente las cuentas con el rol
-- GUARDIA_SEGURIDAD activo, sin filtrar la tabla completa de usuarios.

create or replace function public.guardias_disponibles()
returns table (id_usuario uuid, nombre_usuario text, correo_electronico text)
language sql
stable
security definer
set search_path to 'public'
as $$
  select us.id_usuario, us.nombre_usuario, us.correo_electronico
  from public.usuario_sistema us
  join public.usuario_rol ur on ur.id_usuario = us.id_usuario and ur.estado_asignacion = 'ACTIVO'
  join public.rol r on r.id_rol = ur.id_rol and r.estado_rol = 'ACTIVO'
  where r.nombre_rol = 'GUARDIA_SEGURIDAD'
    and us.estado_usuario = 'ACTIVO'
    and (public.tiene_permiso('PCO_ASIGNACION_INSERT') or public.tiene_permiso('PCO_ASIGNACION_UPDATE') or public.tiene_permiso('ADM_MODULO_ACCEDER'))
  order by us.nombre_usuario;
$$;

grant execute on function public.guardias_disponibles() to authenticated;
