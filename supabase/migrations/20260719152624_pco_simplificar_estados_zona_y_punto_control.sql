-- PCO §"no tiene sentido el combo Estado": una zona física de la EPN o está en servicio o no lo
-- está. BLOQUEADA e INACTIVA eran indistinguibles operativamente (en ambas no pasa nadie) y
-- ninguna pantalla las trataba distinto, así que el catálogo obligaba a elegir entre dos
-- palabras para el mismo hecho. Queda ACTIVA/INACTIVA.
update public.zona set estado_zona = 'INACTIVA' where estado_zona = 'BLOQUEADA';

alter table public.zona drop constraint if exists zona_estado_zona_check;
alter table public.zona add constraint zona_estado_zona_check
  check (estado_zona = any (array['ACTIVA'::text, 'INACTIVA'::text]));

-- PCO §"El estado de falla no tiene sentido, ¿cómo un punto de control puede fallar?": un punto
-- de control es un lugar, no un aparato. Lo que falla es el `dispositivo` que hay en él, y esa
-- tabla sí conserva FALLA_DE_RED / DANO_FISICO. Un punto solo puede estar en servicio o cerrado
-- por mantenimiento. Las filas en FALLA pasan a MANTENIMIENTO, que es lo que significaban.
update public.punto_control set estado_punto = 'MANTENIMIENTO' where estado_punto = 'FALLA';

alter table public.punto_control drop constraint if exists punto_control_estado_punto_check;
alter table public.punto_control add constraint punto_control_estado_punto_check
  check (estado_punto = any (array['ACTIVO'::text, 'MANTENIMIENTO'::text]));
