-- scripts/ajustes_datos_demo_prototipo3.sql
--
-- Cierre de las decisiones de DATOS de la sesión final (prototipo 3). Son ajustes
-- de datos de demostración, no cambios de esquema: por eso viven aquí y no en
-- supabase/migrations/. Se aplicaron contra la base remota vía el MCP el 20/07/2026
-- (db push sigue bloqueado por el historial de migraciones sin reconciliar).
--
-- Todo va en una transacción y es idempotente (los INSERT/UPDATE comprueban antes
-- de tocar), así que se puede reejecutar sin duplicar nada.
--
-- Decisiones que NO tocan datos (se documentan en docs/99_DUDAS_PARA_EL_EQUIPO.md):
--   §V11  Las 18 cédulas "ficticias" son las cuentas y personas de demostración del
--         propio sistema (admin, guardia_demo, las 6 cuentas del equipo que usan
--         TODOS los planes de TestSprite, y las personas de calibración biométrica).
--         Son estructuralmente válidas. Sustituirlas rompería la batería de
--         integración y el enrolamiento biométrico → se ACEPTAN como datos de demo.
--   §V29  El guardia_demo ya opera: la ronda de CAC lo reasignó a "Garita Principal
--         (demo)", que está ACTIVA. El punto en MANTENIMIENTO ("Laboratorio de
--         Suelos") no es el suyo y su estado es correcto → no se toca.
--   §V12  No hay integración con el SRI; se ACEPTA. La pantalla de empresas ahora
--         avisa "sin verificar" en vez de callarlo (cambio en el frontend).

begin;

-- §V24 — El parqueadero cuelga del campus; la jerarquía exige Campus→Edificio→Parqueadero.
-- EARME es un edificio real de la EPN (Aulas y Relación con el Medio Externo): se crea
-- y se reasigna el parqueadero bajo él, en vez de relajar el trigger de jerarquía.
insert into public.zona (nombre_zona, tipo_zona, estado_zona, id_zona_padre)
select 'Edificio EARME - Aulas y Relación con el Medio Externo', 'EDIFICIO', 'ACTIVA', z.id_zona
  from public.zona z
 where z.nombre_zona = 'Campus EPN' and z.tipo_zona = 'CAMPUS'
   and not exists (select 1 from public.zona e where e.nombre_zona like 'Edificio EARME%' and e.tipo_zona = 'EDIFICIO');

update public.zona
   set id_zona_padre = (select id_zona from public.zona where nombre_zona like 'Edificio EARME%' and tipo_zona = 'EDIFICIO' limit 1)
 where nombre_zona = 'Parqueadero Subsuelo EARME' and tipo_zona = 'PARQUEADERO';

-- §V31 — Dos vehículos sin propietario (RF-CA-018). No se puede saber de quién son de
-- verdad; se asigna un propietario de demostración coherente entre el personal interno.
-- PDF7777 (Mazda) → Hernán Avellaneda. PDF1234 (Hyundai, que Joel conduce) → Cecilia
-- Jaramillo, dejando a Joel como conductor autorizado (dueño y conductor distintos).
insert into public.persona_vehiculo (id_persona, id_vehiculo, tipo_relacion, fecha_inicio, estado_relacion, id_usuario_registro, es_responsable_tramite)
select p.id_persona, v.id_vehiculo, 'PROPIETARIO', now(), 'ACTIVA',
       (select us.id_usuario from public.usuario_sistema us
          join public.usuario_rol ur on ur.id_usuario = us.id_usuario and ur.estado_asignacion = 'ACTIVO'
          join public.rol r on r.id_rol = ur.id_rol and r.nombre_rol = 'ADMINISTRADOR_SISTEMA' limit 1),
       true
  from public.vehiculo v, public.persona p
 where v.placa = 'PDF7777' and p.nombres = 'Hernán' and p.apellidos = 'Avellaneda'
   and not exists (select 1 from public.persona_vehiculo pv where pv.id_vehiculo = v.id_vehiculo and pv.tipo_relacion = 'PROPIETARIO' and pv.estado_relacion = 'ACTIVA');

insert into public.persona_vehiculo (id_persona, id_vehiculo, tipo_relacion, fecha_inicio, estado_relacion, id_usuario_registro, es_responsable_tramite)
select p.id_persona, v.id_vehiculo, 'PROPIETARIO', now(), 'ACTIVA',
       (select us.id_usuario from public.usuario_sistema us
          join public.usuario_rol ur on ur.id_usuario = us.id_usuario and ur.estado_asignacion = 'ACTIVO'
          join public.rol r on r.id_rol = ur.id_rol and r.nombre_rol = 'ADMINISTRADOR_SISTEMA' limit 1),
       true
  from public.vehiculo v, public.persona p
 where v.placa = 'PDF1234' and p.nombres = 'Cecilia' and p.apellidos = 'Jaramillo'
   and not exists (select 1 from public.persona_vehiculo pv where pv.id_vehiculo = v.id_vehiculo and pv.tipo_relacion = 'PROPIETARIO' and pv.estado_relacion = 'ACTIVA');

-- §V41 — Un punto de control en edificio no seguía el estándar E<edificio>/P<piso>/E<espacio>
-- (§D78). El equipo confirmó el Alan Turing como E20/P4/E004 (el ejemplo del doc v2). El
-- "Laboratorio de Suelos" se deja con su nombre descriptivo hasta conocer su aula (además está
-- en MANTENIMIENTO, no lo usa ningún guardia ahora). El separador " – " es el que compone la
-- pantalla (componerNombrePuntoEPN).
update public.punto_control
   set nombre_punto = 'E20/P4/E004 – Laboratorio Alan Turing'
 where nombre_punto = 'Puerta - Laboratorio "Alan Turing"'
   and id_zona = (select id_zona from public.zona where nombre_zona like 'Edificio 20 %' limit 1);

-- §V42 — La única asignación de guardia activa sin fecha de fin (guardia_demo, desde el
-- 19/07). Se cierra al 31/12/2026: cubre con holgura el periodo de la defensa del
-- prototipo, y deja de ser la única asignación incompleta del sistema.
update public.guardia_punto_control
   set fecha_fin = timestamptz '2026-12-31 23:59:59-05'
 where id_asignacion = '46a99012-2a49-4bb4-bb9d-fa9707db7363' and fecha_fin is null;

-- Verificación: los contadores de la fotografía deben quedar en cero.
select 'V31 vehiculos sin propietario' as comprobacion,
       (select count(*) from public.vehiculo v
         where v.estado_vehiculo <> 'DADO_DE_BAJA'
           and not exists (select 1 from public.persona_vehiculo pv where pv.id_vehiculo = v.id_vehiculo and pv.tipo_relacion = 'PROPIETARIO' and pv.estado_relacion = 'ACTIVA'))::text as valor
union all
select 'V24 parqueaderos colgando del campus',
       (select count(*) from public.zona h join public.zona p on p.id_zona = h.id_zona_padre where h.tipo_zona = 'PARQUEADERO' and p.tipo_zona = 'CAMPUS')::text
union all
select 'V42 asignaciones activas sin fecha_fin',
       (select count(*) from public.guardia_punto_control where estado_asignacion = 'ACTIVA' and fecha_fin is null)::text;

commit;
