-- CAC RF-CA-022: registrar los fallos TECNICOS del reconocimiento facial o de placas
-- (camara no disponible, modelo que no carga, servicio de OCR caido, imagen ilegible).
--
-- Por que tabla propia y no bitacora_sistema: bitacora registra QUIEN hizo QUE sobre una
-- entidad, y su id_usuario es obligatorio en la practica. Un fallo de camara ocurre sin
-- entidad afectada y a veces sin sesion util, y el requisito pide consultarlo por garita y
-- por tipo de reconocimiento — dos dimensiones que en bitacora habria que sacar parseando
-- texto libre. Ademas RNF-CA-003 lo nombra como una categoria de evento propia, al lado de
-- ingresos, rechazos, salidas y alertas.
--
-- "sin interrumpir el almacenamiento de los demas eventos" (RF-CA-022): esta tabla no tiene
-- FK obligatoria a evento_acceso; un error puede ocurrir antes de que exista evento alguno.

create table if not exists public.error_reconocimiento (
  id_error uuid primary key default gen_random_uuid(),
  tipo_reconocimiento text not null,
  codigo_error text not null,
  descripcion text not null,
  id_punto_control uuid references public.punto_control(id_punto_control),
  id_dispositivo uuid references public.dispositivo(id_dispositivo),
  id_usuario uuid references public.usuario_sistema(id_usuario),
  id_evento uuid references public.evento_acceso(id_evento),
  fecha_hora timestamptz not null default now(),
  constraint error_reconocimiento_tipo_check
    check (tipo_reconocimiento in ('FACIAL', 'PLACA')),
  constraint error_reconocimiento_codigo_check
    check (codigo_error in (
      'CAMARA_NO_DISPONIBLE',    -- el navegador nego el acceso o no hay dispositivo
      'MODELO_NO_CARGADO',       -- los pesos de face-api no llegaron
      'ROSTRO_NO_DETECTADO',     -- hay imagen pero ninguna cara en ella
      'PLACA_NO_LEGIBLE',        -- hay imagen pero el OCR no extrae nada con forma de placa
      'SERVICIO_NO_DISPONIBLE',  -- el proveedor de reconocimiento no responde
      'TIEMPO_AGOTADO',
      'ERROR_INTERNO'
    )),
  constraint error_reconocimiento_descripcion_no_vacia
    check (btrim(descripcion) <> '')
);

comment on table public.error_reconocimiento is
  'RF-CA-022: incidencias tecnicas del reconocimiento facial o de placas, para auditoria y diagnostico.';
comment on column public.error_reconocimiento.codigo_error is
  'Categoria estable del fallo. La descripcion lleva el detalle legible; el codigo es lo que se agrupa y se cuenta.';

create index if not exists idx_error_reconocimiento_fecha
  on public.error_reconocimiento (fecha_hora desc);
create index if not exists idx_error_reconocimiento_punto
  on public.error_reconocimiento (id_punto_control, fecha_hora desc);

-- ---------------------------------------------------------------------------
-- RLS. Historico: solo INSERT y SELECT, nunca UPDATE ni DELETE (misma regla que
-- evento_acceso y bitacora_sistema en CLAUDE.md). Al no crear politicas de UPDATE/DELETE,
-- quedan denegadas para todos los roles salvo service_role.
-- ---------------------------------------------------------------------------
alter table public.error_reconocimiento enable row level security;

-- Lectura: CAC y ADM ven todo; el guardia solo lo ocurrido en su punto asignado, igual que
-- con los eventos de acceso.
create policy error_reconocimiento_select_amplio on public.error_reconocimiento
  for select to authenticated
  using (
    public.tiene_permiso('ADM_MODULO_ACCEDER')
    or public.tiene_permiso('CAC_EVENTO_SELECT')
  );

create policy error_reconocimiento_select_guardia on public.error_reconocimiento
  for select to authenticated
  using (
    public.tiene_permiso('CAC_EVENTO_SELECT_PUNTO_ASIGNADO')
    and id_punto_control in (select public.puntos_control_asignados())
  );

-- Escritura: quien puede registrar un evento de acceso puede dejar constancia de por que el
-- reconocimiento fallo. Si esto fuera mas estricto que el INSERT de evento_acceso, el error
-- se perderia justo en el caso que RF-CA-022 quiere capturar.
create policy error_reconocimiento_insert on public.error_reconocimiento
  for insert to authenticated
  with check (
    public.tiene_permiso('CAC_EVENTO_INSERT')
    or public.tiene_permiso('CAC_VALIDACION_EJECUTAR')
  );
