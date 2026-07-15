-- Feedback GPE: registrar un visitante de paso (sin memorando) no debería exigir todos los
-- campos de una persona externa completa; basta cédula + algún contacto (correo o teléfono).
-- persona.correo era NOT NULL, lo que obligaba a inventar un correo para poder guardar. Se
-- relaja a NULLABLE; el frontend sigue pidiendo cédula/nombres/apellidos siempre.

alter table public.persona alter column correo drop not null;
