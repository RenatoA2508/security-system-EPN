-- §D71: los umbrales del lector de placas dejan de ser una estimacion y salen de una medicion.
--
-- MEDICION (scripts/calibracion_placas, 200 imagenes con la placa correcta conocida):
--
--   condicion                 leida bien   leida mal   no se leyo
--   limpia                        90.0 %       0.0 %       10.0 %
--   leve                         100.0 %       0.0 %        0.0 %
--   pantalla del movil            65.0 %      12.5 %       22.5 %
--   pantalla del movil, lejos      5.0 %      30.0 %       65.0 %
--   placa real en malas cond.     70.0 %       7.5 %       22.5 %
--
-- DOS COSAS QUE LA MEDICION DESTAPO
--
-- 1. La confianza que se guardaba era SIEMPRE 0. tesseract.js 5 devuelve `confidence` a cero
--    en todos los niveles (documento, bloque y palabra), asi que el UMBRAL_PLACA anterior
--    (0.80) no filtraba nada: ninguna lectura lo alcanzaba jamas. El parametro existia y no
--    hacia absolutamente nada.
--
--    La confianza pasa a calcularse por ACUERDO ENTRE VARIANTES de preprocesado: las cuatro
--    formas de preparar la imagen son cuatro lectores independientes sobre la misma foto, y
--    que coincidan dice mas de la lectura que cualquier numero que un motor se ponga a si
--    mismo. Medido, esa señal SI separa:
--
--      lecturas correctas    n=132   p5 0.63   mediana 1.00
--      lecturas equivocadas  n= 20   p5 0.38   mediana 0.63   p95 0.75
--
-- 2. La escala cambia, asi que los valores viejos ya no significan lo mismo. Con la nueva:
--
--      umbral   de las aceptadas, equivocadas   correctas que se descartarian
--       0.60                          9.9 %                          3.8 %
--       0.65                          5.6 %                         23.5 %
--       0.75                          1.2 %                         35.6 %
--       0.90                          1.2 %                         37.9 %
--
--    0.75 es donde el error se desploma sin que subir mas aporte nada. Y ese 35.6 % de
--    lecturas correctas no se tira: cae en la banda de revision, donde el guardia confirma la
--    placa que el sistema propone. Es el mismo patron que la biometria (§D67): el sistema
--    propone, la persona decide, y solo lo que no llega ni a proponerse se descarta.

update public.parametro_sistema
   set valor_parametro = '0.75',
       descripcion = 'Acuerdo minimo entre las variantes de preprocesado para aceptar la lectura sin que el guardia la confirme. Medido sobre 200 imagenes: con 0.75 solo el 1.2 % de las lecturas aceptadas son erroneas.',
       fecha_modificacion = now()
 where codigo_parametro = 'UMBRAL_PLACA';

update public.parametro_sistema
   set valor_parametro = '0.50',
       descripcion = 'Acuerdo desde el cual la lectura se le propone al guardia para que la confirme o la corrija. Por debajo se pide repetir la captura: son lecturas en las que las variantes discrepan entre si.',
       fecha_modificacion = now()
 where codigo_parametro = 'UMBRAL_PLACA_REVISION';
