// resetear-password-usuario
//
// Restablece la contraseña de OTRA cuenta (docs/Req_Front/ADM_Nuevos_Requerimientos.md §7.2,
// caso de uso CU-ADM-007). Esto requiere la Auth Admin API de GoTrue (service_role): ni RLS ni
// una política sobre usuario_sistema pueden hacerlo, porque la contraseña vive en auth.users,
// fuera del alcance de nuestras tablas. Por eso es una Edge Function, no un UPDATE directo.
//
// Verifica el permiso granular ADM_USUARIO_RESETEAR_PASSWORD con el JWT de quien llama (no con
// service_role) antes de tocar la cuenta objetivo, para no bypasear la autorización real.

import { createClient } from 'jsr:@supabase/supabase-js@2';

const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
  });
}

function errorResponse(mensaje: string, status = 400): Response {
  return jsonResponse({ error: mensaje }, status);
}

interface ResetearPasswordBody {
  id_usuario?: string;
  // Opcional: fijar una contraseña específica en vez de generar una temporal aleatoria
  // (por ejemplo, para volver a la contraseña de arranque compartida en cuentas de prueba).
  nueva_password?: string;
}

function generarPasswordTemporal(): string {
  const alfabeto = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789';
  let out = '';
  const bytes = crypto.getRandomValues(new Uint8Array(12));
  for (const b of bytes) out += alfabeto[b % alfabeto.length];
  return `Temp${out}#26`;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS });
  }
  if (req.method !== 'POST') {
    return errorResponse('Metodo no permitido', 405);
  }

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return errorResponse('Falta Authorization: Bearer <jwt>', 401);
  }

  let body: ResetearPasswordBody;
  try {
    body = await req.json();
  } catch {
    return errorResponse('JSON invalido', 400);
  }

  const { id_usuario, nueva_password } = body;
  if (!id_usuario || typeof id_usuario !== 'string') {
    return errorResponse('id_usuario es obligatorio', 400);
  }
  if (nueva_password !== undefined && (typeof nueva_password !== 'string' || nueva_password.length < 8)) {
    return errorResponse('nueva_password debe tener al menos 8 caracteres', 400);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

  // Cliente con el JWT de quien llama: solo para verificar su permiso granular, nunca para
  // tocar la cuenta objetivo.
  const clienteLlamador = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: autorizado, error: permisoError } = await clienteLlamador.rpc('tiene_permiso', {
    p_codigo: 'ADM_USUARIO_RESETEAR_PASSWORD',
  });
  if (permisoError) {
    return errorResponse(permisoError.message, 500);
  }
  if (!autorizado) {
    return errorResponse('No tienes el permiso ADM_USUARIO_RESETEAR_PASSWORD', 403);
  }

  const admin = createClient(supabaseUrl, serviceRoleKey);
  const passwordTemporal = nueva_password ?? generarPasswordTemporal();

  const { error: updateAuthError } = await admin.auth.admin.updateUserById(id_usuario, {
    password: passwordTemporal,
  });
  if (updateAuthError) {
    return errorResponse(updateAuthError.message, 400);
  }

  const { error: updatePerfilError } = await admin
    .from('usuario_sistema')
    .update({ requiere_cambio_password: true })
    .eq('id_usuario', id_usuario);
  if (updatePerfilError) {
    return errorResponse(updatePerfilError.message, 500);
  }

  return jsonResponse({ id_usuario, password_temporal: passwordTemporal });
});
