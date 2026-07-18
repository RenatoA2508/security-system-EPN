// registrar-evento-acceso
//
// Implementa el "Resumen operativo" completo de docs/04_REGLAS_NEGOCIO.md:
// las dos vias de validacion (interna/biometria vs externa/cedula, §D20), el
// acceso vehicular (un evento por ocupante, es_conductor, denegacion atomica
// del vehiculo, §D22), y las reglas de salida con sus dos valvulas de escape
// (§D23). Autenticada con service_role para las escrituras; valida
// codigo_mac/direccion_ip contra `dispositivo` para el camino AUTOMATICA, o
// el JWT del guardia para el camino MANUAL (docs/01_AUTENTICACION_Y_ROLES.md §4).

import { createClient, type SupabaseClient } from 'jsr:@supabase/supabase-js@2';
import { CORS_HEADERS, errorResponse, jsonResponse } from '../_shared/respuestas.ts';

interface OcupanteInput {
  id_persona?: string;
  cedula?: string;
  es_conductor?: boolean;
  // Resultado ya obtenido de validar-biometria; solo aplica a INTERNA (§D20).
  confidence?: number;
}

interface RegistrarEventoBody {
  origen_registro: 'AUTOMATICA' | 'MANUAL';
  tipo_movimiento: 'INGRESO' | 'SALIDA';
  id_punto_control: string;
  codigo_mac?: string;
  direccion_ip?: string;
  id_vehiculo?: string;
  ocupantes: OcupanteInput[];
  // Valvula 2 (§D23): el guardia siempre puede forzar una salida manual.
  salida_manual_forzada?: boolean;
  motivo_salida_manual?: string;
}

interface ResultadoValidacion {
  autorizado: boolean;
  motivo: string | null;
  id_regla_acceso: string | null;
  id_autorizacion_visita: string | null;
  generarAlertaInformativa?: string | null;
}

async function obtenerParametro(supabase: SupabaseClient, codigo: string): Promise<number> {
  const { data, error } = await supabase
    .from('parametro_sistema')
    .select('valor_parametro')
    .eq('codigo_parametro', codigo)
    .maybeSingle();
  if (error) throw new Error(error.message);
  if (!data) throw new Error(`Parametro ${codigo} no configurado en parametro_sistema`);
  return Number(data.valor_parametro);
}

// docs/02_MATRIZ_PERMISOS_RLS.md no especifica zona horaria para
// regla_acceso.horario_inicio/fin (tipo `time`, sin tz). Se asume hora local
// de Ecuador (America/Guayaquil, UTC-5, sin horario de verano). Ver docs/99.
function horaLocalEcuador(fecha: Date): string {
  const partes = new Intl.DateTimeFormat('en-GB', {
    timeZone: 'America/Guayaquil',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false,
  }).formatToParts(fecha);
  const obtener = (tipo: string) => partes.find((p) => p.type === tipo)?.value ?? '00';
  return `${obtener('hour')}:${obtener('minute')}:${obtener('second')}`;
}

// §D24: si dos reglas solapan, gana la mas especifica (id_punto_control
// explicito sobre nulo); si empatan, la mas restrictiva (requiere_memorando).
async function evaluarReglaAcceso(
  supabase: SupabaseClient,
  idCategoria: string,
  idPuntoControl: string,
  ahora: Date,
) {
  const horaActual = horaLocalEcuador(ahora);

  const { data: reglas, error } = await supabase
    .from('regla_acceso')
    .select('*')
    .eq('id_categoria', idCategoria)
    .eq('estado_regla', 'ACTIVA')
    .lte('horario_inicio', horaActual)
    .gte('horario_fin', horaActual)
    .or(`id_punto_control.eq.${idPuntoControl},id_punto_control.is.null`);

  if (error) throw new Error(error.message);
  if (!reglas || reglas.length === 0) return null;

  const especificas = reglas.filter((r) => r.id_punto_control === idPuntoControl);
  const candidatas = especificas.length > 0 ? especificas : reglas;
  candidatas.sort((a, b) => Number(b.requiere_memorando) - Number(a.requiere_memorando));
  return candidatas[0];
}

async function resolverPersona(supabase: SupabaseClient, ocupante: OcupanteInput) {
  if (ocupante.id_persona) {
    const { data, error } = await supabase
      .from('persona')
      .select('*')
      .eq('id_persona', ocupante.id_persona)
      .maybeSingle();
    if (error) throw new Error(error.message);
    return data;
  }
  if (ocupante.cedula) {
    const { data, error } = await supabase
      .from('persona')
      .select('*')
      .eq('cedula', ocupante.cedula)
      .maybeSingle();
    if (error) throw new Error(error.message);
    return data;
  }
  return null;
}

// Prioriza MEMORANDO sobre AUTORIZACION_DIARIA si ambos estan vigentes.
async function obtenerVigenciaExterna(supabase: SupabaseClient, idPersona: string) {
  const { data, error } = await supabase
    .from('vista_vigencia_acceso')
    .select('*')
    .eq('id_persona', idPersona)
    .neq('via_vigencia', 'INTERNA_ACTIVA');
  if (error) throw new Error(error.message);
  if (!data || data.length === 0) return null;
  return data.find((v) => v.via_vigencia === 'MEMORANDO') ?? data[0];
}

async function verificarVehiculoActivo(supabase: SupabaseClient, idVehiculo: string) {
  const { data, error } = await supabase
    .from('vehiculo')
    .select('estado_vehiculo')
    .eq('id_vehiculo', idVehiculo)
    .maybeSingle();
  if (error) throw new Error(error.message);
  if (!data) return { activo: false, motivo: 'Vehiculo no encontrado' };
  if (data.estado_vehiculo !== 'ACTIVO') {
    return { activo: false, motivo: `VEHICULO_NO_AUTORIZADO: vehiculo no ACTIVO (estado=${data.estado_vehiculo}); la placa no autoriza el ingreso` };
  }
  return { activo: true, motivo: null as string | null };
}

// deno-lint-ignore no-explicit-any
async function validarIngresoOcupante(
  supabase: SupabaseClient,
  persona: any,
  ocupante: OcupanteInput,
  idPuntoControl: string,
  umbralBiometria: number,
  ahora: Date,
): Promise<ResultadoValidacion> {
  if (persona.tipo_persona === 'INTERNA') {
    const confidence = ocupante.confidence ?? 0;
    if (confidence < umbralBiometria) {
      return {
        autorizado: false,
        motivo: `BIOMETRIA_FALLIDA: confidence ${confidence} < umbral ${umbralBiometria}`,
        id_regla_acceso: null,
        id_autorizacion_visita: null,
      };
    }
    if (persona.estado !== 'ACTIVO') {
      return { autorizado: false, motivo: 'PERSONA_NO_AUTORIZADA: persona interna no ACTIVA', id_regla_acceso: null, id_autorizacion_visita: null };
    }

    const regla = await evaluarReglaAcceso(supabase, persona.id_categoria, idPuntoControl, ahora);
    if (!regla) {
      return { autorizado: false, motivo: 'FUERA_DE_HORARIO: sin regla de acceso aplicable a la categoria/punto/horario', id_regla_acceso: null, id_autorizacion_visita: null };
    }
    return { autorizado: true, motivo: null, id_regla_acceso: regla.id_regla_acceso, id_autorizacion_visita: null };
  }

  // EXTERNA: nunca se consulta biometria (§D20). Identidad ya resuelta por
  // cedula en resolverPersona().
  const vigencia = await obtenerVigenciaExterna(supabase, persona.id_persona);
  if (!vigencia) {
    return {
      autorizado: false,
      motivo: 'MEMORANDO_VENCIDO: sin memorando vigente ni autorizacion de visita diaria',
      id_regla_acceso: null,
      id_autorizacion_visita: null,
    };
  }

  const regla = await evaluarReglaAcceso(supabase, persona.id_categoria, idPuntoControl, ahora);
  if (!regla) {
    return { autorizado: false, motivo: 'FUERA_DE_HORARIO: sin regla de acceso aplicable a la categoria/punto/horario', id_regla_acceso: null, id_autorizacion_visita: null };
  }
  if (regla.requiere_memorando && vigencia.via_vigencia !== 'MEMORANDO') {
    return {
      autorizado: false,
      motivo: 'MEMORANDO_VENCIDO: la regla exige memorando; la persona solo tiene autorizacion de visita diaria',
      id_regla_acceso: regla.id_regla_acceso,
      id_autorizacion_visita: vigencia.id_autorizacion ?? null,
    };
  }

  return {
    autorizado: true,
    motivo: null,
    id_regla_acceso: regla.id_regla_acceso,
    id_autorizacion_visita: vigencia.via_vigencia === 'AUTORIZACION_DIARIA' ? vigencia.id_autorizacion : null,
  };
}

// deno-lint-ignore no-explicit-any
async function validarSalidaOcupante(
  supabase: SupabaseClient,
  persona: any,
  idPuntoControl: string,
  salidaManualForzada: boolean,
  motivoSalidaManual: string | undefined,
): Promise<ResultadoValidacion> {
  // La vigencia nunca se revalida en la SALIDA (resumen operativo, doc04).
  const inicioDia = new Date();
  inicioDia.setUTCHours(0, 0, 0, 0);

  const { data: ultimoIngreso, error } = await supabase
    .from('evento_acceso')
    .select('id_punto_control, id_autorizacion_visita, fecha_hora')
    .eq('id_persona', persona.id_persona)
    .eq('tipo_movimiento', 'INGRESO')
    .eq('resultado', 'AUTORIZADO')
    .not('id_autorizacion_visita', 'is', null)
    .gte('fecha_hora', inicioDia.toISOString())
    .order('fecha_hora', { ascending: false })
    .limit(1)
    .maybeSingle();

  if (error) throw new Error(error.message);

  if (salidaManualForzada) {
    // Valvula 2 (§D23): siempre disponible, con justificacion.
    return {
      autorizado: true,
      motivo: motivoSalidaManual ?? 'Salida manual forzada por el guardia',
      id_regla_acceso: null,
      id_autorizacion_visita: ultimoIngreso?.id_autorizacion_visita ?? null,
      generarAlertaInformativa: 'PUNTO_SALIDA_INCORRECTO',
    };
  }

  // Sin autorizacion de visita diaria de hoy, o salio por el mismo punto: OK.
  // (§D23: la regla del mismo punto solo aplica a visitantes con
  // autorizacion_visita_diaria, no a externos con memorando ni a internos.)
  if (!ultimoIngreso || ultimoIngreso.id_punto_control === idPuntoControl) {
    return {
      autorizado: true,
      motivo: null,
      id_regla_acceso: null,
      id_autorizacion_visita: ultimoIngreso?.id_autorizacion_visita ?? null,
    };
  }

  const { data: puntoIngreso, error: puntoError } = await supabase
    .from('punto_control')
    .select('estado_punto')
    .eq('id_punto_control', ultimoIngreso.id_punto_control)
    .maybeSingle();
  if (puntoError) throw new Error(puntoError.message);

  if (puntoIngreso && puntoIngreso.estado_punto !== 'ACTIVO') {
    // Valvula 1 (§D23): el punto de ingreso no esta ACTIVO -> se autoriza la
    // salida por otro punto, con alerta.
    return {
      autorizado: true,
      motivo: 'Salida autorizada por punto alterno: el punto de ingreso no esta ACTIVO',
      id_regla_acceso: null,
      id_autorizacion_visita: ultimoIngreso.id_autorizacion_visita,
      generarAlertaInformativa: 'PUNTO_SALIDA_INCORRECTO',
    };
  }

  return {
    autorizado: false,
    motivo: 'PUNTO_SALIDA_INCORRECTO: debe salir por el mismo punto de control por el que ingreso',
    id_regla_acceso: null,
    id_autorizacion_visita: ultimoIngreso.id_autorizacion_visita,
  };
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS });
  }
  if (req.method !== 'POST') {
    return errorResponse('Metodo no permitido', 405);
  }

  let body: RegistrarEventoBody;
  try {
    body = await req.json();
  } catch {
    return errorResponse('JSON invalido', 400);
  }

  const { origen_registro, tipo_movimiento, id_punto_control, ocupantes } = body;

  if (origen_registro !== 'AUTOMATICA' && origen_registro !== 'MANUAL') {
    return errorResponse('origen_registro debe ser AUTOMATICA o MANUAL', 400);
  }
  if (tipo_movimiento !== 'INGRESO' && tipo_movimiento !== 'SALIDA') {
    return errorResponse('tipo_movimiento debe ser INGRESO o SALIDA', 400);
  }
  if (!id_punto_control || !Array.isArray(ocupantes) || ocupantes.length === 0) {
    return errorResponse('id_punto_control y al menos un ocupante son obligatorios', 400);
  }

  const supabaseService = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  // ---- Autenticacion del llamador (docs/01_AUTENTICACION_Y_ROLES.md §4) ----
  if (origen_registro === 'AUTOMATICA') {
    if (!body.codigo_mac || !body.direccion_ip) {
      return errorResponse('codigo_mac y direccion_ip son obligatorios para origen_registro=AUTOMATICA', 400);
    }
    const { data: dispositivo, error: dispError } = await supabaseService
      .from('dispositivo')
      .select('id_dispositivo, estado_dispositivo')
      .eq('id_punto_control', id_punto_control)
      .eq('codigo_mac', body.codigo_mac)
      .eq('direccion_ip', body.direccion_ip)
      .maybeSingle();

    if (dispError) return errorResponse(dispError.message, 500);

    if (!dispositivo || dispositivo.estado_dispositivo !== 'OPERATIVO') {
      // Sin evento real que referenciar todavia: se deja constancia en
      // bitacora_sistema (nunca en alerta_seguridad, que exige id_evento NOT
      // NULL). Ver docs/99_DUDAS_PARA_EL_EQUIPO.md.
      await supabaseService.from('bitacora_sistema').insert({
        accion: 'RECHAZO_DISPOSITIVO_NO_RECONOCIDO',
        modulo: 'CAC',
        entidad_afectada: 'dispositivo',
        id_entidad_afectada: `${body.codigo_mac}@${body.direccion_ip}`,
        resultado: 'ERROR',
        descripcion: `Dispositivo no reconocido u OPERATIVO en punto_control=${id_punto_control}`,
      });
      return errorResponse('Dispositivo no reconocido', 401);
    }
  }

  let idUsuarioGuardia: string | null = null;
  if (origen_registro === 'MANUAL') {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader?.startsWith('Bearer ')) {
      return errorResponse('Se requiere el JWT del guardia para origen_registro=MANUAL', 401);
    }
    const jwt = authHeader.replace('Bearer ', '');
    const supabaseAnon = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
    );
    const { data: userData, error: userError } = await supabaseAnon.auth.getUser(jwt);
    if (userError || !userData?.user) {
      return errorResponse('JWT invalido o expirado', 401);
    }
    idUsuarioGuardia = userData.user.id;

    // Barrera de turno (req 34): un guardia solo registra eventos dentro de su
    // turno/hora. Se evalua con la hora del SERVIDOR (esta_en_turno_guardia usa
    // now() y America/Guayaquil), nunca con la del navegador. Solo afecta a los
    // guardias; otros roles con permiso pasan (verificar_turno_guardia_actual).
    // Como esta funcion escribe con service_role (auth.uid() nulo), el trigger
    // de la BD no cubre este camino: la barrera se aplica aqui.
    const supabaseGuardia = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } },
    );
    const { data: turno, error: turnoError } = await supabaseGuardia.rpc('verificar_turno_guardia_actual');
    if (turnoError) return errorResponse(turnoError.message, 500);
    if (turno && (turno as { permitido: boolean }).permitido === false) {
      // Registrar el intento denegado en bitacora (transaccion propia, persiste).
      await supabaseGuardia.rpc('registrar_intento_fuera_de_turno', {
        p_detalle: `Intento de registrar ${tipo_movimiento} en punto_control=${id_punto_control} fuera de turno.`,
      });
      return errorResponse(
        (turno as { motivo: string }).motivo ?? 'Su turno no se encuentra habilitado a esta hora.',
        403,
      );
    }
  }

  // ---- Resolver todos los ocupantes antes de escribir nada (todo o nada) ----
  const personasResueltas: Array<{ ocupante: OcupanteInput; persona: Record<string, unknown> }> = [];
  for (const ocupante of ocupantes) {
    const persona = await resolverPersona(supabaseService, ocupante);
    if (!persona) {
      return errorResponse(
        `Persona no encontrada para ocupante (${ocupante.id_persona ?? ocupante.cedula ?? 'sin identificador'})`,
        404,
      );
    }
    personasResueltas.push({ ocupante, persona });
  }

  const umbralBiometria = await obtenerParametro(supabaseService, 'UMBRAL_BIOMETRIA');

  // ---- Vehicular: la placa autoriza al vehiculo, no a las personas (§D22) ----
  let vehiculoActivo = true;
  let motivoVehiculoInactivo: string | null = null;
  if (body.id_vehiculo) {
    const chequeo = await verificarVehiculoActivo(supabaseService, body.id_vehiculo);
    vehiculoActivo = chequeo.activo;
    motivoVehiculoInactivo = chequeo.motivo;
  }

  const ahora = new Date();
  const fechaHora = ahora.toISOString();
  const resultadosEventos: Array<Record<string, unknown>> = [];
  const alertasInformativas: Array<{ id_evento: string; tipo_alerta: string }> = [];

  for (const { ocupante, persona } of personasResueltas) {
    let resultado: ResultadoValidacion;

    if (!vehiculoActivo) {
      resultado = { autorizado: false, motivo: motivoVehiculoInactivo, id_regla_acceso: null, id_autorizacion_visita: null };
    } else if (tipo_movimiento === 'INGRESO') {
      resultado = await validarIngresoOcupante(supabaseService, persona, ocupante, id_punto_control, umbralBiometria, ahora);
    } else {
      resultado = await validarSalidaOcupante(
        supabaseService,
        persona,
        id_punto_control,
        body.salida_manual_forzada === true,
        body.motivo_salida_manual,
      );
    }

    const { data: eventoInsertado, error: insertError } = await supabaseService
      .from('evento_acceso')
      .insert({
        id_persona: persona.id_persona,
        id_vehiculo: body.id_vehiculo ?? null,
        id_punto_control,
        tipo_movimiento,
        fecha_hora: fechaHora,
        resultado: resultado.autorizado ? 'AUTORIZADO' : 'DENEGADO',
        motivo_resultado: resultado.motivo,
        origen_registro,
        id_regla_acceso: resultado.id_regla_acceso,
        id_autorizacion_visita: resultado.id_autorizacion_visita,
        es_conductor: ocupante.es_conductor === true,
      })
      .select('id_evento')
      .single();

    if (insertError) {
      return errorResponse(`Error registrando evento: ${insertError.message}`, 500);
    }

    if (resultado.generarAlertaInformativa) {
      alertasInformativas.push({ id_evento: eventoInsertado.id_evento, tipo_alerta: resultado.generarAlertaInformativa });
    }

    resultadosEventos.push({
      id_evento: eventoInsertado.id_evento,
      id_persona: persona.id_persona,
      cedula: ocupante.cedula ?? null,
      es_conductor: ocupante.es_conductor === true,
      autorizado: resultado.autorizado,
      motivo: resultado.motivo,
    });
  }

  // Alertas informativas de las valvulas de escape (§D23): el evento queda
  // AUTORIZADO pero igual se genera alerta. El trigger del bloque 5 solo
  // dispara sobre eventos DENEGADO (§D4), por eso se insertan aqui.
  for (const alerta of alertasInformativas) {
    await supabaseService.from('alerta_seguridad').insert({
      id_evento: alerta.id_evento,
      tipo_alerta: alerta.tipo_alerta,
      nivel_riesgo: 'MEDIO',
      estado_alerta: 'PENDIENTE',
    });
  }

  // El trigger automatico de bitacora_sistema (bloque 5) lee auth.uid() al
  // nivel de sesion de Postgres, que aqui es NULL (esta funcion escribe con
  // service_role, no con el JWT del guardia). Se deja una fila explicita con
  // la atribucion correcta para el camino MANUAL. Ver docs/99 (E11).
  if (origen_registro === 'MANUAL' && idUsuarioGuardia) {
    await supabaseService.from('bitacora_sistema').insert({
      id_usuario: idUsuarioGuardia,
      accion: 'REGISTRO_MANUAL_EVENTO_ACCESO',
      modulo: 'CAC',
      entidad_afectada: 'evento_acceso',
      id_entidad_afectada: resultadosEventos.map((e) => e.id_evento).join(','),
      resultado: 'EXITO',
      descripcion: `Registro manual del guardia para ${resultadosEventos.length} ocupante(s) en punto_control=${id_punto_control}`,
    });
  }

  const vehiculoAutorizado = resultadosEventos.every((e) => e.autorizado === true);

  return jsonResponse({
    id_punto_control,
    tipo_movimiento,
    origen_registro,
    id_vehiculo: body.id_vehiculo ?? null,
    vehiculo_autorizado: body.id_vehiculo ? vehiculoAutorizado : undefined,
    ocupantes: resultadosEventos,
  });
});
