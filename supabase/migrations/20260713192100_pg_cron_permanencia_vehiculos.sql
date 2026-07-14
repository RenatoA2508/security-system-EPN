-- Job programado (§D25, §6.b): unica regla del sistema que se dispara por la
-- AUSENCIA de un evento (la salida que nunca llegó), no por su ocurrencia.
-- Corre cada hora, revisa vista_vehiculos_dentro y genera alertas
-- VEHICULO_PERMANENCIA_EXCEDIDA / VEHICULO_ABANDONADO. Idempotente: no
-- duplica una alerta PENDIENTE del mismo tipo para el mismo evento de ingreso.

-- pg_cron no es reubicable: se instala siempre en su propio esquema `cron`.
create extension if not exists pg_cron;

create or replace function public.revisar_permanencia_vehiculos()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  v_tipo_alerta text;
  v_nivel_riesgo text;
begin
  for r in select * from public.vista_vehiculos_dentro loop
    v_tipo_alerta := null;
    v_nivel_riesgo := null;

    if r.horas_dentro >= r.limite_abandono_horas then
      v_tipo_alerta := 'VEHICULO_ABANDONADO';
      v_nivel_riesgo := 'ALTO';
    elsif r.limite_horas_aplicable is not null and r.horas_dentro >= r.limite_horas_aplicable then
      v_tipo_alerta := 'VEHICULO_PERMANENCIA_EXCEDIDA';
      v_nivel_riesgo := 'MEDIO';
    end if;

    if v_tipo_alerta is not null then
      if not exists (
        select 1
          from public.alerta_seguridad al
         where al.id_evento = r.id_evento_ingreso
           and al.tipo_alerta = v_tipo_alerta
           and al.estado_alerta = 'PENDIENTE'
      ) then
        insert into public.alerta_seguridad (id_evento, tipo_alerta, nivel_riesgo, estado_alerta)
        values (r.id_evento_ingreso, v_tipo_alerta, v_nivel_riesgo, 'PENDIENTE');
      end if;
    end if;
  end loop;
end;
$$;

-- Reprogramar de forma idempotente (evita duplicar el job en cada reset/push).
do $$
begin
  if exists (select 1 from cron.job where jobname = 'revisar-permanencia-vehiculos') then
    perform cron.unschedule('revisar-permanencia-vehiculos');
  end if;

  perform cron.schedule(
    'revisar-permanencia-vehiculos',
    '0 * * * *',
    'select public.revisar_permanencia_vehiculos();'
  );
end $$;
