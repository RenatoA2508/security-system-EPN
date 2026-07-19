-- CAC RF-CA-020, RF-CA-021, RF-CA-024, RF-CA-025.
--
-- Tres huecos del esquema que impedian cumplir el documento de CAC:
--
-- 1. RF-CA-021 (persona desconocida) era IMPOSIBLE de registrar: evento_acceso.id_persona
--    era NOT NULL, asi que el caso "el rostro no coincide con nadie" no tenia donde guardarse.
--    Pasa a nullable, con un CHECK que ata ese hueco a su unico caso legitimo.
-- 2. RF-CA-020/024/025 piden mostrar "Tipo de acceso (Peatonal o Vehicular)". Se derivaba de
--    id_vehiculo, que es NULL tanto en un ingreso peatonal como en un intento vehicular con
--    placa no reconocida: dos cosas distintas indistinguibles. Ahora se almacena.
-- 3. RF-CA-013 pide que la salida se asocie al registro de ingreso correspondiente. No habia
--    ninguna columna que los ligara.
--
-- evento_acceso sigue siendo historico y de solo INSERT (CLAUDE.md): esto es DDL, no toca
-- ninguna fila existente salvo el relleno de tipo_acceso, que es una derivacion exacta.

alter table public.evento_acceso
  alter column id_persona drop not null;

alter table public.evento_acceso
  add column if not exists tipo_acceso text not null default 'PEATONAL',
  add column if not exists placa_detectada varchar(16),
  add column if not exists confianza_placa numeric(5, 4),
  add column if not exists confianza_biometria numeric(5, 4),
  add column if not exists id_evento_ingreso uuid;

-- Relleno historico: las 15 filas previas son peatonales salvo las que llevan vehiculo.
update public.evento_acceso
   set tipo_acceso = 'VEHICULAR'
 where id_vehiculo is not null
   and tipo_acceso <> 'VEHICULAR';

alter table public.evento_acceso
  add constraint evento_acceso_tipo_acceso_check
  check (tipo_acceso in ('PEATONAL', 'VEHICULAR'));

-- Un evento sin persona solo puede ser un rechazo por rostro/placa no identificados.
-- Sin esto, id_persona nullable seria una puerta abierta a eventos huerfanos que romperian
-- la trazabilidad que exige RNF-CA-003.
alter table public.evento_acceso
  add constraint evento_acceso_sin_persona_solo_desconocido
  check (
    id_persona is not null
    or (resultado = 'DENEGADO' and motivo_resultado like 'PERSONA_DESCONOCIDA%')
  );

alter table public.evento_acceso
  add constraint evento_acceso_id_evento_ingreso_fkey
  foreign key (id_evento_ingreso) references public.evento_acceso(id_evento);

-- Solo una SALIDA puede colgar de un ingreso.
alter table public.evento_acceso
  add constraint evento_acceso_ingreso_ligado_solo_en_salida
  check (id_evento_ingreso is null or tipo_movimiento = 'SALIDA');

create index if not exists idx_evento_acceso_ingreso_ligado
  on public.evento_acceso (id_evento_ingreso)
  where id_evento_ingreso is not null;

-- RF-CA-024/025 ordenan cronologicamente y filtran por punto; el historial crece sin limite.
create index if not exists idx_evento_acceso_punto_fecha
  on public.evento_acceso (id_punto_control, fecha_hora desc);

-- RF-CA-015: buscar por la placa leida aunque no se resolviera a un vehiculo registrado.
create index if not exists idx_evento_acceso_placa_detectada
  on public.evento_acceso (placa_detectada)
  where placa_detectada is not null;

comment on column public.evento_acceso.tipo_acceso is
  'PEATONAL o VEHICULAR (RF-CA-020/024/025). Se almacena, no se deriva de id_vehiculo: un intento vehicular con placa no reconocida tambien tiene id_vehiculo NULL.';
comment on column public.evento_acceso.placa_detectada is
  'Placa leida por el reconocimiento (forma canonica, sin guion), aunque no corresponda a ningun vehiculo registrado. Trazabilidad de RF-CA-015 y RF-CA-023.';
comment on column public.evento_acceso.confianza_placa is
  'Confianza [0,1] devuelta por el reconocimiento de placas en el momento de la lectura.';
comment on column public.evento_acceso.confianza_biometria is
  'Confianza [0,1] del reconocimiento facial en el momento de la validacion. Antes solo viajaba en la peticion y se perdia.';
comment on column public.evento_acceso.id_evento_ingreso is
  'Ingreso al que corresponde esta salida (RF-CA-013). NULL si no se pudo emparejar.';
comment on column public.evento_acceso.id_persona is
  'NULL solo en eventos PERSONA_DESCONOCIDA (RF-CA-021): el rostro no coincidio con nadie enrolado.';
