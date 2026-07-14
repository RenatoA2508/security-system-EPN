-- scripts/pruebas_cobertura_docs.sql
--
-- Suite de COBERTURA DE DOCUMENTOS: valida contra la base real cada decisión y
-- regla de negocio de docs/01..04 y docs/99 (dudas resueltas). Complementa a
-- scripts/smoke_test.sql (que ejercita el flujo feliz de punta a punta): esta
-- suite es exhaustiva por regla, incluyendo pruebas negativas (lo que DEBE fallar).
--
-- Cómo se ejecutó (2ª modalidad, en cloud vía el MCP de Supabase):
--   cada módulo es un bloque  begin; ... <SELECT resultados>; rollback;  de modo
--   que NO deja datos en la base. El SELECT final devuelve PASA/FALLA por prueba.
--
-- También corre en local (si algún día hay stack):
--   psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -f scripts/pruebas_cobertura_docs.sql
--
-- Corre como postgres (fuera de RLS): prueba la LÓGICA (triggers, vistas,
-- catálogos, clasificador, permanencia) y la MATRIZ de permisos como dato.
-- La verificación conductual de RLS por rol vive en scripts/pruebas_rls_por_rol.sql.
--
-- Notas de método (aprendidas al construirla):
--   * La inmutabilidad de evento_acceso/bitacora_sistema NO es un trigger: es un
--     REVOKE de UPDATE. postgres (superusuario) lo ignora, por eso se verifica con
--     has_table_privilege('authenticated', ...) en vez de intentar el UPDATE.
--   * now() está congelado dentro de una transacción; para probar el trigger de
--     fecha_modificacion se fuerza un valor viejo y se comprueba que lo sobrescribe.
--
-- Mapa de trazabilidad regla -> prueba en el comentario de cada módulo.

\echo '=== MÓDULO A — Esquema, catálogos, parámetros y privilegios ==='
-- D1 (sin password_hash), D14 (token_hash nullable), D15 (vigente boolean),
-- D16/D25 (catálogo tipo_alerta), D17/D25 (parámetros), D18/D21 (defaults evento),
-- D20 (índice cédula), 01§3 (7 roles), 02 (RLS en 25 tablas; REVOKE de históricos).
begin;
create temp table _res(seccion text, prueba text, esperado text, obtenido text, ok boolean) on commit drop;
do $$
declare v_txt text; v_n int; v_bool boolean; v_def text;
begin
  select pg_get_constraintdef(oid) into v_def from pg_constraint where conname='alerta_seguridad_tipo_alerta_check';
  v_bool := v_def like '%VEHICULO_ABANDONADO%' and v_def like '%VEHICULO_PERMANENCIA_EXCEDIDA%'
        and v_def like '%BIOMETRIA_FALLIDA%' and v_def like '%PUNTO_SALIDA_INCORRECTO%'
        and v_def like '%DISPOSITIVO_NO_RECONOCIDO%';
  insert into _res values('A. Esquema','A1 catálogo tipo_alerta con los 9 valores (D16/D25)','incluye 9 tipos',(case when v_bool then 'ok' else 'falta alguno' end), v_bool);

  select count(*) into v_n from public.rol;
  insert into _res values('A. Esquema','A2 exactamente 7 roles definidos (01 §3)','7',v_n::text, v_n=7);

  select count(*) into v_n from public.parametro_sistema where
     (codigo_parametro,valor_parametro) in (
       ('MAX_INTENTOS_LOGIN','5'),('TIEMPO_BLOQUEO_CUENTA_MIN','15'),('TIEMPO_SESION_MIN','60'),
       ('UMBRAL_BIOMETRIA','0.85'),('PERMANENCIA_MAX_INTERNO_H','16'),('PERMANENCIA_MAX_EXTERNO_H','12'),
       ('PERMANENCIA_MAX_VISITA_H','4'),('PERMANENCIA_ABANDONO_H','72'));
  insert into _res values('A. Esquema','A3 los 8 parámetros con valores exactos (D17/D25)','8',v_n::text, v_n=8);

  select ambito into v_txt from public.categoria_persona where codigo_categoria='CONDUCTOR';
  insert into _res values('A. Esquema','A4 categoría CONDUCTOR con ambito EXTERNA (E4)','EXTERNA',v_txt, v_txt='EXTERNA');

  select exists(select 1 from information_schema.columns where table_schema='public' and table_name='registro_biometrico' and column_name='vigente')
     and not exists(select 1 from information_schema.columns where table_schema='public' and table_name='registro_biometrico' and column_name='estado')
    into v_bool;
  insert into _res values('A. Esquema','A5 registro_biometrico usa vigente boolean, sin columna estado (D15)','vigente sí / estado no',(case when v_bool then 'ok' else 'mal' end), v_bool);

  select is_nullable='YES' into v_bool from information_schema.columns where table_schema='public' and table_name='sesion' and column_name='token_hash';
  insert into _res values('A. Esquema','A6 sesion.token_hash es NULLABLE (D14)','YES',(case when v_bool then 'YES' else 'NO' end), v_bool);

  select bool_and(x) into v_bool from (
    select column_default='false' x from information_schema.columns where table_schema='public' and table_name='evento_acceso' and column_name='es_conductor'
    union all
    select column_default='now()' from information_schema.columns where table_schema='public' and table_name='evento_acceso' and column_name='fecha_hora'
  ) s;
  insert into _res values('A. Esquema','A7 es_conductor DEFAULT false (D21) y fecha_hora DEFAULT now() (D18)','ambos',(case when v_bool then 'ok' else 'mal' end), v_bool);

  select exists(select 1 from pg_indexes where schemaname='public' and tablename='persona' and indexdef ilike '%cedula%') into v_bool;
  insert into _res values('A. Esquema','A8 índice sobre persona.cedula (D20)','existe',(case when v_bool then 'existe' else 'falta' end), v_bool);

  select not exists(select 1 from information_schema.columns where table_schema='public' and table_name='usuario_sistema' and column_name='password_hash') into v_bool;
  insert into _res values('A. Esquema','A9 usuario_sistema sin password_hash (D1)','sin password_hash',(case when v_bool then 'ok' else 'existe!' end), v_bool);

  select count(*) into v_n from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relkind='r' and c.relrowsecurity;
  insert into _res values('A. Esquema','A10 RLS habilitado en 25 tablas (02 notas)','25',v_n::text, v_n=25);

  select (not has_table_privilege('authenticated','public.persona','DELETE'))
     and (not has_table_privilege('authenticated','public.evento_acceso','UPDATE'))
     and (not has_table_privilege('authenticated','public.bitacora_sistema','UPDATE'))
    into v_bool;
  insert into _res values('A. Esquema','A11 DELETE(persona)+UPDATE(evento_acceso,bitacora) revocados a authenticated (02)','revocados',(case when v_bool then 'ok' else 'concedido!' end), v_bool);
exception when others then
  insert into _res values('A. Esquema','ERROR en el bloque','-', sqlerrm, false);
end $$;
select seccion, prueba, esperado, obtenido, (case when ok then 'PASA' else 'FALLA' end) as estado from _res order by prueba;
rollback;

\echo '=== MÓDULO B — Triggers e integridad (pruebas negativas) ==='
-- D20 (biometría solo INTERNA), no-DELETE-físico, históricos, trigger fecha_modificacion.
begin;
create temp table _res(seccion text, prueba text, esperado text, obtenido text, ok boolean) on commit drop;
do $$
declare v_cat_doc uuid; v_cat_vis uuid; v_p_int uuid; v_p_ext uuid; v_zona uuid; v_pc uuid; v_ev uuid; v_new timestamptz;
begin
  select id_categoria into v_cat_doc from public.categoria_persona where codigo_categoria='DOCENTE';
  select id_categoria into v_cat_vis from public.categoria_persona where codigo_categoria='VISITANTE';
  insert into public.persona(tipo_persona,id_categoria,cedula,nombres,apellidos,correo,estado)
    values('INTERNA',v_cat_doc,'1700000501','Beta','Interna Test','beta.int@epn.edu.ec','ACTIVO') returning id_persona into v_p_int;
  insert into public.persona(tipo_persona,id_categoria,cedula,nombres,apellidos,correo,estado)
    values('EXTERNA',v_cat_vis,'1700000599','Gamma','Externa Test','gamma.ext@example.com','ACTIVO') returning id_persona into v_p_ext;
  insert into public.zona(nombre_zona,tipo_zona,estado_zona) values('Zona B Test','CAMPUS','ACTIVA') returning id_zona into v_zona;
  insert into public.punto_control(id_zona,nombre_punto,estado_punto) values(v_zona,'PC B Test','ACTIVO') returning id_punto_control into v_pc;

  begin
    insert into public.registro_biometrico(id_persona,tipo_dato,path_storage,vigente) values(v_p_ext,'FACIAL','b/no.jpg',true);
    insert into _res values('B. Triggers','B1 biometría de persona EXTERNA rechazada (D20)','rechazada','SE PERMITIÓ', false);
  exception when others then
    insert into _res values('B. Triggers','B1 biometría de persona EXTERNA rechazada (D20)','rechazada','rechazada', true);
  end;
  begin
    insert into public.registro_biometrico(id_persona,tipo_dato,path_storage,vigente) values(v_p_int,'FACIAL','b/ok.jpg',true);
    insert into _res values('B. Triggers','B2 biometría de persona INTERNA permitida (D20)','permitida','permitida', true);
  exception when others then
    insert into _res values('B. Triggers','B2 biometría de persona INTERNA permitida (D20)','permitida','FALLÓ: '||left(sqlerrm,40), false);
  end;
  begin
    delete from public.persona where id_persona=v_p_int;
    insert into _res values('B. Triggers','B3 DELETE físico de persona rechazado (trigger)','rechazado','SE PERMITIÓ', false);
  exception when others then
    insert into _res values('B. Triggers','B3 DELETE físico de persona rechazado (trigger)','rechazado','rechazado', true);
  end;
  insert into public.evento_acceso(id_persona,id_punto_control,tipo_movimiento,resultado,origen_registro)
    values(v_p_int,v_pc,'INGRESO','AUTORIZADO','AUTOMATICA') returning id_evento into v_ev;
  begin
    delete from public.evento_acceso where id_evento=v_ev;
    insert into _res values('B. Triggers','B4 DELETE de evento_acceso rechazado (histórico)','rechazado','SE PERMITIÓ', false);
  exception when others then
    insert into _res values('B. Triggers','B4 DELETE de evento_acceso rechazado (histórico)','rechazado','rechazado', true);
  end;
  insert into _res values('B. Triggers','B5 evento_acceso: UPDATE revocado a authenticated (inmutable, 02)','sin privilegio UPDATE',
    (case when has_table_privilege('authenticated','public.evento_acceso','UPDATE') then 'TIENE UPDATE!' else 'revocado' end),
    not has_table_privilege('authenticated','public.evento_acceso','UPDATE'));
  insert into _res values('B. Triggers','B6 bitacora_sistema: UPDATE revocado a authenticated (histórico, 02)','sin privilegio UPDATE',
    (case when has_table_privilege('authenticated','public.bitacora_sistema','UPDATE') then 'TIENE UPDATE!' else 'revocado' end),
    not has_table_privilege('authenticated','public.bitacora_sistema','UPDATE'));
  update public.persona set fecha_modificacion = timestamptz '2000-01-01 00:00+00', nombres='Gamma2' where id_persona=v_p_ext;
  select fecha_modificacion into v_new from public.persona where id_persona=v_p_ext;
  insert into _res values('B. Triggers','B7 trigger set_fecha_modificacion sobrescribe fecha en UPDATE de persona',
    'trigger la fija a now()', (case when v_new > timestamptz '2001-01-01' then 'sobrescrita a now()' else 'quedó en 2000 (no disparó)' end),
    v_new > timestamptz '2001-01-01');
end $$;
select seccion, prueba, esperado, obtenido, (case when ok then 'PASA' else 'FALLA' end) as estado from _res order by prueba;
rollback;

\echo '=== MÓDULO C — Flujo de alertas y clasificador determinista ==='
-- D4 (alertas nacen solas; solo DENEGADO), E9 (clasificador por código canónico).
begin;
create temp table _res(seccion text, prueba text, esperado text, obtenido text, ok boolean) on commit drop;
do $$
declare v_cat_doc uuid; v_p uuid; v_zona uuid; v_pc uuid; v_ev uuid; v_n int; v_tipo text; v_estado text;
begin
  select id_categoria into v_cat_doc from public.categoria_persona where codigo_categoria='DOCENTE';
  insert into public.persona(tipo_persona,id_categoria,cedula,nombres,apellidos,correo,estado)
    values('INTERNA',v_cat_doc,'1700000701','Delta','Alerta Test','delta.al@epn.edu.ec','ACTIVO') returning id_persona into v_p;
  insert into public.zona(nombre_zona,tipo_zona,estado_zona) values('Zona C Test','CAMPUS','ACTIVA') returning id_zona into v_zona;
  insert into public.punto_control(id_zona,nombre_punto,estado_punto) values(v_zona,'PC C Test','ACTIVO') returning id_punto_control into v_pc;

  insert into public.evento_acceso(id_persona,id_punto_control,tipo_movimiento,resultado,origen_registro)
    values(v_p,v_pc,'INGRESO','AUTORIZADO','AUTOMATICA') returning id_evento into v_ev;
  select count(*) into v_n from public.alerta_seguridad where id_evento=v_ev;
  insert into _res values('C. Alertas','C2 evento AUTORIZADO no genera alerta (D4)','0',v_n::text, v_n=0);

  insert into public.evento_acceso(id_persona,id_punto_control,tipo_movimiento,resultado,motivo_resultado,origen_registro)
    values(v_p,v_pc,'INGRESO','DENEGADO','MEMORANDO_VENCIDO: prueba','MANUAL') returning id_evento into v_ev;
  select count(*) into v_n from public.alerta_seguridad where id_evento=v_ev;
  insert into _res values('C. Alertas','C1 evento DENEGADO genera exactamente 1 alerta (D4)','1',v_n::text, v_n=1);
  select tipo_alerta, estado_alerta into v_tipo, v_estado from public.alerta_seguridad where id_evento=v_ev;
  insert into _res values('C. Alertas','C3 clasificador MEMORANDO_VENCIDO: -> MEMORANDO_VENCIDO (E9)','MEMORANDO_VENCIDO',v_tipo, v_tipo='MEMORANDO_VENCIDO');
  insert into _res values('C. Alertas','C6 la alerta nace en estado PENDIENTE (D4)','PENDIENTE',v_estado, v_estado='PENDIENTE');

  insert into public.evento_acceso(id_persona,id_punto_control,tipo_movimiento,resultado,motivo_resultado,origen_registro)
    values(v_p,v_pc,'INGRESO','DENEGADO','BIOMETRIA_FALLIDA: no hay match','AUTOMATICA') returning id_evento into v_ev;
  select tipo_alerta into v_tipo from public.alerta_seguridad where id_evento=v_ev;
  insert into _res values('C. Alertas','C4 clasificador BIOMETRIA_FALLIDA: -> BIOMETRIA_FALLIDA (E9)','BIOMETRIA_FALLIDA',v_tipo, v_tipo='BIOMETRIA_FALLIDA');

  insert into public.evento_acceso(id_persona,id_punto_control,tipo_movimiento,resultado,motivo_resultado,origen_registro)
    values(v_p,v_pc,'INGRESO','DENEGADO','FUERA_DE_HORARIO: 03:00','AUTOMATICA') returning id_evento into v_ev;
  select tipo_alerta into v_tipo from public.alerta_seguridad where id_evento=v_ev;
  insert into _res values('C. Alertas','C5 clasificador FUERA_DE_HORARIO: -> FUERA_DE_HORARIO (E9)','FUERA_DE_HORARIO',v_tipo, v_tipo='FUERA_DE_HORARIO');

  insert into public.evento_acceso(id_persona,id_punto_control,tipo_movimiento,resultado,motivo_resultado,origen_registro)
    values(v_p,v_pc,'INGRESO','DENEGADO','texto libre sin prefijo canonico','MANUAL') returning id_evento into v_ev;
  select tipo_alerta into v_tipo from public.alerta_seguridad where id_evento=v_ev;
  insert into _res values('C. Alertas','C7 motivo sin código -> respaldo PERSONA_NO_AUTORIZADA (E9)','PERSONA_NO_AUTORIZADA',v_tipo, v_tipo='PERSONA_NO_AUTORIZADA');
exception when others then
  insert into _res values('C. Alertas','ERROR en el bloque','-', sqlerrm, false);
end $$;
select seccion, prueba, esperado, obtenido, (case when ok then 'PASA' else 'FALLA' end) as estado from _res order by prueba;
rollback;

\echo '=== MÓDULO D — Vistas de vigencia y permanencia vehicular ==='
-- D20 (dos vías), D22 (conductor), D24 (fecha_fin inclusiva), D25 (límites),
-- fix 3e1f9fe (último movimiento manda ante timestamps iguales).
begin;
create temp table _res(seccion text, prueba text, esperado text, obtenido text, ok boolean) on commit drop;
do $$
declare
  v_cat_doc uuid; v_cat_vis uuid; v_admin uuid; v_emp uuid;
  v_int uuid; v_ext_memo uuid; v_ext_auth uuid; v_ext_hoy uuid; v_ext_sin uuid;
  v_memo uuid; v_memo_hoy uuid; v_zona uuid; v_pc uuid; v_veh uuid; v_veh2 uuid; v_ts timestamptz;
  v_via text; v_n int; v_lim numeric;
begin
  select id_categoria into v_cat_doc from public.categoria_persona where codigo_categoria='DOCENTE';
  select id_categoria into v_cat_vis from public.categoria_persona where codigo_categoria='VISITANTE';
  select us.id_usuario into v_admin from public.usuario_sistema us
    join public.usuario_rol ur on ur.id_usuario=us.id_usuario and ur.estado_asignacion='ACTIVO'
    join public.rol r on r.id_rol=ur.id_rol and r.nombre_rol='ADMINISTRADOR_SISTEMA' limit 1;
  insert into public.empresa(nombre,estado) values('Empresa D Test','ACTIVO') returning id_empresa into v_emp;

  insert into public.persona(tipo_persona,id_categoria,cedula,nombres,apellidos,correo,estado)
    values('INTERNA',v_cat_doc,'1700000801','Eps','Interna','eps.i@epn.edu.ec','ACTIVO') returning id_persona into v_int;
  insert into public.persona(tipo_persona,id_categoria,cedula,nombres,apellidos,correo,estado)
    values('EXTERNA',v_cat_vis,'1700000802','Zeta','Memo','zeta.m@ex.com','ACTIVO') returning id_persona into v_ext_memo;
  insert into public.persona(tipo_persona,id_categoria,cedula,nombres,apellidos,correo,estado)
    values('EXTERNA',v_cat_vis,'1700000803','Eta','Auth','eta.a@ex.com','ACTIVO') returning id_persona into v_ext_auth;
  insert into public.persona(tipo_persona,id_categoria,cedula,nombres,apellidos,correo,estado)
    values('EXTERNA',v_cat_vis,'1700000804','Theta','MemoHoy','theta.h@ex.com','ACTIVO') returning id_persona into v_ext_hoy;
  insert into public.persona(tipo_persona,id_categoria,cedula,nombres,apellidos,correo,estado)
    values('EXTERNA',v_cat_vis,'1700000805','Iota','SinVia','iota.s@ex.com','ACTIVO') returning id_persona into v_ext_sin;

  insert into public.memorando(numero_memorando,id_empresa,fecha_inicio,fecha_fin,dependencia_autorizada,estado_memorando,id_usuario_registro)
    values('MEMO-D-1',v_emp,current_date-2,current_date+5,'Dir Admin','VIGENTE',v_admin) returning id_memorando into v_memo;
  insert into public.persona_memorando(id_memorando,id_persona,estado_acceso) values(v_memo,v_ext_memo,'ACTIVO');
  insert into public.memorando(numero_memorando,id_empresa,fecha_inicio,fecha_fin,dependencia_autorizada,estado_memorando,id_usuario_registro)
    values('MEMO-D-HOY',v_emp,current_date-3,current_date,'Dir Admin','VIGENTE',v_admin) returning id_memorando into v_memo_hoy;
  insert into public.persona_memorando(id_memorando,id_persona,estado_acceso) values(v_memo_hoy,v_ext_hoy,'ACTIVO');
  insert into public.autorizacion_visita_diaria(id_persona,fecha_visita,motivo,estado_autorizacion,id_usuario_registro)
    values(v_ext_auth,current_date,'Reunion','VIGENTE',v_admin);

  select via_vigencia into v_via from public.vista_vigencia_acceso where id_persona=v_int;
  insert into _res values('D. Vistas','D1 vigencia INTERNA activa -> INTERNA_ACTIVA (D20)','INTERNA_ACTIVA',coalesce(v_via,'(nada)'), v_via='INTERNA_ACTIVA');
  select via_vigencia into v_via from public.vista_vigencia_acceso where id_persona=v_ext_memo;
  insert into _res values('D. Vistas','D2 EXTERNA con memorando vigente -> MEMORANDO (D20)','MEMORANDO',coalesce(v_via,'(nada)'), v_via='MEMORANDO');
  select via_vigencia into v_via from public.vista_vigencia_acceso where id_persona=v_ext_auth;
  insert into _res values('D. Vistas','D3 EXTERNA con autorización diaria hoy -> AUTORIZACION_DIARIA (D20)','AUTORIZACION_DIARIA',coalesce(v_via,'(nada)'), v_via='AUTORIZACION_DIARIA');
  select via_vigencia into v_via from public.vista_vigencia_acceso where id_persona=v_ext_hoy;
  insert into _res values('D. Vistas','D4 memorando que termina HOY sigue vigente (fecha_fin inclusiva, D24)','MEMORANDO',coalesce(v_via,'(nada/vencido)'), v_via='MEMORANDO');
  select count(*) into v_n from public.vista_vigencia_acceso where id_persona=v_ext_sin;
  insert into _res values('D. Vistas','D5 EXTERNA activa sin memorando ni autorización no aparece (denegación por defecto)','0',v_n::text, v_n=0);

  insert into public.zona(nombre_zona,tipo_zona,estado_zona) values('Zona D Test','CAMPUS','ACTIVA') returning id_zona into v_zona;
  insert into public.punto_control(id_zona,nombre_punto,estado_punto) values(v_zona,'PC D Test','ACTIVO') returning id_punto_control into v_pc;
  insert into public.vehiculo(placa,tipo_vehiculo,estado_vehiculo,id_usuario_registro) values('DTA-0001','AUTOMOVIL','ACTIVO',v_admin) returning id_vehiculo into v_veh;
  insert into public.vehiculo(placa,tipo_vehiculo,estado_vehiculo,id_usuario_registro) values('DTA-0002','AUTOMOVIL','ACTIVO',v_admin) returning id_vehiculo into v_veh2;

  insert into public.evento_acceso(id_persona,id_vehiculo,id_punto_control,tipo_movimiento,resultado,origen_registro,es_conductor)
    values(v_int,v_veh,v_pc,'INGRESO','AUTORIZADO','AUTOMATICA',true);
  select count(*), max(limite_horas_aplicable) into v_n, v_lim from public.vista_vehiculos_dentro where id_vehiculo=v_veh;
  insert into _res values('D. Vistas','D6 vehículo con INGRESO sin SALIDA aparece en vista_vehiculos_dentro (D25)','1',v_n::text, v_n=1);
  insert into _res values('D. Vistas','D8 límite imputado al conductor INTERNA = 16 h (D25)','16',coalesce(v_lim::text,'(null)'), v_lim=16);

  insert into public.evento_acceso(id_persona,id_vehiculo,id_punto_control,tipo_movimiento,resultado,origen_registro,es_conductor)
    values(v_int,v_veh,v_pc,'SALIDA','AUTORIZADO','AUTOMATICA',true);
  select count(*) into v_n from public.vista_vehiculos_dentro where id_vehiculo=v_veh;
  insert into _res values('D. Vistas','D7 tras la SALIDA el vehículo desaparece de la vista','0',v_n::text, v_n=0);

  v_ts := now();
  insert into public.evento_acceso(id_persona,id_vehiculo,id_punto_control,tipo_movimiento,resultado,origen_registro,es_conductor,fecha_hora)
    values(v_int,v_veh2,v_pc,'INGRESO','AUTORIZADO','AUTOMATICA',true,v_ts);
  insert into public.evento_acceso(id_persona,id_vehiculo,id_punto_control,tipo_movimiento,resultado,origen_registro,es_conductor,fecha_hora)
    values(v_int,v_veh2,v_pc,'SALIDA','AUTORIZADO','AUTOMATICA',true,v_ts);
  select count(*) into v_n from public.vista_vehiculos_dentro where id_vehiculo=v_veh2;
  insert into _res values('D. Vistas','D9 INGRESO y SALIDA en el mismo instante -> no queda dentro (fix 3e1f9fe)','0',v_n::text, v_n=0);
exception when others then
  insert into _res values('D. Vistas','ERROR en el bloque','-', sqlerrm, false);
end $$;
select seccion, prueba, esperado, obtenido, (case when ok then 'PASA' else 'FALLA' end) as estado from _res order by prueba;
rollback;

\echo '=== MÓDULO E — Job de permanencia pg_cron ==='
-- D25: alerta por permanencia excedida / abandono, imputada al conductor, idempotente.
begin;
create temp table _res(seccion text, prueba text, esperado text, obtenido text, ok boolean) on commit drop;
do $$
declare
  v_cat_doc uuid; v_admin uuid; v_int uuid; v_zona uuid; v_pc uuid;
  v_veh_exc uuid; v_veh_aba uuid; v_ev_exc uuid; v_ev_aba uuid; v_n int; v_tipo text; v_sched text;
begin
  select schedule into v_sched from cron.job where jobname='revisar-permanencia-vehiculos';
  insert into _res values('E. Permanencia','E1 job pg_cron revisar-permanencia-vehiculos cada hora (D25)','0 * * * *',coalesce(v_sched,'(no existe)'), v_sched='0 * * * *');

  select id_categoria into v_cat_doc from public.categoria_persona where codigo_categoria='DOCENTE';
  select us.id_usuario into v_admin from public.usuario_sistema us
    join public.usuario_rol ur on ur.id_usuario=us.id_usuario and ur.estado_asignacion='ACTIVO'
    join public.rol r on r.id_rol=ur.id_rol and r.nombre_rol='ADMINISTRADOR_SISTEMA' limit 1;
  insert into public.persona(tipo_persona,id_categoria,cedula,nombres,apellidos,correo,estado)
    values('INTERNA',v_cat_doc,'1700000901','Kappa','Perm','kappa.p@epn.edu.ec','ACTIVO') returning id_persona into v_int;
  insert into public.zona(nombre_zona,tipo_zona,estado_zona) values('Zona E Test','CAMPUS','ACTIVA') returning id_zona into v_zona;
  insert into public.punto_control(id_zona,nombre_punto,estado_punto) values(v_zona,'PC E Test','ACTIVO') returning id_punto_control into v_pc;
  insert into public.vehiculo(placa,tipo_vehiculo,estado_vehiculo,id_usuario_registro) values('ETA-EXC1','AUTOMOVIL','ACTIVO',v_admin) returning id_vehiculo into v_veh_exc;
  insert into public.vehiculo(placa,tipo_vehiculo,estado_vehiculo,id_usuario_registro) values('ETA-ABA1','AUTOMOVIL','ACTIVO',v_admin) returning id_vehiculo into v_veh_aba;

  insert into public.evento_acceso(id_persona,id_vehiculo,id_punto_control,tipo_movimiento,resultado,origen_registro,es_conductor,fecha_hora)
    values(v_int,v_veh_exc,v_pc,'INGRESO','AUTORIZADO','AUTOMATICA',true, now()-interval '20 hours') returning id_evento into v_ev_exc;
  insert into public.evento_acceso(id_persona,id_vehiculo,id_punto_control,tipo_movimiento,resultado,origen_registro,es_conductor,fecha_hora)
    values(v_int,v_veh_aba,v_pc,'INGRESO','AUTORIZADO','AUTOMATICA',true, now()-interval '80 hours') returning id_evento into v_ev_aba;

  perform public.revisar_permanencia_vehiculos();

  select count(*), max(tipo_alerta) into v_n, v_tipo from public.alerta_seguridad where id_evento=v_ev_exc;
  insert into _res values('E. Permanencia','E2 vehículo excedido (20h>16h) -> 1 alerta VEHICULO_PERMANENCIA_EXCEDIDA (D25)',
    '1 / VEHICULO_PERMANENCIA_EXCEDIDA', v_n::text||' / '||coalesce(v_tipo,'(nada)'), v_n=1 and v_tipo='VEHICULO_PERMANENCIA_EXCEDIDA');
  select count(*), max(tipo_alerta) into v_n, v_tipo from public.alerta_seguridad where id_evento=v_ev_aba;
  insert into _res values('E. Permanencia','E3 vehículo con 80h dentro -> alerta VEHICULO_ABANDONADO (D25)',
    '1 / VEHICULO_ABANDONADO', v_n::text||' / '||coalesce(v_tipo,'(nada)'), v_n=1 and v_tipo='VEHICULO_ABANDONADO');
  perform public.revisar_permanencia_vehiculos();
  select count(*) into v_n from public.alerta_seguridad where id_evento=v_ev_exc;
  insert into _res values('E. Permanencia','E4 idempotencia: segunda corrida no duplica la alerta (D25)','1',v_n::text, v_n=1);
exception when others then
  insert into _res values('E. Permanencia','ERROR en el bloque','-', sqlerrm, false);
end $$;
select seccion, prueba, esperado, obtenido, (case when ok then 'PASA' else 'FALLA' end) as estado from _res order by prueba;
rollback;

\echo '=== MÓDULO F — Matriz de permisos (rol_permiso vs doc 02) ==='
-- 02 (matriz por rol), D3/D5/D6/D7 (revertida), E7 (100 permisos + 2 nuevos), E8 (supervisor CAC).
begin;
create temp table _res(seccion text, prueba text, esperado text, obtenido text, ok boolean) on commit drop;
create or replace function pg_temp.perms(p_rol text) returns text[] language sql stable as $$
  select coalesce(array_agg(pm.codigo_permiso order by pm.codigo_permiso),'{}')
  from public.rol r
  join public.rol_permiso rp on rp.id_rol=r.id_rol and rp.estado_asignacion='ACTIVO'
  join public.permiso pm on pm.id_permiso=rp.id_permiso and pm.estado_permiso='ACTIVO'
  where r.nombre_rol=p_rol;
$$;
do $$
declare v_n int; v_a text[]; v_b text[];
begin
  select count(*) into v_n from public.permiso;
  insert into _res values('F. Permisos','F1 catálogo de 100 permisos sembrados (E7)','100',v_n::text, v_n=100);
  select count(*) into v_n from public.permiso where codigo_permiso in ('ADM_BIOMETRIA_SELECT','CAC_AUTORIZACION_SELECT');
  insert into _res values('F. Permisos','F2 permisos nuevos ADM_BIOMETRIA_SELECT y CAC_AUTORIZACION_SELECT existen (E7)','2',v_n::text, v_n=2);

  v_a := pg_temp.perms('ADMINISTRADOR_SISTEMA');
  select array_agg(codigo_permiso) into v_b from public.permiso where codigo_permiso like 'ADM\_%';
  insert into _res values('F. Permisos','F3 ADMIN posee ADM_MODULO_ACCEDER + todos los ADM_*','todos ADM_*',
    (case when 'ADM_MODULO_ACCEDER'=any(v_a) and v_b <@ v_a then 'ok' else 'faltan ADM_*' end), 'ADM_MODULO_ACCEDER'=any(v_a) and v_b <@ v_a);
  insert into _res values('F. Permisos','F4 ADMIN no tiene ningún PERSONA_INSERT (D5)','sin PERSONA_INSERT',
    (case when exists(select 1 from unnest(v_a) x where x like '%PERSONA_INSERT') then 'tiene!' else 'ninguno' end),
    not exists(select 1 from unnest(v_a) x where x like '%PERSONA_INSERT'));

  v_a := pg_temp.perms('DIRECTOR_ADMINISTRATIVO');
  insert into _res values('F. Permisos','F5 DIRECTOR sin ningún _INSERT ni _UPDATE (solo lectura, 02)','sin INSERT/UPDATE',
    (case when exists(select 1 from unnest(v_a) x where x like '%\_INSERT' or x like '%\_UPDATE') then 'tiene escritura!' else 'solo lectura' end),
    not exists(select 1 from unnest(v_a) x where x like '%\_INSERT' or x like '%\_UPDATE'));

  v_a := pg_temp.perms('RESPONSABLE_PERSONAL_EXTERNO');
  insert into _res values('F. Permisos','F6 GPE sin ningún permiso *BIOMETRIA* (D7 revertida, D20)','ninguno',
    (case when exists(select 1 from unnest(v_a) x where x like '%BIOMETRIA%') then 'tiene!' else 'ninguno' end),
    not exists(select 1 from unnest(v_a) x where x like '%BIOMETRIA%'));

  v_a := pg_temp.perms('RESPONSABLE_PERSONAL_INTERNO');
  insert into _res values('F. Permisos','F7 GPI posee GPI_BIOMETRIA_INSERT (interno con biometría, D20)','sí',
    (case when 'GPI_BIOMETRIA_INSERT'=any(v_a) then 'sí' else 'no' end), 'GPI_BIOMETRIA_INSERT'=any(v_a));

  v_a := pg_temp.perms('GUARDIA_SEGURIDAD');
  insert into _res values('F. Permisos','F8 GUARDIA posee el set operativo (CAC_PERSONA_EXTERNA_INSERT, CAC_AUTORIZACION_INSERT/UPDATE, CAC_EVENTO_INSERT, CAC_EVENTO_SELECT_PUNTO_ASIGNADO, GPE_MEMORANDO_SELECT, ADM_VEHICULO_SELECT) (02/D3/D6)','todos presentes',
    (case when array['CAC_PERSONA_EXTERNA_INSERT','CAC_AUTORIZACION_INSERT','CAC_AUTORIZACION_UPDATE','CAC_EVENTO_INSERT','CAC_EVENTO_SELECT_PUNTO_ASIGNADO','GPE_MEMORANDO_SELECT','ADM_VEHICULO_SELECT'] <@ v_a then 'ok' else 'falta alguno' end),
    array['CAC_PERSONA_EXTERNA_INSERT','CAC_AUTORIZACION_INSERT','CAC_AUTORIZACION_UPDATE','CAC_EVENTO_INSERT','CAC_EVENTO_SELECT_PUNTO_ASIGNADO','GPE_MEMORANDO_SELECT','ADM_VEHICULO_SELECT'] <@ v_a);
  insert into _res values('F. Permisos','F8b GUARDIA sin CAC_REGLA_* ni CAC_ASIGNACION_INSERT/UPDATE (02)','ninguno',
    (case when exists(select 1 from unnest(v_a) x where x like 'CAC_REGLA_%') or 'CAC_ASIGNACION_INSERT'=any(v_a) or 'CAC_ASIGNACION_UPDATE'=any(v_a) then 'tiene!' else 'ninguno' end),
    not (exists(select 1 from unnest(v_a) x where x like 'CAC_REGLA_%') or 'CAC_ASIGNACION_INSERT'=any(v_a) or 'CAC_ASIGNACION_UPDATE'=any(v_a)));
  insert into _res values('F. Permisos','F8c GUARDIA con CAC_MODULO_ACCEDER y sin ADM_MODULO_ACCEDER (allowed_modules=[CAC])','CAC sí / ADM no',
    (case when 'CAC_MODULO_ACCEDER'=any(v_a) and not 'ADM_MODULO_ACCEDER'=any(v_a) then 'ok' else 'mal' end),
    'CAC_MODULO_ACCEDER'=any(v_a) and not 'ADM_MODULO_ACCEDER'=any(v_a));

  v_a := pg_temp.perms('RESPONSABLE_CONTROL_ACCESOS');
  insert into _res values('F. Permisos','F9 Supervisor CAC sin CAC_PERSONA_EXTERNA_INSERT (02) ni CAC_EVENTO_INSERT / CAC_AUTORIZACION_INSERT/UPDATE (E8)','ninguno de esos',
    (case when 'CAC_PERSONA_EXTERNA_INSERT'=any(v_a) or 'CAC_EVENTO_INSERT'=any(v_a) or 'CAC_AUTORIZACION_INSERT'=any(v_a) or 'CAC_AUTORIZACION_UPDATE'=any(v_a) then 'tiene alguno!' else 'ninguno' end),
    not ('CAC_PERSONA_EXTERNA_INSERT'=any(v_a) or 'CAC_EVENTO_INSERT'=any(v_a) or 'CAC_AUTORIZACION_INSERT'=any(v_a) or 'CAC_AUTORIZACION_UPDATE'=any(v_a)));
  insert into _res values('F. Permisos','F9b Supervisor CAC sí posee CAC_ALERTA_ATENDER y CAC_REGLA_INSERT/UPDATE (02)','ambos',
    (case when 'CAC_ALERTA_ATENDER'=any(v_a) and 'CAC_REGLA_INSERT'=any(v_a) and 'CAC_REGLA_UPDATE'=any(v_a) then 'ok' else 'falta' end),
    'CAC_ALERTA_ATENDER'=any(v_a) and 'CAC_REGLA_INSERT'=any(v_a) and 'CAC_REGLA_UPDATE'=any(v_a));
end $$;
select seccion, prueba, esperado, obtenido, (case when ok then 'PASA' else 'FALLA' end) as estado from _res order by prueba;
rollback;

\echo '=== FIN suite de cobertura (RLS conductual por rol: scripts/pruebas_rls_por_rol.sql) ==='
