-- Feedback (docs/Req_Front/CAC_Nuevos_Requerimientos.md): "Quitar asignación de guardia" de CAC.
-- La organización operativa de guardias es responsabilidad exclusiva de PCO (Puntos de Control).
-- Se revoca (sin DELETE físico) el INSERT/UPDATE de RESPONSABLE_CONTROL_ACCESOS sobre
-- guardia_punto_control; se mantiene el SELECT (oversight de quién vigila cada punto).

update public.rol_permiso rp
set estado_asignacion = 'REVOCADO', fecha_revocacion = now()
from public.permiso p, public.rol r
where rp.id_permiso = p.id_permiso
  and rp.id_rol = r.id_rol
  and r.nombre_rol = 'RESPONSABLE_CONTROL_ACCESOS'
  and p.codigo_permiso in ('CAC_ASIGNACION_INSERT', 'CAC_ASIGNACION_UPDATE')
  and rp.estado_asignacion = 'ACTIVO';
