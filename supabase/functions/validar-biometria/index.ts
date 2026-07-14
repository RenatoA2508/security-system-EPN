// validar-biometria
//
// Reconocimiento facial 1:N (identificacion). Recibe el descriptor facial vivo
// (128 dimensiones, calculado en el navegador con face-api.js) y responde
// { match, id_persona, confidence } -- la misma forma que tendria un proveedor
// real (AWS Rekognition SearchFacesByImage, Azure Face Identify, etc.).
// Fuente: docs/01_AUTENTICACION_Y_ROLES.md §6.
//
// El descriptor se compara EN EL BACKEND con pgvector (funcion SQL
// identificar_por_descriptor). `confidence` = similitud coseno contra el
// enrolado mas cercano. El match se decide contra el mismo parametro
// UMBRAL_BIOMETRIA que usa registrar-evento-acceso: un solo umbral para todo el
// pipeline. Asi, aguas abajo, nada cambia respecto al mock anterior.
//
// Solo aplica a personas INTERNAS: los externos NUNCA tienen registro_biometrico
// (§D20). La funcion SQL ya filtra por tipo_persona = 'INTERNA', asi que un
// rostro externo simplemente no encontrara coincidencia.
//
// TODO: reemplazar face-api.js/pgvector por un proveedor real antes de
// produccion. Solo cambiaria el origen del descriptor y esta funcion; el resto
// del flujo CAC (evento -> identidad -> regla -> resultado -> alerta) permanece
// intacto porque depende solo de la forma de esta respuesta.

import { createClient } from 'jsr:@supabase/supabase-js@2';
import { CORS_HEADERS, errorResponse, jsonResponse } from '../_shared/respuestas.ts';

interface ValidarBiometriaBody {
  // Descriptor facial de 128 floats producido por face-api.js en el cliente.
  descriptor?: number[];
  // Punto de control / dispositivo que capturo el rostro (opcional, trazabilidad).
  id_dispositivo?: string;
  // Parametro de configuracion para forzar el camino de denegacion en pruebas
  // (docs/01_AUTENTICACION_Y_ROLES.md §6).
  forzar_fallo?: boolean;
}

const DIMENSIONES_DESCRIPTOR = 128;

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

  const { descriptor, forzar_fallo } = body;

  if (forzar_fallo === true) {
    return jsonResponse({ match: false, id_persona: null, confidence: 0 });
  }

  if (
    !Array.isArray(descriptor) ||
    descriptor.length !== DIMENSIONES_DESCRIPTOR ||
    !descriptor.every((n) => typeof n === 'number' && Number.isFinite(n))
  ) {
    return errorResponse(
      `descriptor debe ser un arreglo de ${DIMENSIONES_DESCRIPTOR} numeros finitos`,
      400,
    );
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  // Umbral unico del pipeline (mismo que aplica registrar-evento-acceso).
  const { data: parametro, error: parametroError } = await supabase
    .from('parametro_sistema')
    .select('valor_parametro')
    .eq('codigo_parametro', 'UMBRAL_BIOMETRIA')
    .maybeSingle();

  if (parametroError) {
    return errorResponse(parametroError.message, 500);
  }
  if (!parametro) {
    return errorResponse('Parametro UMBRAL_BIOMETRIA no configurado', 500);
  }
  const umbral = Number(parametro.valor_parametro);

  // Identificacion 1:N contra los descriptores enrolados (pgvector).
  const { data: candidatos, error: rpcError } = await supabase.rpc(
    'identificar_por_descriptor',
    { p_descriptor: descriptor },
  );

  if (rpcError) {
    return errorResponse(rpcError.message, 500);
  }

  const candidato = Array.isArray(candidatos) ? candidatos[0] : candidatos;

  if (!candidato) {
    // Ningun rostro enrolado: rostro desconocido.
    return jsonResponse({ match: false, id_persona: null, confidence: 0 });
  }

  const confidence = Number(candidato.confidence);
  const match = confidence >= umbral;

  return jsonResponse({
    match,
    // Solo se revela la identidad si supera el umbral; por debajo es un rostro
    // no reconocido con confianza suficiente.
    id_persona: match ? candidato.id_persona : null,
    confidence,
  });
});
