-- vista_vehiculos_dentro (§D25): por cada id_vehiculo, el tiempo transcurrido
-- desde su ultimo INGRESO AUTORIZADO sin SALIDA posterior, y el limite
-- aplicable segun la vigencia de su conductor (es_conductor = true, §D21).
-- No requiere tabla ni columna nueva: es computable con lo que ya existe.

create or replace view public.vista_vehiculos_dentro
with (security_invoker = true)
as
with parametros as (
  select
    max(valor_parametro) filter (where codigo_parametro = 'PERMANENCIA_MAX_INTERNO_H')::numeric as max_interno_h,
    max(valor_parametro) filter (where codigo_parametro = 'PERMANENCIA_MAX_EXTERNO_H')::numeric as max_externo_h,
    max(valor_parametro) filter (where codigo_parametro = 'PERMANENCIA_MAX_VISITA_H')::numeric as max_visita_h,
    max(valor_parametro) filter (where codigo_parametro = 'PERMANENCIA_ABANDONO_H')::numeric as abandono_h
  from public.parametro_sistema
),
ultimo_ingreso as (
  select distinct on (ea.id_vehiculo)
    ea.id_vehiculo,
    ea.id_evento as id_evento_ingreso,
    ea.fecha_hora as fecha_ingreso,
    ea.id_punto_control
  from public.evento_acceso ea
  where ea.id_vehiculo is not null
    and ea.tipo_movimiento = 'INGRESO'
    and ea.resultado = 'AUTORIZADO'
  order by ea.id_vehiculo, ea.fecha_hora desc
),
conductor_ingreso as (
  select ea.id_vehiculo, ea.fecha_hora, ea.id_persona as id_persona_conductor
  from public.evento_acceso ea
  where ea.es_conductor = true
    and ea.resultado = 'AUTORIZADO'
    and ea.tipo_movimiento = 'INGRESO'
)
select
  ui.id_vehiculo,
  v.placa,
  ui.id_evento_ingreso,
  ui.fecha_ingreso,
  ui.id_punto_control,
  ci.id_persona_conductor,
  p.tipo_persona as tipo_persona_conductor,
  round(extract(epoch from (now() - ui.fecha_ingreso)) / 3600.0, 2) as horas_dentro,
  -- Limite segun la via/vigencia del conductor (tabla de §D25). Si el
  -- conductor no encaja en ninguna via reconocible (dato incompleto o
  -- vigencia ya vencida), queda NULL: solo se evalua contra el umbral de
  -- abandono (universal), en vez de asumir una categoria incorrecta.
  case
    when p.tipo_persona = 'INTERNA' and p.estado = 'ACTIVO' then pa.max_interno_h
    when exists (
      select 1
        from public.persona_memorando pm
        join public.memorando m on m.id_memorando = pm.id_memorando
       where pm.id_persona = p.id_persona
         and pm.estado_acceso = 'ACTIVO'
         and current_date between m.fecha_inicio and m.fecha_fin
    ) then pa.max_externo_h
    when exists (
      select 1
        from public.autorizacion_visita_diaria a
       where a.id_persona = p.id_persona
         and a.estado_autorizacion = 'VIGENTE'
         and a.fecha_visita = current_date
    ) then pa.max_visita_h
    else null
  end as limite_horas_aplicable,
  pa.abandono_h as limite_abandono_horas
from ultimo_ingreso ui
cross join parametros pa
join public.vehiculo v on v.id_vehiculo = ui.id_vehiculo
left join conductor_ingreso ci on ci.id_vehiculo = ui.id_vehiculo and ci.fecha_hora = ui.fecha_ingreso
left join public.persona p on p.id_persona = ci.id_persona_conductor
where not exists (
  select 1
    from public.evento_acceso salida
   where salida.id_vehiculo = ui.id_vehiculo
     and salida.tipo_movimiento = 'SALIDA'
     and salida.resultado = 'AUTORIZADO'
     and salida.fecha_hora > ui.fecha_ingreso
);

grant select on public.vista_vehiculos_dentro to authenticated;
