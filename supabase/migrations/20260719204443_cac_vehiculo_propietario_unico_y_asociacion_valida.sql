-- CAC RF-CA-018: "asociar un vehiculo a un UNICO propietario" y "un vehiculo no podra
-- permanecer sin propietario asociado". Nada en el esquema lo impedia: persona_vehiculo
-- admitia dos PROPIETARIO activos sobre el mismo vehiculo sin rechistar.
--
-- Y RF-CA-015: "verificar que la placa se encuentre asociada al usuario". Esa comprobacion
-- vivia dispersa; aqui queda como una sola funcion que usan la validacion de acceso y la
-- pantalla de la garita, para que no puedan discrepar (RNF-CA-002).
--
-- Las dos reglas se mantienen SEPARADAS a proposito:
--   * que la persona este asociada al vehiculo decide un ingreso (RF-CA-015);
--   * que el vehiculo tenga propietario es integridad del maestro (RF-CA-018).
-- Denegar el paso a un conductor legitimo porque a su vehiculo le falta el papeleo del
-- propietario seria castigar a la persona por un hueco administrativo que no le corresponde.

-- ---------------------------------------------------------------------------
-- Un solo propietario activo por vehiculo
-- ---------------------------------------------------------------------------
create unique index if not exists ux_vehiculo_un_solo_propietario_activo
  on public.persona_vehiculo (id_vehiculo)
  where tipo_relacion = 'PROPIETARIO' and estado_relacion = 'ACTIVA';

comment on index public.ux_vehiculo_un_solo_propietario_activo is
  'RF-CA-018: un vehiculo tiene como maximo un propietario con relacion ACTIVA.';

-- ---------------------------------------------------------------------------
-- ¿Esta esta persona asociada a este vehiculo? (RF-CA-015)
-- ---------------------------------------------------------------------------
create or replace function public.persona_asociada_a_vehiculo(
  p_id_persona uuid,
  p_id_vehiculo uuid
) returns boolean
language sql
stable
security definer
set search_path to 'public'
as $$
  select exists (
    select 1
      from public.persona_vehiculo pv
     where pv.id_persona = p_id_persona
       and pv.id_vehiculo = p_id_vehiculo
       and pv.estado_relacion = 'ACTIVA'
       -- Una relacion TEMPORAL con fecha de fin pasada no autoriza nada, aunque nadie haya
       -- pasado a marcarla como VENCIDA. Lo que depende del calendario se calcula.
       and (pv.fecha_fin is null or pv.fecha_fin > now())
  );
$$;

comment on function public.persona_asociada_a_vehiculo(uuid, uuid) is
  'RF-CA-015: true si la persona tiene una relacion ACTIVA y no caducada con el vehiculo (propietario, conductor autorizado, pasajero o temporal).';

revoke all on function public.persona_asociada_a_vehiculo(uuid, uuid) from public;
grant execute on function public.persona_asociada_a_vehiculo(uuid, uuid) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Incidencias de RF-CA-018 que ya existen en los datos
-- ---------------------------------------------------------------------------
-- No se inventa un propietario para las filas historicas: no hay forma de saber de quien es
-- el coche. Se exponen para que ADM/GPI las corrija desde la pantalla de vehiculos.
create or replace view public.vista_vehiculo_sin_propietario as
  select v.id_vehiculo,
         v.placa,
         v.tipo_vehiculo,
         v.estado_vehiculo,
         v.fecha_registro
    from public.vehiculo v
   where v.estado_vehiculo <> 'DADO_DE_BAJA'
     and not exists (
       select 1 from public.persona_vehiculo pv
        where pv.id_vehiculo = v.id_vehiculo
          and pv.tipo_relacion = 'PROPIETARIO'
          and pv.estado_relacion = 'ACTIVA'
     );

comment on view public.vista_vehiculo_sin_propietario is
  'RF-CA-018: vehiculos en servicio sin propietario asignado. Incidencia de datos a corregir, no un bloqueo de ingreso.';

alter view public.vista_vehiculo_sin_propietario set (security_invoker = true);
