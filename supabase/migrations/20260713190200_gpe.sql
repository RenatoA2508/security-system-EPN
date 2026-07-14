-- Modulo GPE: gestion de personal externo.
-- Fuente: docs/Modelo_Datos_Consolidado_EPN.pdf §3.3.

create table public.memorando (
  id_memorando uuid primary key default gen_random_uuid(),
  numero_memorando varchar(50) not null unique,
  id_empresa uuid not null references public.empresa (id_empresa),
  fecha_inicio date not null,
  fecha_fin date not null,
  dependencia_autorizada varchar(120) not null,
  estado_memorando text not null default 'VIGENTE' check (estado_memorando in ('VIGENTE', 'VENCIDO')),
  fecha_registro timestamptz not null default now(),
  id_usuario_registro uuid not null references public.usuario_sistema (id_usuario),
  constraint chk_memorando_fechas check (fecha_fin >= fecha_inicio)
);

create table public.persona_memorando (
  id_persona_memorando uuid primary key default gen_random_uuid(),
  id_memorando uuid not null references public.memorando (id_memorando),
  id_persona uuid not null references public.persona (id_persona),
  estado_acceso text not null default 'ACTIVO' check (estado_acceso in ('ACTIVO', 'BLOQUEADO'))
);

-- autorizacion_visita_diaria: visitas sin memorando, criterio del guardia
-- (§D3 - el guardia SI registra estas autorizaciones, aunque no toca memorando).
create table public.autorizacion_visita_diaria (
  id_autorizacion uuid primary key default gen_random_uuid(),
  id_persona uuid not null references public.persona (id_persona),
  fecha_visita date not null,
  motivo varchar(255) not null,
  estado_autorizacion text not null default 'VIGENTE' check (estado_autorizacion in ('VIGENTE', 'REVOCADA')),
  id_usuario_registro uuid not null references public.usuario_sistema (id_usuario),
  fecha_registro timestamptz not null default now()
);
