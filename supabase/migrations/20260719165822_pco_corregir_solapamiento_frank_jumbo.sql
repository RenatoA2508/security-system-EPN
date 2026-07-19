-- §V26 resuelto. La cuenta frank.jumbo tenía DOS asignaciones activas sobre el MISMO punto
-- ("Garita - Subsuelo EARME"):
--   06:00–20:00, creada el 17/07 — catorce horas seguidas
--   14:00–20:00, creada el 18/07 — seis horas
--
-- La segunda es del día siguiente y encaja dentro de la primera: todo apunta a que se registró
-- para corregirla y nadie finalizó la original, así que el guardia constaba con dos turnos a la
-- vez. Se conserva la de 14:00–20:00, que además es la única de las dos que cabe en una jornada
-- legal, y la de catorce horas pasa a FINALIZADA.
--
-- Sin DELETE (regla del proyecto): la fila se queda como historial de que esa asignación existió.
update public.guardia_punto_control
   set estado_asignacion = 'FINALIZADA'
 where id_asignacion = 'b21f7b50-357e-4b47-a01a-bdffd50072ee'
   and hora_inicio = '06:00'
   and hora_fin = '20:00'
   and estado_asignacion = 'ACTIVA';
