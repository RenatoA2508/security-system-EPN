// validar-biometria
//
// Mock del reconocimiento facial, exactamente con la forma de respuesta que
// tendria un proveedor real (AWS Rekognition, Azure Face API, etc.).
// Fuente: docs/01_AUTENTICACION_Y_ROLES.md §6.
//
// Solo aplica a personas INTERNAS: los externos NUNCA tienen
// registro_biometrico (§D20). Si la persona es EXTERNA, se responde
// "sin coincidencia" en vez de un error: la via correcta para un externo es
// la cedula ante el guardia, no la biometria.
//
// TODO: reemplazar por proveedor real antes de produccion. El resto del
// flujo de CAC (evento -> identidad -> regla -> resultado -> alerta) esta
// escrito contra esta forma de respuesta para que el reemplazo no requiera
// tocar nada mas.

import { createClient } from 'jsr:@supabase/supabase-js@2';
import { CORS_HEADERS, errorResponse, jsonResponse } from '../_shared/respuestas.ts';

interface ValidarBiometriaBody {
  id_persona?: string;
  imagen_ref?: string;
  id_dispositivo?: string;
  // Parametro de configuracion para forzar el camino de denegacion en
  // pruebas (docs/01_AUTENTICACION_Y_ROLES.md §6).
  forzar_fallo?: boolean;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS });
  }
  if (req.method !== 'POST') {
    return errorResponse('Metodo no permitido', 405);
  }

  let body: ValidarBiometriaBody;
  try {
    body = await req.json();
  } catch {
    return errorResponse('JSON invalido', 400);
  }

  const { id_persona, imagen_ref, id_dispositivo, forzar_fallo } = body;

  if (!id_persona || !imagen_ref || !id_dispositivo) {
    return errorResponse('id_persona, imagen_ref e id_dispositivo son obligatorios', 400);
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  if (forzar_fallo === true) {
    return jsonResponse({ match: false, confidence: 0 });
  }

  const { data: persona, error: personaError } = await supabase
    .from('persona')
    .select('id_persona, tipo_persona, estado')
    .eq('id_persona', id_persona)
    .maybeSingle();

  if (personaError) {
    return errorResponse(personaError.message, 500);
  }
  if (!persona) {
    return errorResponse('Persona no encontrada', 404);
  }
  if (persona.tipo_persona !== 'INTERNA') {
    return jsonResponse({ match: false, confidence: 0 });
  }

  const { data: registro, error: registroError } = await supabase
    .from('registro_biometrico')
    .select('id_registro')
    .eq('id_persona', id_persona)
    .eq('vigente', true)
    .limit(1)
    .maybeSingle();

  if (registroError) {
    return errorResponse(registroError.message, 500);
  }

  const match = registro !== null;
  const confidence = match ? 0.95 : 0;

  return jsonResponse({ match, confidence });
});
