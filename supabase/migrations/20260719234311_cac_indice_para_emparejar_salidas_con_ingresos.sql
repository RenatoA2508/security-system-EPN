-- RF-CA-013 empareja cada salida con su ingreso. La version anterior acotaba la busqueda al
-- dia natural en UTC, lo que dejaba huerfana la salida de quien entraba a las 23:00 y salia a
-- las 02:00; al quitar ese filtro, la consulta pasa a recorrer todo el historial de la persona
-- ordenado por fecha, y `evento_acceso.id_persona` no tenia ningun indice que la cubriera.
--
-- Con quince filas no se nota. Con el historial de un semestre, cada salida registrada en la
-- garita haria un recorrido secuencial de la tabla mientras alguien espera con el coche en la
-- puerta. El indice cubre exactamente la consulta que hace validarSalidaOcupante: los ingresos
-- autorizados de una persona, del mas reciente al mas antiguo.
create index if not exists idx_evento_acceso_ingresos_de_persona
  on public.evento_acceso (id_persona, tipo_movimiento, fecha_hora desc)
  where resultado = 'AUTORIZADO';

comment on index public.idx_evento_acceso_ingresos_de_persona is
  'Emparejado de salidas con su ingreso (RF-CA-013) y consulta del historial por persona.';

-- El resto de FKs de evento_acceso (vehiculo, regla, autorizacion) tambien salen en el linter,
-- pero no se indexan aqui a proposito: ninguna consulta del flujo filtra por ellas, y en una
-- tabla que solo crece y se escribe en cada paso de una persona por la garita, cada indice de
-- mas es coste en la escritura a cambio de nada. Se anadiran si aparece la consulta que los
-- necesite.
