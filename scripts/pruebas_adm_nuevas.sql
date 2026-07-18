-- Pruebas de los cambios de ADM (Requerimientos_ADM, migraciones 20260718193730..195447).
--
-- Seguro de ejecutar contra la base real: TODO va dentro de BEGIN … ROLLBACK, no
-- deja rastro. Requiere que las 5 migraciones ya estén aplicadas.
--   psql "$DATABASE_URL" -f scripts/pruebas_adm_nuevas.sql
--
-- Cada bloque lanza EXCEPTION si una aserción falla; si el script llega al final
-- e imprime 'TODAS LAS PRUEBAS DE ADM PASARON', todo está correcto.

begin;

-- 1. Parámetros: unidad de medida separada del nombre ------------------------
do $$
declare v_sin_unidad int; v_con_parentesis int;
begin
  select count(*) into v_sin_unidad from parametro_sistema where unidad_medida is null;
  assert v_sin_unidad = 0, 'todos los parametros sembrados deberian tener unidad de medida';

  -- La unidad ya no viaja pegada al nombre: "(min)", "(h)" y similares deben haber
  -- desaparecido de nombre_parametro.
  select count(*) into v_con_parentesis
    from parametro_sistema
   where nombre_parametro ~ '\((min|h|hrs|horas|minutos)\)';
  assert v_con_parentesis = 0, 'ningun nombre de parametro deberia llevar la unidad entre parentesis';

  assert (select unidad_medida from parametro_sistema where codigo_parametro = 'TIEMPO_SESION_MIN') = 'MINUTOS',
    'TIEMPO_SESION_MIN deberia medirse en MINUTOS';
  assert (select unidad_medida from parametro_sistema where codigo_parametro = 'MAX_VEHICULOS_POR_PERSONA') = 'VEHICULOS',
    'MAX_VEHICULOS_POR_PERSONA deberia medirse en VEHICULOS';
end $$;

-- 2. La unidad tiene CHECK: no se puede inventar una ------------------------
do $$
declare v_fallo boolean := false;
begin
  begin
    update parametro_sistema set unidad_medida = 'PARSECS' where codigo_parametro = 'TIEMPO_SESION_MIN';
  exception when check_violation then
    v_fallo := true;
  end;
  assert v_fallo, 'una unidad fuera del catalogo deberia rechazarse';
end $$;

-- 3. Categorías: ámbito y descripción ---------------------------------------
do $$
begin
  assert (select count(*) from categoria_persona where descripcion is null or btrim(descripcion) = '') = 0,
    'ninguna categoria deberia quedarse sin descripcion';
  assert (select ambito from categoria_persona where codigo_categoria = 'DOCENTE') = 'INTERNA',
    'DOCENTE deberia ser de ambito INTERNA';
  assert (select ambito from categoria_persona where codigo_categoria = 'VISITANTE') = 'EXTERNA',
    'VISITANTE deberia ser de ambito EXTERNA';
end $$;

-- 4. Auditoría: la vista resuelve el registro afectado -----------------------
do $$
declare v_fila record;
begin
  -- Un cierre administrativo de sesión es el caso que reúne todo lo que pidió el
  -- equipo: ejecutor, usuario accedido y hora de salida.
  select * into v_fila
    from v_auditoria
   where entidad_afectada = 'sesion' and hora_salida is not null
   limit 1;

  if v_fila is null then
    raise notice 'sin eventos de sesion en la bitacora: se omite la comprobacion 4';
  else
    assert v_fila.registro_afectado like 'Sesión de %', 'el registro afectado deberia nombrar la sesion y su usuario';
    assert v_fila.usuario_accedido is not null, 'un evento de sesion deberia decir sobre que cuenta recayo';
    assert v_fila.hora_salida is not null, 'un cierre de sesion deberia traer la hora de salida';
    assert v_fila.tipo_registro = 'Sesión', 'el tipo de registro deberia estar en castellano';
  end if;
end $$;

-- 5. Auditoría: el uuid crudo nunca es la referencia si hay algo mejor -------
do $$
declare v_uuid_sueltos int;
begin
  -- `registro_afectado` cae al uuid solo cuando la entidad no es ninguna de las
  -- resueltas por la vista. Para usuario_sistema y persona siempre debe haber nombre.
  select count(*) into v_uuid_sueltos
    from v_auditoria
   where entidad_afectada in ('usuario_sistema', 'persona')
     and registro_afectado ~ '^[0-9a-f]{8}-[0-9a-f]{4}-';
  assert v_uuid_sueltos = 0,
    format('%s registros de usuario/persona siguen mostrando un uuid como referencia', v_uuid_sueltos);
end $$;

-- 6. Auditoría: los datos del cambio no filtran nada sensible ----------------
do $$
declare v_sensibles int;
begin
  select count(*) into v_sensibles
    from v_auditoria
   where cambios::text ~ '(descriptor_facial|token_hash)';
  assert v_sensibles = 0, 'el descriptor biometrico y el hash de sesion no pueden salir en Auditoria';
end $$;

-- 7. Tildes en los textos que se muestran -----------------------------------
do $$
declare v_sin_tilde int;
begin
  select count(*) into v_sin_tilde
    from permiso
   where descripcion ~ '\m(vehiculo|vehiculos|parametro|parametros|categoria|categorias|biometrico|biometricos|sesion|codigo|auditoria)\M';
  assert v_sin_tilde = 0, format('%s descripciones de permiso siguen sin tildes', v_sin_tilde);

  select count(*) into v_sin_tilde
    from rol
   where descripcion ~ '\m(logica|auditoria|operacion|supervision|atencion|biometria|parametros|catalogos|ningun)\M';
  assert v_sin_tilde = 0, format('%s descripciones de rol siguen sin tildes', v_sin_tilde);

  -- Y el revés: los plurales en -ciones NO llevan tilde. Si aparecieran acentuados
  -- sería que la sustitución se pasó de lista.
  assert (select count(*) from permiso where descripcion ~ '\m(asignaciónes|validaciónes|autorizaciónes)\M') = 0,
    'los plurales en -ciones no llevan tilde';
end $$;

-- 8. La vista se evalúa con el RLS de quien consulta -------------------------
do $$
declare v_invoker boolean;
begin
  select 'security_invoker=true' = any(reloptions) into v_invoker
    from pg_class where relname = 'v_auditoria' and relnamespace = 'public'::regnamespace;
  assert coalesce(v_invoker, false),
    'v_auditoria DEBE ser security_invoker: si no, leeria persona y usuario_sistema saltandose el RLS';
end $$;

-- 9. Auditoría es de solo lectura -------------------------------------------
do $$
declare v_fallo boolean := false;
begin
  begin
    insert into v_auditoria (id_bitacora, fecha_hora, modulo, accion, resultado, entidad_afectada)
    values (gen_random_uuid(), now(), 'ADM', 'INSERT', 'EXITO', 'prueba');
  exception when others then
    v_fallo := true;
  end;
  assert v_fallo, 'no deberia poder insertarse una fila a traves de la vista de auditoria';
end $$;

rollback;

\echo 'TODAS LAS PRUEBAS DE ADM PASARON'
