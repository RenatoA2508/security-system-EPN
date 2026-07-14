-- Modulo PCO: puntos de control e infraestructura fisica.
-- Fuente: docs/Modelo_Datos_Consolidado_EPN.pdf §3.4 + tabla añadida
-- guardia_punto_control (docs/03_DECISIONES_Y_CORRECCIONES.md §D11, 25a entidad).

create table public.zona (
  id_zona uuid primary key default gen_random_uuid(),
  id_zona_padre uuid references public.zona (id_zona),
  nombre_zona varchar(100) not null,
  tipo_zona text not null check (tipo_zona in ('CAMPUS', 'EDIFICIO', 'PARQUEADERO')),
  estado_zona text not null default 'ACTIVA' check (estado_zona in ('ACTIVA', 'INACTIVA', 'BLOQUEADA')),
  fecha_registro timestamptz not null default now()
);
-- Nota: la validacion "CAMPUS sin padre / EDIFICIO-PARQUEADERO con padre CAMPUS"
-- se implementa como trigger en el bloque 5 (triggers de negocio).

create table public.punto_control (
  id_punto_control uuid primary key default gen_random_uuid(),
  id_zona uuid not null references public.zona (id_zona),
  nombre_punto varchar(100) not null,
  estado_punto text not null default 'ACTIVO' check (estado_punto in ('ACTIVO', 'FALLA', 'MANTENIMIENTO')),
  fecha_registro timestamptz not null default now()
);

create table public.dispositivo (
  id_dispositivo uuid primary key default gen_random_uuid(),
  id_punto_control uuid not null references public.punto_control (id_punto_control),
  direccion_ip varchar(45) not null,
  -- unique: la identidad de servicio del dispositivo (§04 doc 01) depende de
  -- que el codigo_mac identifique a un unico dispositivo sin ambiguedad.
  codigo_mac varchar(50) not null unique,
  tipo_tecnologia text not null check (tipo_tecnologia in ('BIOMETRIA_FACIAL', 'LPR_PLACAS')),
  estado_dispositivo text not null default 'OPERATIVO' check (
    estado_dispositivo in ('OPERATIVO', 'FALLA_DE_RED', 'DANO_FISICO')
  )
);

-- guardia_punto_control (§D11): la 25a tabla del sistema. Asigna guardias a
-- puntos de control; permite resolver "solo su punto asignado" en RLS.
create table public.guardia_punto_control (
  id_asignacion uuid primary key default gen_random_uuid(),
  id_usuario uuid not null references public.usuario_sistema (id_usuario),
  id_punto_control uuid not null references public.punto_control (id_punto_control),
  turno varchar(30),
  fecha_inicio timestamptz not null default now(),
  fecha_fin timestamptz,
  estado_asignacion text not null default 'ACTIVA' check (estado_asignacion in ('ACTIVA', 'FINALIZADA')),
  id_usuario_registro uuid not null references public.usuario_sistema (id_usuario),
  fecha_registro timestamptz not null default now()
);
