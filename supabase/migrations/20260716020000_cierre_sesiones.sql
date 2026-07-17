-- Cierre real de las sesiones de la tabla de auditoria `sesion`.
--
-- El problema: registrar_sesion() (20260713190500_autenticacion.sql) insertaba
-- la fila con estado ACTIVA y NADIE la cerraba nunca. cerrarSesion() en el
-- frontend solo llamaba a supabase.auth.signOut(), que no toca public.sesion.
-- Resultado en el proyecto remoto: 170 filas, 170 ACTIVAS, 0 con fecha_cierre.
-- La ventana de sesiones del administrador mostraba como vivas sesiones de
-- hace semanas.
--
-- La solucion tiene tres piezas:
--   1. cerrar_sesion()          -> el logout marca su propia fila como CERRADA.
--   2. expirar_sesiones_vencidas() + pg_cron -> barre las que vencieron sin
--      que nadie hiciera logout (cerrar el navegador, caida de red, etc.).
--   3. Saneamiento de las 170 filas historicas.

-- ---------------------------------------------------------------------------
-- 1. cerrar_sesion: lo llama el frontend justo antes de signOut()
-- ---------------------------------------------------------------------------
-- Cierra la sesion ACTIVA mas reciente del usuario autenticado. SECURITY
-- DEFINER por el mismo motivo que registrar_sesion: la matriz RLS (doc 02) no
-- da UPDATE sobre `sesion` a nadie, ni siquiera al propio dueño.
--
-- Se cierra solo la del usuario actual (auth.uid()): un usuario no puede tocar
-- la sesion de otro por esta via.
create or replace function public.cerrar_sesion()
returns public.sesion
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.sesion;
begin
  if auth.uid() is null then
    raise exception 'cerrar_sesion requiere un usuario autenticado';
  end if;

  update public.sesion
     set estado_sesion = 'CERRADA',
         fecha_cierre = now()
   where id_sesion = (
     select id_sesion
       from public.sesion
      where id_usuario = auth.uid()
        and estado_sesion = 'ACTIVA'
      order by fecha_inicio desc
      limit 1
   )
  returning * into v_row;

  -- Sin fila que cerrar no es un error: puede que el barrido de pg_cron ya la
  -- hubiera marcado EXPIRADA, o que el registro de sesion fallara al entrar.
  return v_row;
end;
$$;

comment on function public.cerrar_sesion() is
  'Marca como CERRADA la sesion ACTIVA mas reciente del usuario autenticado. La llama el frontend antes de signOut().';

-- ---------------------------------------------------------------------------
-- 2. Barrido de sesiones vencidas
-- ---------------------------------------------------------------------------
-- Cubre el caso normal: el usuario cierra el navegador y nunca llama a
-- cerrar_sesion(). Sin esto, la fila se queda ACTIVA para siempre.
--
-- EXPIRADA y CERRADA son cosas distintas a proposito: CERRADA = el usuario
-- salio; EXPIRADA = se le acabo el tiempo. Para auditoria de seguridad, saber
-- cual de las dos ocurrio importa.
create or replace function public.expirar_sesiones_vencidas()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_afectadas integer;
begin
  update public.sesion
     set estado_sesion = 'EXPIRADA',
         fecha_cierre = coalesce(fecha_cierre, fecha_expiracion)
   where estado_sesion = 'ACTIVA'
     and fecha_expiracion < now();

  get diagnostics v_afectadas = row_count;
  return v_afectadas;
end;
$$;

comment on function public.expirar_sesiones_vencidas() is
  'Marca EXPIRADA toda sesion ACTIVA cuya fecha_expiracion ya paso. La ejecuta pg_cron cada 5 minutos.';

-- Cada 5 minutos: TIEMPO_SESION_MIN por defecto es 60, asi que 5 minutos da un
-- desfase maximo aceptable entre la expiracion real y lo que muestra la
-- ventana del administrador, sin cargar la BD.
-- Reprogramacion idempotente (mismo patron que revisar-permanencia-vehiculos).
do $$
begin
  if exists (select 1 from cron.job where jobname = 'expirar-sesiones-vencidas') then
    perform cron.unschedule('expirar-sesiones-vencidas');
  end if;

  perform cron.schedule(
    'expirar-sesiones-vencidas',
    '*/5 * * * *',
    'select public.expirar_sesiones_vencidas();'
  );
end $$;

-- ---------------------------------------------------------------------------
-- 3. Saneamiento del historico
-- ---------------------------------------------------------------------------
-- Las sesiones que quedaron ACTIVA y ya vencieron pasan a EXPIRADA. No se
-- inventa una fecha_cierre: se usa la de expiracion, que es el ultimo momento
-- en que la sesion pudo estar viva.
update public.sesion
   set estado_sesion = 'EXPIRADA',
       fecha_cierre = coalesce(fecha_cierre, fecha_expiracion)
 where estado_sesion = 'ACTIVA'
   and fecha_expiracion < now();

-- ---------------------------------------------------------------------------
-- 4. Coherencia de estado
-- ---------------------------------------------------------------------------
-- Una sesion ACTIVA no puede tener fecha_cierre, y una cerrada/expirada tiene
-- que tenerla. Sin esto nada impide volver al estado inconsistente de partida.
alter table public.sesion drop constraint if exists sesion_cierre_coherente;
alter table public.sesion add constraint sesion_cierre_coherente
  check (
    (estado_sesion = 'ACTIVA' and fecha_cierre is null)
    or (estado_sesion in ('CERRADA', 'EXPIRADA') and fecha_cierre is not null)
  );

-- Acelera tanto el barrido de pg_cron como el filtro "solo activas" de la UI.
create index if not exists idx_sesion_activas
  on public.sesion (id_usuario, fecha_inicio desc)
  where estado_sesion = 'ACTIVA';

-- ---------------------------------------------------------------------------
-- 5. Permisos
-- ---------------------------------------------------------------------------
revoke execute on function public.cerrar_sesion(), public.expirar_sesiones_vencidas() from public, anon;

-- cerrar_sesion la llama el frontend; expirar_sesiones_vencidas solo pg_cron.
grant execute on function public.cerrar_sesion() to authenticated;
revoke execute on function public.expirar_sesiones_vencidas() from authenticated;
