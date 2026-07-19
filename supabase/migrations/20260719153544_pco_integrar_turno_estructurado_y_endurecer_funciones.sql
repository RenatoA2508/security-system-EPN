-- Dos cosas que faltaban tras estructurar el turno.
--
-- 1) `esta_en_turno_guardia` (req 34, ya existente) seguía interpretando el TEXTO de `turno`. Al
--    haber ahora columnas `hora_inicio`/`hora_fin`, había dos fuentes de verdad y la del texto
--    era la peor: dependía de una expresión regular. Pasa a usar las columnas cuando existen y
--    solo cae al texto (rango literal o código MATUTINO/VESPERTINO/NOCTURNO de
--    parametro_sistema) para las filas que aún no se han estructurado. Se conservan intactas la
--    tolerancia y el resto de condiciones —usuario activo, asignación vigente, punto activo—.
--
-- 2) Las funciones nuevas de esta ronda no tenían `search_path` fijo ni permisos acotados, que es
--    lo que marcan los advisors de seguridad y el patrón de
--    20260715124700_endurecer_permisos_funciones_trigger.

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
    select gpc.turno, gpc.hora_inicio, gpc.hora_fin
      from public.guardia_punto_control gpc
      join public.punto_control pc on pc.id_punto_control = gpc.id_punto_control
     where gpc.id_usuario = p_id_usuario
       and gpc.estado_asignacion = 'ACTIVA'
       and gpc.fecha_inicio <= p_momento
       and (gpc.fecha_fin is null or gpc.fecha_fin >= p_momento)
       and pc.estado_punto = 'ACTIVO'
  loop
    -- (a) columnas estructuradas: la fuente de verdad desde esta ronda.
    v_ini := r.hora_inicio;
    v_fin := r.hora_fin;

    if v_ini is null or v_fin is null then
      -- (b) rango literal 'HH:MM-HH:MM' o 'HH:MM–HH:MM' (guion o raya larga).
      m := regexp_match(coalesce(r.turno, ''), '(\d{1,2}:\d{2})\s*[–-]\s*(\d{1,2}:\d{2})');
      if m is not null then
        v_ini := m[1]::time;
        v_fin := m[2]::time;

      -- (c) código de turno con ventana en parametro_sistema.
      elsif upper(btrim(coalesce(r.turno, ''))) in ('MATUTINO', 'VESPERTINO', 'NOCTURNO') then
        select valor_parametro::time into v_ini
          from public.parametro_sistema
         where codigo_parametro = 'TURNO_' || upper(btrim(r.turno)) || '_INICIO';
        select valor_parametro::time into v_fin
          from public.parametro_sistema
         where codigo_parametro = 'TURNO_' || upper(btrim(r.turno)) || '_FIN';
      end if;
    end if;

    -- Turno no interpretable: no habilita (conservador, igual que antes).
    if v_ini is null or v_fin is null then
      continue;
    end if;

    v_ini_min := extract(hour from v_ini)::integer * 60 + extract(minute from v_ini)::integer;
    v_fin_min := extract(hour from v_fin)::integer * 60 + extract(minute from v_fin)::integer;

    if v_fin_min >= v_ini_min then
      if v_local_min between (v_ini_min - v_tol_min) and (v_fin_min + v_tol_min) then
        return true;
      end if;
    else
      -- ventana que cruza medianoche (p. ej. 22:00-06:00).
      if v_local_min >= (v_ini_min - v_tol_min) or v_local_min <= (v_fin_min + v_tol_min) then
        return true;
      end if;
    end if;
  end loop;

  return false;
end;
$$;

-- --- Endurecimiento de las funciones nuevas de esta ronda -------------------
alter function public.esta_en_turno(time, time, time)        set search_path = public;
alter function public.hora_ecuador()                          set search_path = public;
alter function public.tramos_turno(time, time)                set search_path = public;
alter function public.es_ubicacion_epn(text)                  set search_path = public;
alter function public.normalizar_ubicacion_epn(text)          set search_path = public;
alter function public.sincronizar_texto_turno()               set search_path = public;

-- Funciones de trigger: no las llama nadie por RPC.
revoke execute on function public.sincronizar_texto_turno()             from public, anon, authenticated;
revoke execute on function public.validar_solapamiento_turno_guardia()  from public, anon, authenticated;

-- OJO: los tres revoke que venían aquí sobre es_usuario_guardia, es_persona_de_guardia y
-- persona_del_usuario_actual estaban MAL y se corrigen en 20260719153611. Una función usada en
-- el USING de una política RLS sí necesita EXECUTE para el rol que consulta.
revoke execute on function public.es_usuario_guardia(uuid)        from public, anon, authenticated;
revoke execute on function public.es_persona_de_guardia(uuid)     from public, anon, authenticated;
revoke execute on function public.persona_del_usuario_actual()    from public, anon, authenticated;

-- Utilidades de cálculo sin datos sensibles: útiles para el espejo del frontend.
revoke execute on function public.esta_en_turno(time, time, time) from public, anon;
grant  execute on function public.esta_en_turno(time, time, time) to authenticated;
revoke execute on function public.tramos_turno(time, time)        from public, anon;
grant  execute on function public.tramos_turno(time, time)        to authenticated;
revoke execute on function public.es_ubicacion_epn(text)          from public, anon;
grant  execute on function public.es_ubicacion_epn(text)          to authenticated;
revoke execute on function public.normalizar_ubicacion_epn(text)  from public, anon;
grant  execute on function public.normalizar_ubicacion_epn(text)  to authenticated;
revoke execute on function public.hora_ecuador()                  from public, anon;
grant  execute on function public.hora_ecuador()                  to authenticated;
