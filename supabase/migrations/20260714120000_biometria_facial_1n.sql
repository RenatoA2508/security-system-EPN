-- Biometria facial real (reemplaza el mock 1:1 por identificacion 1:N).
-- Fuente: docs/01_AUTENTICACION_Y_ROLES.md §6 (actualizado). Decision del
-- equipo (2026-07-14): el reconocimiento facial se implementa con descriptores
-- de 128 dimensiones calculados en el navegador (face-api.js) y COMPARADOS en
-- el backend con pgvector. El flujo de ingreso de personal interno es una
-- IDENTIFICACION 1:N ("¿de quien es este rostro?"), no una verificacion 1:1.
--
-- El resto del pipeline CAC no cambia: validar-biometria sigue devolviendo un
-- `confidence` que registrar-evento-acceso compara contra el parametro
-- UMBRAL_BIOMETRIA (0.85). Aqui `confidence` = similitud coseno del descriptor
-- vivo contra el mas cercano de los enrolados, un solo umbral para todo.
--
-- Los externos siguen SIN biometria (§D20): el trigger trg_bloquear_biometria_externa
-- (migracion gpi) y la ausencia de descriptor lo garantizan.

-- 1. Extension pgvector en el esquema `extensions` (convencion Supabase, igual
--    que pgcrypto). El tipo queda como extensions.vector.
create extension if not exists vector with schema extensions;

-- 2. Columna del descriptor facial. NULLABLE: las filas historicas del mock no
--    lo tienen, y un enrolamiento puede existir sin descriptor durante la
--    transicion. El archivo/foto sigue viviendo en Storage (path_storage); esto
--    guarda solo el vector de 128 floats que produce face-api.js.
alter table public.registro_biometrico
  add column if not exists descriptor_facial extensions.vector(128);

comment on column public.registro_biometrico.descriptor_facial is
  'Descriptor facial de 128 dimensiones (face-api.js). Se compara por similitud coseno en el backend. La foto original vive en Storage (path_storage), nunca aqui.';

-- 3. Indice HNSW por distancia coseno para la busqueda del vecino mas cercano.
--    En un prototipo con pocas filas un seq scan bastaria, pero se deja el
--    indice para que el comportamiento sea el de produccion (1:N escalable).
create index if not exists idx_registro_biometrico_descriptor
  on public.registro_biometrico
  using hnsw (descriptor_facial extensions.vector_cosine_ops);

-- 4. Identificacion 1:N. Recibe el descriptor vivo como float8[] (evita pasar el
--    tipo vector por PostgREST) y devuelve la persona INTERNA enrolada mas
--    parecida junto con su confidence = 1 - distancia_coseno.
--    NO filtra por persona.estado: identificar es "de quien es el rostro"; la
--    autorizacion (estado ACTIVO, reglas, horario) la decide despues
--    registrar-evento-acceso, conservando la separacion de responsabilidades.
--    SECURITY DEFINER porque la invoca la Edge Function (identidad de servicio),
--    nunca un usuario final; solo lee metadatos, jamas el archivo de Storage.
create or replace function public.identificar_por_descriptor(
  p_descriptor double precision[]
)
returns table (
  id_persona uuid,
  confidence double precision
)
language sql
stable
security definer
set search_path = public, extensions
as $$
  select
    rb.id_persona,
    (1 - (rb.descriptor_facial <=> (p_descriptor::extensions.vector)))::double precision as confidence
  from public.registro_biometrico rb
  join public.persona p on p.id_persona = rb.id_persona
  where rb.vigente = true
    and rb.descriptor_facial is not null
    and p.tipo_persona = 'INTERNA'
  order by rb.descriptor_facial <=> (p_descriptor::extensions.vector)
  limit 1;
$$;

comment on function public.identificar_por_descriptor(double precision[]) is
  'Identificacion facial 1:N. Devuelve la persona INTERNA enrolada mas cercana al descriptor y su confidence (similitud coseno). Invocada por la Edge Function validar-biometria con service_role.';

-- 5. Enrolamiento. SECURITY INVOKER (por defecto) para que la RLS de
--    registro_biometrico (GPI_BIOMETRIA_INSERT) y el trigger que bloquea
--    externos se apliquen con la identidad del responsable GPI que enrola.
--    Recibe el descriptor como float8[] y lo castea a vector internamente.
create or replace function public.enrolar_biometria(
  p_id_persona uuid,
  p_descriptor double precision[],
  p_path_storage text
)
returns uuid
language plpgsql
volatile
set search_path = public, extensions
as $$
declare
  v_id_registro uuid;
begin
  if array_length(p_descriptor, 1) is distinct from 128 then
    raise exception 'El descriptor facial debe tener exactamente 128 dimensiones (recibidas: %)',
      coalesce(array_length(p_descriptor, 1), 0);
  end if;

  insert into public.registro_biometrico (
    id_persona, tipo_dato, path_storage, descriptor_facial, vigente
  )
  values (
    p_id_persona, 'FACIAL', p_path_storage, p_descriptor::extensions.vector, true
  )
  returning id_registro into v_id_registro;

  return v_id_registro;
end;
$$;

comment on function public.enrolar_biometria(uuid, double precision[], text) is
  'Enrola el descriptor facial (128-d) de una persona INTERNA. SECURITY INVOKER: respeta la RLS de GPI y el trigger que prohibe biometria de externos.';

-- 6. Grants de EXECUTE coherentes con la migracion de hardening: se revoca a
--    PUBLIC/anon y se concede solo a quien corresponde.
revoke execute on function
  public.identificar_por_descriptor(double precision[]),
  public.enrolar_biometria(uuid, double precision[], text)
from public;

revoke execute on function
  public.identificar_por_descriptor(double precision[]),
  public.enrolar_biometria(uuid, double precision[], text)
from anon;

-- identificar: solo la Edge Function (service_role). Ningun usuario final debe
-- poder correr la busqueda contra todos los descriptores biometricos.
-- Supabase concede EXECUTE por defecto a `authenticated` en funciones nuevas del
-- esquema public; hay que revocarlo explicitamente (igual que la migracion de
-- hardening), porque `revoke from public` no lo cubre.
revoke execute on function public.identificar_por_descriptor(double precision[])
  from authenticated;

grant execute on function public.identificar_por_descriptor(double precision[])
  to service_role;

-- enrolar: el responsable GPI autenticado (via su JWT); tambien service_role
-- para seeds/demos de bootstrap.
grant execute on function public.enrolar_biometria(uuid, double precision[], text)
  to authenticated, service_role;
