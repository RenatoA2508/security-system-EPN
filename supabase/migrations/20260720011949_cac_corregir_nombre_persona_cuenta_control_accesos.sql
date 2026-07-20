-- §V36, resuelto por el equipo el 19/07/2026.
--
-- Lo encontro TestSprite: al iniciar sesion con carlos.chavez03@epn.edu.ec, el encabezado
-- mostraba "Sebastian Chavez" y el agente lo interpreto como un fallo de autenticacion. No lo
-- era —el rol y el modulo eran los correctos— pero el dato si estaba mal.
--
-- Confirmado por el equipo: el nombre es el que estaba equivocado, no la vinculacion. La
-- persona 1750000141, titular de la cuenta de Responsable de Control de Accesos, se llama
-- Carlos Chavez. Su correo institucional ya era el correcto.
--
-- Se corrige el nombre y se deja la cuenta donde esta. El trigger de bitacora_sistema deja el
-- rastro del cambio, como con cualquier otra edicion de persona.

update public.persona
   set nombres   = 'Carlos',
       apellidos = 'Chávez'
 where cedula = '1750000141'
   and nombres = 'Sebastián';
