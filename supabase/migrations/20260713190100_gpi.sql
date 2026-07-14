-- Modulo GPI: gestion de personal interno.
-- Fuente: docs/Modelo_Datos_Consolidado_EPN.pdf §3.2, con correccion §D15
-- (registro_biometrico.vigente boolean, no existe columna estado) y §D20
-- (los externos nunca tienen biometria).

create table public.persona_interna_detalle (
  id_persona uuid primary key references public.persona (id_persona),
  carrera varchar(50),
  curso varchar(50),
  unidad text check (unidad in ('EPN', 'CEC')),
  categoria_escalafon varchar(50),
  contrato varchar(50),
  nombramiento varchar(50),
  cargo varchar(50)
);

create table public.registro_biometrico (
  id_registro uuid primary key default gen_random_uuid(),
  id_persona uuid not null references public.persona (id_persona),
  tipo_dato text not null default 'FACIAL',
  path_storage text not null,
  vigente boolean not null default true,
  fecha_registro timestamptz not null default now(),
  id_usuario_registro uuid references public.usuario_sistema (id_usuario)
);

-- §D20 / §02_MATRIZ_PERMISOS_RLS.md: un externo NUNCA tiene registro biometrico.
create or replace function public.bloquear_biometria_externa()
returns trigger
language plpgsql
as $$
declare
  v_tipo_persona text;
begin
  select tipo_persona into v_tipo_persona from public.persona where id_persona = new.id_persona;
  if v_tipo_persona = 'EXTERNA' then
    raise exception 'No se puede registrar biometria para una persona EXTERNA (id_persona=%)', new.id_persona;
  end if;
  return new;
end;
$$;

create trigger trg_bloquear_biometria_externa
before insert or update on public.registro_biometrico
for each row execute function public.bloquear_biometria_externa();
