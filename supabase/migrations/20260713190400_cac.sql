-- Modulo CAC: control de accesos.
-- Fuente: docs/Modelo_Datos_Consolidado_EPN.pdf §3.5, con correcciones
-- §D16 (catalogo tipo_alerta), §D18 (fecha_hora DEFAULT now()) y
-- §D21 (columna es_conductor nueva).

create table public.regla_acceso (
  id_regla_acceso uuid primary key default gen_random_uuid(),
  nombre_regla varchar(100) not null unique,
  descripcion text,
  id_punto_control uuid references public.punto_control (id_punto_control),
  id_categoria uuid not null references public.categoria_persona (id_categoria),
  requiere_memorando boolean not null,
  horario_inicio time not null,
  horario_fin time not null,
  estado_regla text not null default 'ACTIVA' check (estado_regla in ('ACTIVA', 'INACTIVA'))
);

-- evento_acceso: historico de solo insercion. fecha_hora con DEFAULT now()
-- (§D18). es_conductor (§D21): distingue, entre varios eventos de un mismo
-- vehiculo, quien iba manejando ese ingreso/salida en concreto.
create table public.evento_acceso (
  id_evento uuid primary key default gen_random_uuid(),
  id_persona uuid not null references public.persona (id_persona),
  id_vehiculo uuid references public.vehiculo (id_vehiculo),
  id_punto_control uuid not null references public.punto_control (id_punto_control),
  tipo_movimiento text not null check (tipo_movimiento in ('INGRESO', 'SALIDA')),
  fecha_hora timestamptz not null default now(),
  resultado text not null check (resultado in ('AUTORIZADO', 'DENEGADO')),
  motivo_resultado varchar(255),
  origen_registro text not null check (origen_registro in ('AUTOMATICA', 'MANUAL')),
  id_regla_acceso uuid references public.regla_acceso (id_regla_acceso),
  id_autorizacion_visita uuid references public.autorizacion_visita_diaria (id_autorizacion),
  es_conductor boolean not null default false
);

-- alerta_seguridad: catalogo tipo_alerta segun §D16 (provisional, a confirmar
-- por el equipo CAC), incluye los dos valores vehiculares de §D25.
create table public.alerta_seguridad (
  id_alerta uuid primary key default gen_random_uuid(),
  id_evento uuid not null references public.evento_acceso (id_evento),
  tipo_alerta text not null check (tipo_alerta in (
    'BIOMETRIA_FALLIDA', 'PERSONA_NO_AUTORIZADA', 'MEMORANDO_VENCIDO',
    'FUERA_DE_HORARIO', 'PUNTO_SALIDA_INCORRECTO',
    'DISPOSITIVO_NO_RECONOCIDO', 'VEHICULO_NO_AUTORIZADO',
    'VEHICULO_PERMANENCIA_EXCEDIDA', 'VEHICULO_ABANDONADO'
  )),
  nivel_riesgo text not null check (nivel_riesgo in ('BAJO', 'MEDIO', 'ALTO', 'CRITICO')),
  estado_alerta text not null default 'PENDIENTE' check (estado_alerta in ('PENDIENTE', 'ATENDIDA')),
  fecha_hora timestamptz not null default now(),
  accion_atencion text,
  observacion_atencion text,
  id_usuario_atencion uuid references public.usuario_sistema (id_usuario)
);
