-- Calibracion de los dos reconocimientos (peticion de CAC: "ajustar los umbrales de ambas
-- autenticaciones para que funcionen correctamente, tal cual la vida real").
--
-- MEDICION SOBRE EL BANCO REAL (19/07/2026, 3 rostros enrolados). Distancia L2 entre
-- descriptores de personas DISTINTAS:
--     Guerra  <-> Jumbo      0.6910
--     Guerra  <-> Jaramillo  0.6949
--     Jumbo   <-> Jaramillo  0.7423
-- El umbral vigente (0.38 de confianza = 0.62 de distancia) dejaba solo 0.071 de margen
-- contra el impostor mas parecido del banco. Un cambio de luz o de angulo mueve un descriptor
-- facilmente mas de 0.07: el sistema estaba a un mal reflejo de autorizar a la persona
-- equivocada. Ese es el fallo que un umbral "de manual" (0.6 de dlib) no revela hasta que se
-- prueba con caras reales.
--
-- Se sustituye el umbral unico por DOS, que es lo que hace un control de acceso real:
--   UMBRAL_BIOMETRIA            0.45  (distancia <= 0.55) -> se autoriza sin intervencion
--   UMBRAL_BIOMETRIA_REVISION   0.35  (distancia <= 0.65) -> el guardia confirma visualmente
--   por debajo de 0.35                                    -> PERSONA_DESCONOCIDA (RF-CA-021)
-- Margen contra el impostor mas cercano: 0.141 de distancia, el doble que antes. Y el
-- impostor mas parecido (0.309) queda por debajo incluso de la banda de revision, asi que no
-- llega a plantearsele al guardia.
--
-- No se sube mas porque el otro lado tambien cuesta: por encima de 0.50 de confianza empiezan
-- a caerse capturas legitimas con mascarilla, gafas o contraluz, y un guardia que ve fallar el
-- rostro tres de cada diez veces deja de usarlo y teclea la cedula. Un umbral que nadie usa no
-- protege nada.

update public.parametro_sistema
   set valor_parametro = '0.45',
       descripcion = 'Confianza minima (= 1 - distancia L2) para autorizar un rostro sin que intervenga el guardia. 0.45 = distancia L2 maxima de 0.55. Calibrado con el banco real: personas distintas se separan a partir de 0.691.',
       fecha_modificacion = now()
 where codigo_parametro = 'UMBRAL_BIOMETRIA';

insert into public.parametro_sistema
  (codigo_parametro, nombre_parametro, descripcion, modulo_aplicacion, tipo_dato,
   valor_parametro, estado_parametro, editable, unidad_medida)
values
  ('UMBRAL_BIOMETRIA_REVISION', 'Umbral de revision biometrica',
   'Confianza desde la cual el rostro es un candidato plausible pero NO se autoriza solo: el guardia confirma visualmente. Por debajo, el evento se registra como persona desconocida (RF-CA-021).',
   'SEGURIDAD', 'DECIMAL', '0.35', 'ACTIVO', true, 'DISTANCIA'),

  ('UMBRAL_PLACA', 'Umbral de confianza del reconocimiento de placas',
   'Confianza minima [0,1] del lector de placas para aceptar la lectura sin que el guardia la confirme.',
   'SEGURIDAD', 'DECIMAL', '0.80', 'ACTIVO', true, 'PORCENTAJE'),

  ('UMBRAL_PLACA_REVISION', 'Umbral de revision del reconocimiento de placas',
   'Confianza desde la cual la lectura de la placa se muestra al guardia para confirmarla o corregirla. Por debajo, se pide repetir la captura.',
   'SEGURIDAD', 'DECIMAL', '0.55', 'ACTIVO', true, 'PORCENTAJE'),

  ('TOLERANCIA_PLACA_CARACTERES', 'Tolerancia de caracteres en la placa',
   'Caracteres de diferencia admitidos al buscar la placa leida en la base. Cubre las confusiones tipicas del OCR (O/0, I/1, S/5, B/8). Solo se acepta si UNA sola placa registrada queda a esa distancia y el guardia lo confirma.',
   'SEGURIDAD', 'ENTERO', '1', 'ACTIVO', true, 'CARACTERES')
on conflict (codigo_parametro) do update
   set valor_parametro = excluded.valor_parametro,
       descripcion = excluded.descripcion,
       fecha_modificacion = now();
