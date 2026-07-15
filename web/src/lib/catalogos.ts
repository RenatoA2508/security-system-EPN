/**
 * Catálogos derivados de los CHECK reales del backend (consultados desde
 * information_schema el 2026-07-14). NO inventar valores: si el backend cambia
 * un CHECK, actualizar aquí. Ver docs/03_DECISIONES_Y_CORRECCIONES.md y el
 * Modelo de Datos Consolidado. Regla de implementación §5.2: no hardcodear
 * catálogos sin respaldo en el CHECK real — estos lo tienen.
 */

export const CAT = {
  persona_estado: ['ACTIVO', 'INACTIVO', 'DADO_DE_BAJA'],
  persona_tipo: ['INTERNA', 'EXTERNA'],
  // Feedback GPI: solo Masculino/Femenino (persona.sexo no tiene CHECK real en la BD; este
  // catálogo es puramente de UI, sin respaldo de constraint — corregido a lo que pide el equipo).
  persona_sexo: ['M', 'F'],
  categoria_ambito: ['INTERNA', 'EXTERNA'],
  categoria_codigo: [
    'DOCENTE', 'ESTUDIANTE', 'ADMINISTRATIVO', 'TRABAJADOR',
    'EMPRESA_SERVICIO', 'VISITANTE', 'PROVEEDOR', 'CONTRATISTA', 'CONDUCTOR',
  ],
  categoria_estado: ['ACTIVO', 'INACTIVO'],
  unidad: ['EPN', 'CEC'],
  empresa_estado: ['ACTIVO', 'INACTIVO'],
  vehiculo_tipo: ['AUTOMOVIL', 'MOTOCICLETA', 'CAMIONETA', 'BICICLETA', 'OTRO'],
  vehiculo_estado: ['ACTIVO', 'SUSPENDIDO', 'DADO_DE_BAJA'],
  persona_vehiculo_tipo: ['PROPIETARIO', 'CONDUCTOR_AUTORIZADO', 'PASAJERO', 'TEMPORAL'],
  persona_vehiculo_estado: ['ACTIVA', 'SUSPENDIDA', 'VENCIDA', 'REVOCADA'],
  zona_tipo: ['CAMPUS', 'EDIFICIO', 'PARQUEADERO'],
  zona_estado: ['ACTIVA', 'INACTIVA', 'BLOQUEADA'],
  punto_estado: ['ACTIVO', 'FALLA', 'MANTENIMIENTO'],
  dispositivo_tecnologia: ['BIOMETRIA_FACIAL', 'LPR_PLACAS'],
  dispositivo_estado: ['OPERATIVO', 'FALLA_DE_RED', 'DANO_FISICO'],
  asignacion_estado: ['ACTIVA', 'FINALIZADA'],
  regla_estado: ['ACTIVA', 'INACTIVA'],
  memorando_estado: ['VIGENTE', 'VENCIDO'],
  persona_memorando_estado: ['ACTIVO', 'BLOQUEADO'],
  autorizacion_estado: ['VIGENTE', 'REVOCADA'],
  evento_movimiento: ['INGRESO', 'SALIDA'],
  evento_origen: ['AUTOMATICA', 'MANUAL'],
  evento_resultado: ['AUTORIZADO', 'DENEGADO'],
  alerta_estado: ['PENDIENTE', 'ATENDIDA'],
  alerta_nivel: ['BAJO', 'MEDIO', 'ALTO', 'CRITICO'],
  alerta_tipo: [
    'BIOMETRIA_FALLIDA', 'PERSONA_NO_AUTORIZADA', 'MEMORANDO_VENCIDO', 'FUERA_DE_HORARIO',
    'PUNTO_SALIDA_INCORRECTO', 'DISPOSITIVO_NO_RECONOCIDO', 'VEHICULO_NO_AUTORIZADO',
    'VEHICULO_PERMANENCIA_EXCEDIDA', 'VEHICULO_ABANDONADO',
  ],
  usuario_estado: ['ACTIVO', 'INACTIVO', 'BLOQUEADO', 'DADO_DE_BAJA'],
  parametro_modulo: ['AUTENTICACION', 'SESION', 'SEGURIDAD', 'GENERAL'],
  parametro_tipo_dato: ['ENTERO', 'TEXTO', 'BOOLEANO', 'DECIMAL', 'FECHA'],
  parametro_estado: ['ACTIVO', 'INACTIVO', 'CRITICO'],
  rol_nombre: [
    'ADMINISTRADOR_SISTEMA', 'DIRECTOR_ADMINISTRATIVO', 'RESPONSABLE_PERSONAL_INTERNO',
    'RESPONSABLE_PERSONAL_EXTERNO', 'RESPONSABLE_PUNTOS_CONTROL', 'RESPONSABLE_CONTROL_ACCESOS',
    'GUARDIA_SEGURIDAD',
  ],
} as const

/** Categorías por ámbito (EMPRESA_SERVICIO es EXTERNA en el backend real, §D20 / brecha §6.2). */
export const CATEGORIAS_INTERNAS = ['DOCENTE', 'ESTUDIANTE', 'ADMINISTRATIVO', 'TRABAJADOR']
export const CATEGORIAS_EXTERNAS = [
  'VISITANTE', 'PROVEEDOR', 'CONTRATISTA', 'CONDUCTOR', 'EMPRESA_SERVICIO',
]

/** Etiqueta legible para roles del sistema. */
export const ROL_LABEL: Record<string, string> = {
  ADMINISTRADOR_SISTEMA: 'Administrador del Sistema',
  DIRECTOR_ADMINISTRATIVO: 'Director Administrativo',
  RESPONSABLE_PERSONAL_INTERNO: 'Responsable de Personal Interno',
  RESPONSABLE_PERSONAL_EXTERNO: 'Responsable de Personal Externo',
  RESPONSABLE_PUNTOS_CONTROL: 'Responsable de Puntos de Control',
  RESPONSABLE_CONTROL_ACCESOS: 'Responsable de Control de Accesos',
  GUARDIA_SEGURIDAD: 'Guardia de Seguridad',
}

/** Convierte MAYUSCULAS_CON_GUION a "Mayúsculas con guion" para mostrar. */
export function humanizar(valor?: string | null): string {
  if (!valor) return '—'
  return valor
    .toLowerCase()
    .split('_')
    .join(' ')
    .replace(/^\w/, (c) => c.toUpperCase())
}
