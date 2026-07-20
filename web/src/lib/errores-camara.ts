/**
 * Traducción de los fallos de cámara a lenguaje del guardia.
 *
 * El guardia usa el sistema de pie y con prisa: lo que falle tiene que decirle qué
 * hacer, no qué se rompió. El navegador y face-api devuelven mensajes en inglés y
 * de jerga ("The highest priority backend 'wasm' has not yet been initialized"),
 * que es justo lo que apareció en la garita durante las pruebas de integración.
 *
 * `alternativa` es la vía que le queda abierta cuando la cámara no responde:
 * teclear la cédula al identificar personas, o teclear la placa en el lector.
 */
export function mensajeDeErrorDeCamara(e: Error, alternativa: string): string {
  if (e.name === 'NotAllowedError' || e.name === 'SecurityError')
    return `El navegador no dio permiso para usar la cámara. Permítelo desde el candado de la barra de direcciones y vuelve a intentarlo. ${alternativa}`
  if (e.name === 'NotFoundError' || e.name === 'DevicesNotFoundError')
    return `No se encontró ninguna cámara conectada a este equipo. ${alternativa}`
  if (e.name === 'NotReadableError')
    return `La cámara está ocupada por otro programa. Ciérralo y vuelve a intentarlo. ${alternativa}`
  if (!window.isSecureContext)
    return `La cámara solo funciona sobre una conexión segura (https). Avisa a soporte. ${alternativa}`
  return `No se pudo iniciar la cámara en este equipo. Avisa a soporte. ${alternativa}`
}
