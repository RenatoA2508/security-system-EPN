-- fecha_modificacion / fecha_actualizacion automatica en cada UPDATE.
-- Solo las tablas que declaran esa columna en el Modelo de Datos Consolidado:
-- persona, usuario_sistema, parametro_sistema (fecha_modificacion) y
-- vehiculo (fecha_actualizacion, mismo proposito con otro nombre).

create or replace function public.set_fecha_modificacion()
returns trigger
language plpgsql
as $$
begin
  new.fecha_modificacion = now();
  return new;
end;
$$;

create trigger trg_persona_fecha_modificacion
before update on public.persona
for each row execute function public.set_fecha_modificacion();

create trigger trg_usuario_sistema_fecha_modificacion
before update on public.usuario_sistema
for each row execute function public.set_fecha_modificacion();

create trigger trg_parametro_sistema_fecha_modificacion
before update on public.parametro_sistema
for each row execute function public.set_fecha_modificacion();

create or replace function public.set_fecha_actualizacion_vehiculo()
returns trigger
language plpgsql
as $$
begin
  new.fecha_actualizacion = now();
  return new;
end;
$$;

create trigger trg_vehiculo_fecha_actualizacion
before update on public.vehiculo
for each row execute function public.set_fecha_actualizacion_vehiculo();
