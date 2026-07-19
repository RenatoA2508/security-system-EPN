-- La barrera de turno (req 34) funciona: a las 18:01 el guardia de demostracion dejo de poder
-- registrar eventos, porque su turno terminaba a las 18:00. Es el comportamiento correcto y no
-- se toca.
--
-- El problema es de DATOS, no de reglas: una cuenta cuyo unico proposito es que cualquiera
-- pueda probar la garita necesita un turno que cubra la hora a la que se prueba. Con la jornada
-- maxima de 12 h (§D59, art. 55) no hay ninguna ventana que cubra el dia entero, asi que hay
-- que elegir cual, y se elige la que cubre las tardes y las noches: es cuando se hacen las
-- pruebas manuales y cuando corre TestSprite.
--
-- Para moverla a la mañana, una sola linea (no hace falta migracion):
--
--   update public.guardia_punto_control
--      set hora_inicio = '06:00', hora_fin = '18:00'
--    where id_usuario = (select id from auth.users where email = 'guardia.demo@epn.edu.ec')
--      and estado_asignacion = 'ACTIVA';

update public.guardia_punto_control
   set hora_inicio = '12:00:00'::time,
       hora_fin    = '23:59:59'::time
 where id_usuario = (select id from auth.users where email = 'guardia.demo@epn.edu.ec')
   and estado_asignacion = 'ACTIVA';
