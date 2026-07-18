-- Restringir el acceso operativo del guardia a su turno y hora (req 34).
--
-- Fuente de tiempo: now() del servidor convertido a America/Guayaquil. NUNCA la
-- hora del cliente. Los horarios y la tolerancia viven en parametro_sistema (no
-- hardcodeados). El turno del remoto es heterogeneo (V4): hay codigos
-- ('MATUTINO') y rangos literales ('06:00-20:00', '07:00-17:00'); la funcion
-- entiende ambos. Un turno que no se puede interpretar no habilita el acceso
-- (opcion conservadora; el dato actual si es interpretable).

-- ===========================================================================
-- 1. Parametros de turno (editables, no hardcodeados)
-- ===========================================================================
-- parametro_sistema.tipo_dato no admite TIME; las horas van como TEXTO 'HH:MM'.
insert into public.parametro_sistema
  (codigo_parametro, nombre_parametro, descripcion, modulo_aplicacion, tipo_dato, valor_parametro, estado_parametro, editable)
values
  ('TURNO_MATUTINO_INICIO',   'Inicio turno matutino',   'Hora de inicio del turno MATUTINO (HH:MM, America/Guayaquil).',   'SEGURIDAD', 'TEXTO',  '06:00', 'ACTIVO', true),
  ('TURNO_MATUTINO_FIN',      'Fin turno matutino',      'Hora de fin del turno MATUTINO (HH:MM, America/Guayaquil).',      'SEGURIDAD', 'TEXTO',  '14:00', 'ACTIVO', true),
  ('TURNO_VESPERTINO_INICIO', 'Inicio turno vespertino', 'Hora de inicio del turno VESPERTINO (HH:MM, America/Guayaquil).', 'SEGURIDAD', 'TEXTO',  '14:00', 'ACTIVO', true),
  ('TURNO_VESPERTINO_FIN',    'Fin turno vespertino',    'Hora de fin del turno VESPERTINO (HH:MM, America/Guayaquil).',    'SEGURIDAD', 'TEXTO',  '22:00', 'ACTIVO', true),
  ('TURNO_NOCTURNO_INICIO',   'Inicio turno nocturno',   'Hora de inicio del turno NOCTURNO (HH:MM, America/Guayaquil).',   'SEGURIDAD', 'TEXTO',  '22:00', 'ACTIVO', true),
  ('TURNO_NOCTURNO_FIN',      'Fin turno nocturno',      'Hora de fin del turno NOCTURNO (HH:MM, cruza medianoche).',       'SEGURIDAD', 'TEXTO',  '06:00', 'ACTIVO', true),
  ('TOLERANCIA_INGRESO_GUARDIA_MINUTOS', 'Tolerancia de ingreso del guardia', 'Minutos de gracia antes/despues de la ventana del turno.', 'SEGURIDAD', 'ENTERO', '15', 'ACTIVO', true)
on conflict (codigo_parametro) do nothing;

-- ===========================================================================
-- 2. esta_en_turno_guardia(usuario, momento)
-- ===========================================================================
-- true si el usuario, en ese instante, cumple TODAS las condiciones del req 34:
--   usuario activo + asignacion activa vigente + punto de control activo +
--   hora dentro de la ventana del turno (con tolerancia, cruce de medianoche).
-- SECURITY DEFINER: la llaman triggers y RPC que no pueden ver guardia_punto_control.
create or replace function public.esta_en_turno_guardia(p_id_usuario uuid, p_momento timestamptz default now())
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_local_min integer;
  v_tol_min integer;
  r record;
  m text[];
  v_ini time;
  v_fin time;
  v_ini_min integer;
  v_fin_min integer;
begin
  if p_id_usuario is null then
    return false;
  end if;

  if not exists (select 1 from public.usuario_sistema where id_usuario = p_id_usuario and estado_usuario = 'ACTIVO') then
    return false;
  end if;

  v_local_min := extract(hour from (p_momento at time zone 'America/Guayaquil'))::integer * 60
               + extract(minute from (p_momento at time zone 'America/Guayaquil'))::integer;

  select coalesce(max(valor_parametro::integer), 0) into v_tol_min
    from public.parametro_sistema
   where codigo_parametro = 'TOLERANCIA_INGRESO_GUARDIA_MINUTOS';

  for r in
    select gpc.turno
      from public.guardia_punto_control gpc
      join public.punto_control pc on pc.id_punto_control = gpc.id_punto_control
     where gpc.id_usuario = p_id_usuario
       and gpc.estado_asignacion = 'ACTIVA'
       and gpc.fecha_inicio <= p_momento
       and (gpc.fecha_fin is null or gpc.fecha_fin >= p_momento)
       and pc.estado_punto = 'ACTIVO'
  loop
    v_ini := null;
    v_fin := null;

    -- (a) rango literal 'HH:MM-HH:MM' o 'HH:MM–HH:MM' (guion o raya larga).
    m := regexp_match(r.turno, '(\d{1,2}:\d{2})\s*[–-]\s*(\d{1,2}:\d{2})');
    if m is not null then
      v_ini := m[1]::time;
      v_fin := m[2]::time;

    -- (b) codigo de turno con ventana en parametro_sistema.
    elsif upper(btrim(coalesce(r.turno, ''))) in ('MATUTINO', 'VESPERTINO', 'NOCTURNO') then
      select valor_parametro::time into v_ini
        from public.parametro_sistema
       where codigo_parametro = 'TURNO_' || upper(btrim(r.turno)) || '_INICIO';
      select valor_parametro::time into v_fin
        from public.parametro_sistema
       where codigo_parametro = 'TURNO_' || upper(btrim(r.turno)) || '_FIN';
    end if;

    -- Turno no interpretable: no habilita (conservador).
    if v_ini is null or v_fin is null then
      continue;
    end if;

    v_ini_min := extract(hour from v_ini)::integer * 60 + extract(minute from v_ini)::integer;
    v_fin_min := extract(hour from v_fin)::integer * 60 + extract(minute from v_fin)::integer;

    if v_fin_min >= v_ini_min then
      -- ventana normal en el mismo dia.
      if v_local_min between (v_ini_min - v_tol_min) and (v_fin_min + v_tol_min) then
        return true;
      end if;
    else
      -- ventana que cruza medianoche (p. ej. NOCTURNO 22:00-06:00).
      if v_local_min >= (v_ini_min - v_tol_min) or v_local_min <= (v_fin_min + v_tol_min) then
        return true;
      end if;
    end if;
  end loop;

  return false;
end;
$$;

comment on function public.esta_en_turno_guardia(uuid, timestamptz) is
  'true si el guardia esta activo, con asignacion vigente, punto activo y dentro de la ventana de su turno (America/Guayaquil, con tolerancia). Req 34.';

-- ===========================================================================
-- 3. verificar_turno_guardia_actual(): la usa el frontend antes de operar
-- ===========================================================================
-- Devuelve {permitido, motivo}. No lanza excepcion: el frontend muestra el
-- motivo en español y decide. Solo aplica a quien tenga rol GUARDIA_SEGURIDAD;
-- para el resto de roles siempre permite (no bloquear a nadie por error, req 34).
create or replace function public.verificar_turno_guardia_actual()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_es_guardia boolean;
begin
  if v_uid is null then
    return jsonb_build_object('permitido', false, 'motivo', 'No hay una sesion autenticada.');
  end if;

  select exists (
    select 1 from public.usuario_rol ur join public.rol r on r.id_rol = ur.id_rol
     where ur.id_usuario = v_uid and ur.estado_asignacion = 'ACTIVO'
       and r.nombre_rol = 'GUARDIA_SEGURIDAD' and r.estado_rol = 'ACTIVO'
  ) into v_es_guardia;

  -- Otros roles no se ven afectados por la regla de turno.
  if not v_es_guardia then
    return jsonb_build_object('permitido', true, 'motivo', null);
  end if;

  if public.esta_en_turno_guardia(v_uid, now()) then
    return jsonb_build_object('permitido', true, 'motivo', null);
  end if;

  return jsonb_build_object(
    'permitido', false,
    'motivo', 'Su turno no se encuentra habilitado a esta hora. Comuniquese con el administrador para revisar su asignacion.'
  );
end;
$$;

comment on function public.verificar_turno_guardia_actual() is
  'Chequeo de turno del guardia autenticado para el frontend: {permitido, motivo}. Otros roles siempre permitidos (req 34).';

-- ===========================================================================
-- 4. Registro de intentos denegados (bitacora)
-- ===========================================================================
-- Se llama por separado (transaccion propia) para que el registro persista aun
-- cuando la operacion sensible se rechace. No guarda secretos.
create or replace function public.registrar_intento_fuera_de_turno(p_detalle text default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    return;
  end if;
  insert into public.bitacora_sistema (id_usuario, accion, modulo, entidad_afectada, resultado, descripcion)
  values (
    auth.uid(),
    'ACCESO_FUERA_DE_TURNO',
    'CAC',
    'guardia_punto_control',
    'ERROR',
    coalesce(p_detalle, 'Intento de operar fuera del turno asignado.')
  );
end;
$$;

comment on function public.registrar_intento_fuera_de_turno(text) is
  'Registra en bitacora un intento del guardia de operar fuera de turno (req 34, intentos denegados).';

-- ===========================================================================
-- 5. Barrera dura: trigger sobre evento_acceso
-- ===========================================================================
-- Defensa en profundidad: aunque el frontend ya bloquee, un guardia con token
-- no puede registrar un evento por la API REST fuera de su turno. Los eventos
-- de DISPOSITIVO llegan por Edge Function con service_role (auth.uid() nulo) y
-- NO se ven afectados: la camara no tiene turno.
create or replace function public.exigir_turno_guardia_evento()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    return new; -- dispositivo / service_role
  end if;

  if exists (
    select 1 from public.usuario_rol ur join public.rol r on r.id_rol = ur.id_rol
     where ur.id_usuario = auth.uid() and ur.estado_asignacion = 'ACTIVO'
       and r.nombre_rol = 'GUARDIA_SEGURIDAD' and r.estado_rol = 'ACTIVO'
  ) then
    if not public.esta_en_turno_guardia(auth.uid(), now()) then
      raise exception 'Su turno no se encuentra habilitado a esta hora.'
        using errcode = 'insufficient_privilege',
              hint = 'Comuniquese con el administrador para revisar su asignacion.';
    end if;
  end if;

  return new;
end;
$$;

comment on function public.exigir_turno_guardia_evento() is
  'Barrera dura: un guardia no puede insertar evento_acceso fuera de su turno. Los eventos de dispositivo (service_role) no se ven afectados. Req 34.';

drop trigger if exists trg_exigir_turno_guardia_evento on public.evento_acceso;
create trigger trg_exigir_turno_guardia_evento
before insert on public.evento_acceso
for each row execute function public.exigir_turno_guardia_evento();

-- ===========================================================================
-- 6. Permisos
-- ===========================================================================
revoke execute on function public.esta_en_turno_guardia(uuid, timestamptz) from public, anon;
grant execute on function public.esta_en_turno_guardia(uuid, timestamptz) to authenticated;
-- La Edge Function registrar-evento-acceso (service_role) la usa para bloquear
-- el registro manual fuera de turno.
grant execute on function public.esta_en_turno_guardia(uuid, timestamptz) to service_role;

revoke execute on function public.verificar_turno_guardia_actual() from public, anon;
grant execute on function public.verificar_turno_guardia_actual() to authenticated;

revoke execute on function public.registrar_intento_fuera_de_turno(text) from public, anon;
grant execute on function public.registrar_intento_fuera_de_turno(text) to authenticated;

revoke execute on function public.exigir_turno_guardia_evento() from public, anon, authenticated;
