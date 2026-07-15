-- Feedback GPE (docs/Req_Front/GPE_Nuevos_Requerimientos.pdf): poder registrar una empresa
-- desde GPE al registrar personal externo. GPE ya podía leer `empresa` (política
-- empresa_select ya incluye GPE_MODULO_ACCEDER); faltaba el INSERT.
-- Aceptado explícitamente por el usuario ("si puede tener ese permiso").

insert into public.permiso (codigo_permiso, descripcion)
values ('GPE_EMPRESA_INSERT', 'Registrar una empresa desde el módulo de Personal Externo')
on conflict (codigo_permiso) do nothing;

insert into public.rol_permiso (id_rol, id_permiso, estado_asignacion)
select r.id_rol, p.id_permiso, 'ACTIVO'
from public.rol r
cross join public.permiso p
where r.nombre_rol = 'RESPONSABLE_PERSONAL_EXTERNO'
  and p.codigo_permiso = 'GPE_EMPRESA_INSERT'
  and not exists (
    select 1 from public.rol_permiso existente
    where existente.id_rol = r.id_rol and existente.id_permiso = p.id_permiso
  );

create policy empresa_insert_gpe on public.empresa
  for insert with check (tiene_permiso('GPE_EMPRESA_INSERT'));
