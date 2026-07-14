-- Vista de vigencia (§7 del PDF): combina personal interno activo
-- (permanente), memorando vigente y autorizacion diaria vigente, para
-- responder "¿puede entrar hoy?" sin duplicar datos. Al ser una vista, nunca
-- queda desincronizada del dato original.
--
-- security_invoker = true: la vista respeta el RLS de quien consulta, no el
-- del dueño de la vista (recomendacion de seguridad de Supabase para vistas).

create or replace view public.vista_vigencia_acceso
with (security_invoker = true)
as
select
  p.id_persona,
  p.tipo_persona,
  'INTERNA_ACTIVA'::text as via_vigencia,
  null::uuid as id_memorando,
  null::uuid as id_autorizacion,
  null::date as vigente_hasta
from public.persona p
where p.tipo_persona = 'INTERNA'
  and p.estado = 'ACTIVO'

union all

-- §D24: memorando.fecha_fin es inclusiva.
select
  p.id_persona,
  p.tipo_persona,
  'MEMORANDO'::text as via_vigencia,
  m.id_memorando,
  null::uuid as id_autorizacion,
  m.fecha_fin as vigente_hasta
from public.persona p
join public.persona_memorando pm on pm.id_persona = p.id_persona and pm.estado_acceso = 'ACTIVO'
join public.memorando m on m.id_memorando = pm.id_memorando
where p.tipo_persona = 'EXTERNA'
  and p.estado = 'ACTIVO'
  and current_date between m.fecha_inicio and m.fecha_fin

union all

select
  p.id_persona,
  p.tipo_persona,
  'AUTORIZACION_DIARIA'::text as via_vigencia,
  null::uuid as id_memorando,
  a.id_autorizacion,
  a.fecha_visita as vigente_hasta
from public.persona p
join public.autorizacion_visita_diaria a on a.id_persona = p.id_persona
where p.tipo_persona = 'EXTERNA'
  and p.estado = 'ACTIVO'
  and a.estado_autorizacion = 'VIGENTE'
  and a.fecha_visita = current_date;

grant select on public.vista_vigencia_acceso to authenticated;
