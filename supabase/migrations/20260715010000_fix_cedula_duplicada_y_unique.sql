-- Corrige la cédula duplicada detectada en la evaluación de ADM (docs/Req_Front) y
-- agrega la restricción UNIQUE que faltaba en persona.cedula (persona es maestra única, §CLAUDE.md).
--
-- La colisión era entre el dato semilla "Docente Demo" (usado en las pruebas de biometría de
-- esta sesión) y una persona real registrada por el usuario durante sus pruebas de GPI. Se
-- cambia solo la cédula del dato semilla; el dato real del usuario no se toca.

update public.persona
set cedula = '1712345000'
where id_persona = '00000000-0000-0000-0000-0000000000da'
  and cedula = '1712345678';

alter table public.persona
  add constraint persona_cedula_key unique (cedula);
