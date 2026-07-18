/**
 * Descripción legible del dispositivo/navegador desde el que se abrió una sesión.
 *
 * Se envía al registrar la sesión y se guarda en `sesion.dispositivo_nombre`, para
 * que la pantalla de Sesiones muestre "Chrome en Windows" en vez del user agent
 * crudo. Es informativo: el user agent lo declara el cliente y puede falsearse,
 * así que no se usa para ninguna decisión de seguridad.
 */
export function describirDispositivo(ua: string | null | undefined): string {
  if (!ua) return 'Dispositivo desconocido'

  // El orden importa: Edge y Opera también contienen "Chrome" en su user agent,
  // y Chrome contiene "Safari".
  const navegador = /Edg\//.test(ua) ? 'Edge'
    : /OPR\/|Opera/.test(ua) ? 'Opera'
    : /Chrome\/|CriOS/.test(ua) ? 'Chrome'
    : /Firefox\/|FxiOS/.test(ua) ? 'Firefox'
    : /Safari\//.test(ua) ? 'Safari'
    : 'Navegador'

  const sistema = /Windows/.test(ua) ? 'Windows'
    : /Android/.test(ua) ? 'Android'
    : /iPhone/.test(ua) ? 'iPhone'
    : /iPad/.test(ua) ? 'iPad'
    : /Mac OS X|Macintosh/.test(ua) ? 'macOS'
    : /Linux/.test(ua) ? 'Linux'
    : 'sistema desconocido'

  return `${navegador} en ${sistema}`
}

/** Descripción del dispositivo actual, para enviar al registrar la sesión. */
export function dispositivoActual(): string {
  return typeof navigator === 'undefined' ? 'Dispositivo desconocido' : describirDispositivo(navigator.userAgent)
}
