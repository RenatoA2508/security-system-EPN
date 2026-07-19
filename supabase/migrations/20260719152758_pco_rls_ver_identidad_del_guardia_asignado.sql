-- BUG (PCO §"En Asignaciones de guardia no aparece el nombre del guardia a cargo de ese punto").
--
-- La causa estaba en RLS, no en la pantalla: `usuario_sistema_select` solo dejaba leer la propia
-- fila o exigía ADM_USUARIO_SELECT, que el Responsable de Puntos de Control no tiene. El embed
-- de PostgREST no da error en ese caso: devuelve `guardia: null`, así que la columna se pintaba
-- como "—" y parecía un fallo de la pantalla. Comprobado contra la API con esa cuenta.
--
-- El arreglo es el permiso mínimo: quien gestiona o supervisa asignaciones puede leer la
-- identidad de las cuentas que son guardias, y de nadie más.

create or replace function public.es_usuario_guardia(p_id_usuario uuid)
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
     where ur.id_usuario = p_id_usuario
       and ur.estado_asignacion = 'ACTIVO'
       and r.estado_rol = 'ACTIVO'
       and r.nombre_rol = 'GUARDIA_SEGURIDAD'
  );
$$;

comment on function public.es_usuario_guardia(uuid) is
  'Cierto si la cuenta tiene el rol GUARDIA_SEGURIDAD activo. Acota qué filas de usuario_sistema puede leer quien gestiona asignaciones.';

create policy usuario_sistema_select_guardia_asignable
  on public.usuario_sistema for select
  using (
    public.es_usuario_guardia(id_usuario)
    and (
      public.tiene_permiso('PCO_ASIGNACION_SELECT')
      or public.tiene_permiso('CAC_ASIGNACION_SELECT')
    )
  );
