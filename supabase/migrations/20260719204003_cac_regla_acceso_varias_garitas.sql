-- CAC RF-CA-002 y RF-CA-007 hablan de "garitas" en plural: la regla debe poder autorizar un
-- conjunto de puntos de control, y la validacion debe comprobar que la garita de la solicitud
-- esta incluida en ese conjunto. El esquema solo permitia una FK unica (o NULL = todas), asi
-- que "acceso docente por las tres garitas del campus" obligaba a crear tres reglas
-- duplicadas y a mantenerlas sincronizadas a mano.
--
-- Semantica de la tabla N:M (una sola regla, sin ambiguedad):
--   * la regla NO tiene filas   -> aplica en TODOS los puntos de control
--   * la regla tiene >= 1 fila  -> aplica UNICAMENTE en esos puntos
-- Es exactamente la que tenia la columna nullable, generalizada a varios puntos, asi que las
-- 8 reglas ya sembradas conservan su comportamiento tras el traspaso.

create table if not exists public.regla_acceso_punto_control (
  id_regla_acceso uuid not null references public.regla_acceso(id_regla_acceso) on delete cascade,
  id_punto_control uuid not null references public.punto_control(id_punto_control),
  fecha_registro timestamptz not null default now(),
  primary key (id_regla_acceso, id_punto_control)
);

comment on table public.regla_acceso_punto_control is
  'Garitas en las que aplica una regla de acceso (RF-CA-007). Sin filas = todas las garitas.';

create index if not exists idx_regla_punto_por_punto
  on public.regla_acceso_punto_control (id_punto_control);

-- Traspaso de la columna antigua. Las reglas con id_punto_control NULL no generan fila:
-- siguen aplicando en todos los puntos.
insert into public.regla_acceso_punto_control (id_regla_acceso, id_punto_control)
select r.id_regla_acceso, r.id_punto_control
  from public.regla_acceso r
 where r.id_punto_control is not null
on conflict do nothing;

alter table public.regla_acceso drop column id_punto_control;

-- Predicado unico de "esta regla aplica en esta garita". Lo usan la Edge Function de
-- validacion y las pruebas; tenerlo en un solo sitio evita que las dos definiciones de
-- "sin filas = todas" se separen con el tiempo.
create or replace function public.regla_aplica_en_punto(
  p_id_regla uuid,
  p_id_punto uuid
) returns boolean
language sql
stable
security invoker
set search_path to 'public'
as $$
  select not exists (
           select 1 from public.regla_acceso_punto_control rp
            where rp.id_regla_acceso = p_id_regla
         )
      or exists (
           select 1 from public.regla_acceso_punto_control rp
            where rp.id_regla_acceso = p_id_regla
              and rp.id_punto_control = p_id_punto
         );
$$;

comment on function public.regla_aplica_en_punto(uuid, uuid) is
  'RF-CA-007: true si la regla autoriza esa garita. Sin garitas asociadas, la regla aplica en todas.';

revoke all on function public.regla_aplica_en_punto(uuid, uuid) from public;
grant execute on function public.regla_aplica_en_punto(uuid, uuid) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- RLS: mismas reglas que regla_acceso (doc 02). Quien puede leer una regla puede leer
-- en que garitas aplica; quien puede modificarla puede cambiar esa lista.
-- (Ambas politicas se corrigen en la migracion inmediatamente posterior: ver §D58.)
-- ---------------------------------------------------------------------------
alter table public.regla_acceso_punto_control enable row level security;

create policy regla_punto_select on public.regla_acceso_punto_control
  for select to authenticated
  using (public.tiene_permiso('CAC_REGLA_SELECT'));

create policy regla_punto_insert on public.regla_acceso_punto_control
  for insert to authenticated
  with check (public.tiene_permiso('CAC_REGLA_INSERT'));

create policy regla_punto_delete on public.regla_acceso_punto_control
  for delete to authenticated
  using (public.tiene_permiso('CAC_REGLA_UPDATE'));
