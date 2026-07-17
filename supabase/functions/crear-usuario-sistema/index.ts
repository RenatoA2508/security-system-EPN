// crear-usuario-sistema
//
// Da de alta una cuenta de acceso al sistema sobre una persona YA registrada, y le asigna su rol.
//
// Por qué es una Edge Function y no un INSERT: la cuenta vive en auth.users, fuera del alcance de
// RLS y de nuestras tablas. Solo la Auth Admin API de GoTrue (service_role) puede crearla. El
// trigger on_auth_user_created hace el resto: al insertarse en auth.users crea automáticamente la
// fila de usuario_sistema leyendo id_persona y nombre_usuario de raw_user_meta_data (§D12).
//
// Responde al caso real: si el encargado de un módulo deja la EPN, ADM da de baja su cuenta y crea
// la del reemplazo sin tocar la base a mano.
//
// La persona debe existir antes: `persona` es la maestra única propiedad de ADM (CLAUDE.md) y el
// alta de personas es de GPI. Esta función se apoya en ella, no la duplica.
//
// Verifica ADM_USUARIO_INSERT con el JWT de quien llama (no con service_role) antes de crear nada.

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

interface CrearUsuarioBody {
  id_persona?: string;
  nombre_usuario?: string;
  correo?: string;
  id_rol?: string;
  // Opcional: si no llega, se genera una temporal y se devuelve para que ADM se la entregue.
  password?: string;
}

function generarPasswordTemporal(): string {
  const alfabeto = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789';
  let out = '';
  const bytes = crypto.getRandomValues(new Uint8Array(12));
  for (const b of bytes) out += alfabeto[b % alfabeto.length];
  return `Temp${out}#26`;
}

/** Mismas reglas que los CHECK de la BD, para dar un error legible antes de llamar a GoTrue. */
const RE_NOMBRE_USUARIO = /^[a-z0-9]([a-z0-9._-]{1,48})[a-z0-9]$/;
const RE_CORREO_EPN = /^[A-Za-z0-9._%+-]+@([a-z0-9-]+\.)*(epn|cec)\.edu\.ec$/i;

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

  let body: CrearUsuarioBody;
  try {
    body = await req.json();
  } catch {
    return errorResponse('JSON invalido', 400);
  }

  const id_persona = body.id_persona?.trim();
  const nombre_usuario = body.nombre_usuario?.trim().toLowerCase();
  const correo = body.correo?.trim().toLowerCase();
  const id_rol = body.id_rol?.trim();

  if (!id_persona) return errorResponse('id_persona es obligatorio', 400);
  if (!nombre_usuario) return errorResponse('nombre_usuario es obligatorio', 400);
  if (!correo) return errorResponse('correo es obligatorio', 400);
  if (!id_rol) return errorResponse('id_rol es obligatorio', 400);

  if (!RE_NOMBRE_USUARIO.test(nombre_usuario)) {
    return errorResponse(
      'nombre_usuario invalido: solo minusculas, digitos, punto, guion y guion bajo (3 a 50 caracteres, sin empezar ni terminar en simbolo)',
      400,
    );
  }
  if (!RE_CORREO_EPN.test(correo)) {
    return errorResponse('El correo debe ser institucional de la EPN (@epn.edu.ec o @cec.edu.ec)', 400);
  }
  if (body.password !== undefined && (typeof body.password !== 'string' || body.password.length < 8)) {
    return errorResponse('password debe tener al menos 8 caracteres', 400);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

  // Cliente con el JWT de quien llama: solo para verificar su permiso, nunca para escribir.
  const clienteLlamador = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: autorizado, error: permisoError } = await clienteLlamador.rpc('tiene_permiso', {
    p_codigo: 'ADM_USUARIO_INSERT',
  });
  if (permisoError) return errorResponse(permisoError.message, 500);
  if (!autorizado) return errorResponse('No tienes el permiso ADM_USUARIO_INSERT', 403);

  const admin = createClient(supabaseUrl, serviceRoleKey);

  // La persona tiene que existir y estar activa: una cuenta para alguien dado de baja no tiene
  // sentido, y el trigger fallaria con un error de FK poco legible.
  const { data: persona, error: personaError } = await admin
    .from('persona')
    .select('id_persona, nombres, apellidos, estado, tipo_persona')
    .eq('id_persona', id_persona)
    .maybeSingle();
  if (personaError) return errorResponse(personaError.message, 500);
  if (!persona) return errorResponse('La persona no existe. Registrala primero en el modulo GPI.', 404);
  if (persona.estado !== 'ACTIVO') {
    return errorResponse(`La persona esta ${persona.estado}: no se le puede crear una cuenta.`, 400);
  }
  if (persona.tipo_persona !== 'INTERNA') {
    return errorResponse('Solo el personal interno de la EPN puede tener cuenta en el sistema.', 400);
  }

  // Una persona, una cuenta: sin esto quedarian dos usuarios para el mismo humano y la bitacora
  // dejaria de poder atribuir una accion a una persona concreta.
  const { data: yaTiene, error: yaTieneError } = await admin
    .from('usuario_sistema')
    .select('id_usuario, nombre_usuario, estado_usuario')
    .eq('id_persona', id_persona)
    .maybeSingle();
  if (yaTieneError) return errorResponse(yaTieneError.message, 500);
  if (yaTiene) {
    return errorResponse(
      `${persona.nombres} ${persona.apellidos} ya tiene la cuenta "${yaTiene.nombre_usuario}" (${yaTiene.estado_usuario}).`,
      409,
    );
  }

  const { data: rol, error: rolError } = await admin
    .from('rol')
    .select('id_rol, nombre_rol, estado_rol')
    .eq('id_rol', id_rol)
    .maybeSingle();
  if (rolError) return errorResponse(rolError.message, 500);
  if (!rol) return errorResponse('El rol no existe', 404);
  if (rol.estado_rol !== 'ACTIVO') return errorResponse(`El rol ${rol.nombre_rol} esta inactivo`, 400);

  const password = body.password ?? generarPasswordTemporal();

  // El trigger on_auth_user_created lee id_persona y nombre_usuario de aqui para crear la fila de
  // usuario_sistema. Si faltaran, lanzaria excepcion y el usuario de auth no llegaria a crearse.
  const { data: creado, error: crearError } = await admin.auth.admin.createUser({
    email: correo,
    password,
    email_confirm: true,
    user_metadata: { id_persona, nombre_usuario },
  });
  if (crearError) return errorResponse(crearError.message, 400);

  const idUsuario = creado.user!.id;

  // Rol y cambio de contrasenia obligatorio en el primer ingreso: la temporal la conoce ADM.
  const { error: rolAsignError } = await admin
    .from('usuario_rol')
    .insert({ id_usuario: idUsuario, id_rol, estado_asignacion: 'ACTIVO' });
  if (rolAsignError) {
    // Sin rol la cuenta no sirve para nada (cero permisos) y ademas quedaria huerfana. Se
    // deshace el alta entera para no dejar basura a medio crear.
    await admin.auth.admin.deleteUser(idUsuario);
    return errorResponse(`No se pudo asignar el rol: ${rolAsignError.message}`, 500);
  }

  const { error: perfilError } = await admin
    .from('usuario_sistema')
    .update({ requiere_cambio_password: true })
    .eq('id_usuario', idUsuario);
  if (perfilError) return errorResponse(perfilError.message, 500);

  return jsonResponse({
    id_usuario: idUsuario,
    nombre_usuario,
    correo,
    rol: rol.nombre_rol,
    persona: `${persona.nombres} ${persona.apellidos}`,
    password_temporal: password,
  });
});