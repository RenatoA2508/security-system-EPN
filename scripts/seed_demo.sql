-- scripts/seed_demo.sql
--
-- Datos DEMO (opcionales) para poder ejercitar las Edge Functions y el flujo
-- de acceso end-to-end sin capturar biometria real. NO son parte del modelo de
-- seguridad; son un escenario de demostracion.
--
-- Depende de que exista el punto de control demo (00000000-...-006), creado por
-- el bootstrap (seed.sql local o scripts/seed_remoto.mjs remoto).
--
-- Idempotente (ON CONFLICT / NOT EXISTS). Ejecutar contra local o remoto.
--   Local:  psql "$LOCAL_DB_URL" -f scripts/seed_demo.sql
--   Remoto: via el MCP de Supabase o el editor SQL del dashboard.

-- Dispositivo biometrico OPERATIVO en la garita principal demo (para la vía
-- AUTOMATICA de registrar-evento-acceso: valida codigo_mac + direccion_ip).
insert into public.dispositivo (id_dispositivo, id_punto_control, direccion_ip, codigo_mac, tipo_tecnologia, estado_dispositivo)
values ('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-000000000006', '10.0.0.10', 'AA:BB:CC:DD:EE:FF', 'BIOMETRIA_FACIAL', 'OPERATIVO')
on conflict (id_dispositivo) do nothing;

-- Reglas de acceso (todo el dia) para DOCENTE y VISITANTE en la garita demo.
insert into public.regla_acceso (id_regla_acceso, nombre_regla, id_punto_control, id_categoria, requiere_memorando, horario_inicio, horario_fin, estado_regla)
select '00000000-0000-0000-0000-0000000000d2', 'Demo DOCENTE garita principal', '00000000-0000-0000-0000-000000000006', id_categoria, false, '00:00:00', '23:59:59', 'ACTIVA'
from public.categoria_persona where codigo_categoria = 'DOCENTE'
on conflict (id_regla_acceso) do nothing;

insert into public.regla_acceso (id_regla_acceso, nombre_regla, id_punto_control, id_categoria, requiere_memorando, horario_inicio, horario_fin, estado_regla)
select '00000000-0000-0000-0000-0000000000d3', 'Demo VISITANTE garita principal', '00000000-0000-0000-0000-000000000006', id_categoria, false, '00:00:00', '23:59:59', 'ACTIVA'
from public.categoria_persona where codigo_categoria = 'VISITANTE'
on conflict (id_regla_acceso) do nothing;

-- Docente demo (INTERNA) con biometria vigente: valida-biometria devuelve
-- match:true y el ingreso peatonal AUTOMATICA queda AUTORIZADO.
insert into public.persona (id_persona, tipo_persona, id_categoria, cedula, nombres, apellidos, correo, estado)
select '00000000-0000-0000-0000-0000000000da', 'INTERNA', id_categoria, '1750000208', 'Docente', 'Demo', 'docente.demo@epn.edu.ec', 'ACTIVO'
from public.categoria_persona where codigo_categoria = 'DOCENTE'
on conflict (id_persona) do nothing;

insert into public.registro_biometrico (id_persona, tipo_dato, path_storage, vigente)
select '00000000-0000-0000-0000-0000000000da', 'FACIAL', 'registro-biometrico/demo/docente.jpg', true
where not exists (select 1 from public.registro_biometrico where id_persona = '00000000-0000-0000-0000-0000000000da' and vigente = true);

-- Visitante demo (EXTERNA) con autorizacion de visita diaria de HOY: valida la
-- vía MANUAL/cedula (§D20) del guardia. id_usuario_registro = el guardia demo.
insert into public.persona (id_persona, tipo_persona, id_categoria, cedula, nombres, apellidos, correo, estado)
select '00000000-0000-0000-0000-0000000000db', 'EXTERNA', id_categoria, '1750000067', 'Visitante', 'Demo', 'visita.demo@example.com', 'ACTIVO'
from public.categoria_persona where codigo_categoria = 'VISITANTE'
on conflict (id_persona) do nothing;

insert into public.autorizacion_visita_diaria (id_persona, fecha_visita, motivo, estado_autorizacion, id_usuario_registro)
select '00000000-0000-0000-0000-0000000000db', current_date, 'Entrega de documentos (demo)', 'VIGENTE',
       (select us.id_usuario from public.usuario_sistema us
          join public.usuario_rol ur on ur.id_usuario = us.id_usuario
          join public.rol r on r.id_rol = ur.id_rol
         where r.nombre_rol = 'GUARDIA_SEGURIDAD' limit 1)
where not exists (
  select 1 from public.autorizacion_visita_diaria
   where id_persona = '00000000-0000-0000-0000-0000000000db' and fecha_visita = current_date
);
