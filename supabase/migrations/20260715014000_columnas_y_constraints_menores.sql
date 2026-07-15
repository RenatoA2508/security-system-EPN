-- Agrupa varios cambios menores de esquema pedidos en docs/Req_Front:
-- (ADM) parámetros faltantes MAX_VEHICULOS_POR_PERSONA y LONGITUD_MINIMA_PASSWORD.
-- (GPI) correo alternativo (telefono_respaldo ya existía).
-- (PCO) nombres únicos de zona y punto de control.
-- (GPE) dependencia_autorizada del memorando deja de ser obligatoria.

insert into public.parametro_sistema (codigo_parametro, nombre_parametro, descripcion, modulo_aplicacion, tipo_dato, valor_parametro, estado_parametro, editable)
values
  ('MAX_VEHICULOS_POR_PERSONA', 'Maximo de vehiculos por persona', 'Limite de vehiculos que puede asociarse una misma persona (docs/03_DECISIONES_Y_CORRECCIONES.md F3).', 'SEGURIDAD', 'ENTERO', '2', 'ACTIVO', true),
  ('LONGITUD_MINIMA_PASSWORD', 'Longitud minima de contrasena', 'Numero minimo de caracteres exigido al cambiar la contrasena.', 'AUTENTICACION', 'ENTERO', '8', 'ACTIVO', true)
on conflict (codigo_parametro) do nothing;

alter table public.persona add column if not exists correo_respaldo character varying;

alter table public.zona add constraint zona_nombre_zona_key unique (nombre_zona);
alter table public.punto_control add constraint punto_control_nombre_punto_key unique (nombre_punto);

alter table public.memorando alter column dependencia_autorizada drop not null;
