-- Continuación del arreglo anterior. Ver el nombre del guardia exige leer también su `persona`:
-- `usuario_sistema.nombre_usuario` es un identificador de cuenta ("guardia_demo"), no el nombre
-- de nadie. Y el documento de PCO pide además que el identificador visible sea siempre la cédula,
-- que vive en `persona`.
--
-- Acotado igual que la política de usuario_sistema: solo las personas que están detrás de una
-- cuenta de guardia, y solo para quien gestiona o supervisa asignaciones.
create or replace function public.es_persona_de_guardia(p_id_persona uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
      from public.usuario_sistema us
     where us.id_persona = p_id_persona
       and public.es_usuario_guardia(us.id_usuario)
  );
$$;

comment on function public.es_persona_de_guardia(uuid) is
  'Cierto si la persona está detrás de una cuenta con rol GUARDIA_SEGURIDAD activo.';

create policy persona_select_guardia_asignado
  on public.persona for select
  using (
    public.es_persona_de_guardia(id_persona)
    and (
      public.tiene_permiso('PCO_ASIGNACION_SELECT')
      or public.tiene_permiso('CAC_ASIGNACION_SELECT')
    )
  );
