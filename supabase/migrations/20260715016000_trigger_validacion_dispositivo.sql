-- Feedback PCO (docs/Req_Front/PCO_Nuevos_Requerimientos.pdf #10): reglas de asignación de
-- dispositivos que hoy no se validan en ningún lado (ni RLS ni trigger, verificado). Se
-- garantizan a nivel de base de datos para que no puedan saltarse por una llamada directa a
-- la API, más allá de cualquier filtro que haga el frontend.
--
-- Reglas:
--  - BIOMETRIA_FACIAL: puede asignarse a cualquier tipo de zona (CAMPUS, EDIFICIO, PARQUEADERO).
--  - LPR_PLACAS: solo a puntos de control dentro de una zona PARQUEADERO.
--  - Máximo de dispositivos por punto de control según el tipo de zona: PARQUEADERO 5,
--    CAMPUS 3, EDIFICIO sin límite. (El mínimo de 1 para CAMPUS es una guía operativa, no
--    aplicable como constraint de inserción — no hay DELETE físico que lo dispare.)

create or replace function public.validar_asignacion_dispositivo()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_tipo_zona text;
  v_cantidad integer;
  v_maximo integer;
begin
  select z.tipo_zona into v_tipo_zona
  from public.punto_control pc
  join public.zona z on z.id_zona = pc.id_zona
  where pc.id_punto_control = new.id_punto_control;

  if v_tipo_zona is null then
    raise exception 'Punto de control % no tiene zona asociada', new.id_punto_control;
  end if;

  if new.tipo_tecnologia = 'LPR_PLACAS' and v_tipo_zona <> 'PARQUEADERO' then
    raise exception 'Un dispositivo de lectura de placas solo puede asignarse a un punto de control en una zona tipo PARQUEADERO (esta es %)', v_tipo_zona;
  end if;

  v_maximo := case v_tipo_zona
    when 'PARQUEADERO' then 5
    when 'CAMPUS' then 3
    else null -- EDIFICIO: sin límite
  end;

  if v_maximo is not null then
    select count(*) into v_cantidad
    from public.dispositivo d
    where d.id_punto_control = new.id_punto_control
      and d.id_dispositivo <> coalesce(new.id_dispositivo, '00000000-0000-0000-0000-000000000000'::uuid);

    if v_cantidad + 1 > v_maximo then
      raise exception 'El punto de control ya tiene el máximo de % dispositivos permitidos para una zona %', v_maximo, v_tipo_zona;
    end if;
  end if;

  return new;
end;
$$;

create trigger trg_validar_asignacion_dispositivo
  before insert or update of id_punto_control, tipo_tecnologia on public.dispositivo
  for each row execute function public.validar_asignacion_dispositivo();
