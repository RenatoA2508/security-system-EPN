-- §D70: la estimacion de §D67 se somete a medicion. El valor NO cambia; lo que cambia es que
-- ahora esta medido en vez de estimado, y se sabe cuanto margen tiene.
--
-- MEDICION (scripts/calibracion_biometria, 1200 pares de LFW con el mismo modelo y el mismo
-- detector que usa la garita; 862 pares utiles, 338 descartados porque el detector no encontro
-- rostro en alguna de las dos fotos):
--
--                        n     min     p5   mediana    p95     max
--   MISMA persona      446   0.250  0.325    0.448   0.588   0.948
--   personas DISTINTAS 416   0.566  0.681    0.829   0.963   1.087
--
-- Lo que faltaba y ahora se tiene: la distribucion de la MISMA persona en dos fotos distintas.
-- Con una sola foto por persona en el banco de la EPN, ese numero no existia, y el umbral de
-- §D67 se fijo por el margen que quedaba contra el impostor mas parecido. Resulta que estaba
-- bien puesto:
--
--   confianza  distancia    FAR      FRR
--      0.50       0.50     0.00 %   27.35 %
--      0.45       0.55     0.00 %   10.99 %   <- el vigente
--      0.40       0.60     0.72 %    4.48 %
--      0.35       0.65     2.88 %    4.04 %   <- suelo de la banda de revision
--      0.30       0.70     7.93 %    2.91 %
--
-- A 0.45 no se cuela NI UN impostor de los 416 medidos, y se rechaza al 11 % de los intentos
-- legitimos — que no se pierden: caen en la banda de revision, donde el guardia confirma.
--
-- LO QUE LA MEDICION CORRIGE DE §D67: el margen real es mas estrecho de lo que se creia. Se
-- dijo "0.141 de margen" comparando contra el impostor mas parecido del banco de la EPN
-- (0.691), pero con 416 pares de impostores el mas parecido esta a 0.566, no a 0.691. El margen
-- real es 0.016. Sigue siendo suficiente —FAR medido 0 %— pero es un filo, no un colchon, y
-- conviene volver a medirlo si se cambia el modelo o el detector.
--
-- Por que no se baja a 0.42 (FAR 0.5 %, FRR 5.2 %): en un control de acceso fisico los dos
-- errores no cuestan lo mismo. Rechazar a alguien legitimo cuesta repetir la captura delante de
-- un guardia que esta ahi mismo; aceptar a un impostor es que entre. Con la banda de revision
-- cubriendo el rechazo, no hay razon para pagar FAR a cambio de comodidad.

update public.parametro_sistema
   set descripcion = 'Confianza minima (= 1 - distancia L2) para autorizar un rostro sin que intervenga el guardia. Medido con 862 pares de LFW: no acepta ninguno de los 416 pares de personas distintas y rechaza el 11 % de intentos legitimos, que pasan a revision.',
       fecha_modificacion = now()
 where codigo_parametro = 'UMBRAL_BIOMETRIA';

update public.parametro_sistema
   set descripcion = 'Confianza desde la cual el rostro se le propone al guardia para que confirme visualmente. Recupera la mayor parte del 11 % de intentos legitimos que rechaza el umbral duro. Por debajo, se registra como persona desconocida (RF-CA-021).',
       fecha_modificacion = now()
 where codigo_parametro = 'UMBRAL_BIOMETRIA_REVISION';
