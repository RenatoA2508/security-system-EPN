/**
 * Lectura de placas vehiculares ecuatorianas (RF-CA-015).
 *
 * Dos motores, en este orden:
 *
 *   1. NUBE — la Edge Function `reconocer-placa` llama a un lector de matrículas real. Es
 *      bastante mejor que cualquier OCR genérico porque localiza la placa dentro de la foto
 *      antes de leerla. Requiere que el token esté configurado en el servidor.
 *   2. LOCAL — Tesseract.js en el propio navegador. No necesita red ni claves, y es el modo
 *      con el que el sistema sigue funcionando cuando el proveedor no está disponible.
 *
 * El OCR genérico del modo local no lee una placa de una foto tal cual: hay que ayudarle.
 * Este módulo hace el preprocesado que separa una lectura inútil de una lectura correcta:
 * recorta la zona donde el guardia encuadró la placa, la amplía, la pasa a gris, le estira el
 * contraste y la binariza. Sin eso, Tesseract sobre una foto de un coche entero devuelve
 * fragmentos del parachoques.
 */

/** Las 24 letras de provincia asignadas por la ANT (D y F no se usan como inicial). */
const LETRAS_PROVINCIA = 'ABUCXHOEWGILRMVNQSPKTZYJ'

/** Forma canónica: mayúsculas, sin guion ni espacios. Espejo de `public.normalizar_placa`. */
export function normalizarPlacaLeida(valor: string): string {
  return (valor || '').toUpperCase().replace(/[^A-Z0-9]/g, '')
}

/**
 * Corrige las confusiones de OCR según la posición. Espejo exacto de
 * `public.corregir_placa_ocr` — si cambias una, cambia la otra.
 *
 * La placa ecuatoriana tiene forma fija: tres letras y luego tres o cuatro dígitos. Un dígito
 * leído en las tres primeras posiciones es necesariamente un error, y una letra en la parte
 * numérica también. Corregirlo por posición no puede convertir una placa en otra placa válida
 * distinta, porque solo toca caracteres que estaban en la clase equivocada.
 */
export function corregirPlacaOcr(valor: string): string {
  const placa = normalizarPlacaLeida(valor)
  if (placa.length !== 6 && placa.length !== 7) return placa

  const aLetra: Record<string, string> = { '0': 'O', '1': 'I', '2': 'Z', '5': 'S', '6': 'G', '8': 'B' }
  const aDigito: Record<string, string> = {
    O: '0', Q: '0', D: '0', I: '1', L: '1', Z: '2', S: '5', G: '6', B: '8',
  }

  return placa
    .split('')
    .map((ch, i) => (i <= 2 ? aLetra[ch] ?? ch : aDigito[ch] ?? ch))
    .join('')
}

/** ¿Tiene forma de placa ecuatoriana ordinaria o de motocicleta? */
export function pareceePlacaEcuatoriana(valor: string): boolean {
  const c = normalizarPlacaLeida(valor)
  return (
    new RegExp(`^[${LETRAS_PROVINCIA}][A-Z]{2}[0-9]{3,4}$`).test(c) ||
    new RegExp(`^[${LETRAS_PROVINCIA}][A-Z][0-9]{3}[A-Z]$`).test(c)
  )
}

/**
 * Extrae la placa de un texto suelto devuelto por el OCR.
 *
 * Tesseract no devuelve "PDF1234": devuelve algo como "ECUADOR\nPDF-1234\nPICHINCHA", porque
 * la placa lleva impreso el país y la provincia. Buscar el patrón dentro del texto, en vez de
 * tomar el texto entero, es lo que hace que la lectura sirva para algo.
 */
export function extraerPlacaDeTexto(texto: string): string | null {
  const limpio = (texto || '').toUpperCase().replace(/[^A-Z0-9\s-]/g, ' ')

  // Se prueban los trozos largos primero: "PDF1234" antes que "PDF123", para no quedarse con
  // un prefijo de la placa de cuatro dígitos.
  const candidatos = limpio
    .split(/\s+/)
    .map(normalizarPlacaLeida)
    .filter((t) => t.length >= 6 && t.length <= 8)
    .sort((a, b) => b.length - a.length)

  for (const candidato of candidatos) {
    if (pareceePlacaEcuatoriana(candidato)) return candidato
    const corregido = corregirPlacaOcr(candidato)
    if (pareceePlacaEcuatoriana(corregido)) return corregido
  }

  // Último intento: el texto entero pegado, por si el OCR metió espacios dentro de la placa.
  const todo = normalizarPlacaLeida(limpio)
  const encontrado = todo.match(new RegExp(`[${LETRAS_PROVINCIA}][A-Z]{2}[0-9]{3,4}`))
  return encontrado ? encontrado[0] : null
}

// ---------------------------------------------------------------------------
// Preprocesado de la imagen
// ---------------------------------------------------------------------------

/**
 * Recorta la franja central del fotograma —la que el panel dibuja como guía— y la prepara
 * para el OCR: amplía, pasa a gris, estira el contraste y binariza por el método de Otsu.
 *
 * El recorte es lo que más aporta: el guardia encuadra la placa dentro del marco, así que el
 * resto de la imagen (capó, calle, otros coches) es ruido que solo puede empeorar la lectura.
 */
export function prepararImagenParaOcr(
  origen: HTMLVideoElement | HTMLImageElement,
  canvas: HTMLCanvasElement,
): string {
  const anchoOrigen = origen instanceof HTMLVideoElement ? origen.videoWidth : origen.naturalWidth
  const altoOrigen = origen instanceof HTMLVideoElement ? origen.videoHeight : origen.naturalHeight
  if (!anchoOrigen || !altoOrigen) throw new Error('La cámara todavía no ha entregado imagen.')

  // Misma proporción que el marco guía del panel: 70 % del ancho, 26 % del alto, centrado.
  const anchoRecorte = Math.round(anchoOrigen * 0.7)
  const altoRecorte = Math.round(altoOrigen * 0.26)
  const x = Math.round((anchoOrigen - anchoRecorte) / 2)
  const y = Math.round((altoOrigen - altoRecorte) / 2)

  // Tesseract acierta mucho más si los caracteres miden 30 px o más de alto. Se amplía hasta
  // un ancho de trabajo fijo en vez de usar la resolución nativa, que varía con cada cámara.
  const anchoTrabajo = 1000
  const escala = anchoTrabajo / anchoRecorte
  canvas.width = anchoTrabajo
  canvas.height = Math.round(altoRecorte * escala)

  const ctx = canvas.getContext('2d', { willReadFrequently: true })!
  ctx.imageSmoothingEnabled = true
  ctx.imageSmoothingQuality = 'high'
  ctx.drawImage(origen, x, y, anchoRecorte, altoRecorte, 0, 0, canvas.width, canvas.height)

  const imagen = ctx.getImageData(0, 0, canvas.width, canvas.height)
  const pixeles = imagen.data

  // 1. Escala de grises con pesos de luminancia, y histograma para los dos pasos siguientes.
  const grises = new Uint8Array(pixeles.length / 4)
  const histograma = new Array(256).fill(0)
  for (let i = 0, j = 0; i < pixeles.length; i += 4, j++) {
    const gris = Math.round(0.299 * pixeles[i] + 0.587 * pixeles[i + 1] + 0.114 * pixeles[i + 2])
    grises[j] = gris
    histograma[gris]++
  }

  // 2. Estirado de contraste, recortando el 2 % de cada extremo. Una placa fotografiada a
  //    contraluz ocupa una franja estrecha del histograma; sin estirarla, el umbral posterior
  //    se lo come todo del mismo lado.
  const total = grises.length
  const recorte = total * 0.02
  let acumulado = 0
  let minimo = 0
  let maximo = 255
  for (let v = 0; v < 256; v++) {
    acumulado += histograma[v]
    if (acumulado > recorte) { minimo = v; break }
  }
  acumulado = 0
  for (let v = 255; v >= 0; v--) {
    acumulado += histograma[v]
    if (acumulado > recorte) { maximo = v; break }
  }
  const rango = Math.max(1, maximo - minimo)

  // 3. Umbral de Otsu sobre el histograma ya estirado: separa fondo de caracteres sin que
  //    haya que elegir a mano un valor que solo funciona con una iluminación concreta.
  const estirados = new Uint8Array(total)
  const histEstirado = new Array(256).fill(0)
  for (let j = 0; j < total; j++) {
    const v = Math.max(0, Math.min(255, Math.round(((grises[j] - minimo) / rango) * 255)))
    estirados[j] = v
    histEstirado[v]++
  }

  let sumaTotal = 0
  for (let v = 0; v < 256; v++) sumaTotal += v * histEstirado[v]
  let sumaFondo = 0
  let pesoFondo = 0
  let mejorVarianza = -1
  let umbral = 128
  for (let v = 0; v < 256; v++) {
    pesoFondo += histEstirado[v]
    if (pesoFondo === 0) continue
    const pesoFrente = total - pesoFondo
    if (pesoFrente === 0) break
    sumaFondo += v * histEstirado[v]
    const mediaFondo = sumaFondo / pesoFondo
    const mediaFrente = (sumaTotal - sumaFondo) / pesoFrente
    const varianza = pesoFondo * pesoFrente * (mediaFondo - mediaFrente) ** 2
    if (varianza > mejorVarianza) { mejorVarianza = varianza; umbral = v }
  }

  for (let i = 0, j = 0; i < pixeles.length; i += 4, j++) {
    const valor = estirados[j] > umbral ? 255 : 0
    pixeles[i] = valor
    pixeles[i + 1] = valor
    pixeles[i + 2] = valor
    pixeles[i + 3] = 255
  }
  ctx.putImageData(imagen, 0, 0)

  return canvas.toDataURL('image/png')
}

// ---------------------------------------------------------------------------
// Motor local (Tesseract.js)
// ---------------------------------------------------------------------------

// Igual que face-api: dependencia pesada que solo necesita la garita, así que se carga bajo
// demanda y queda en su propio chunk en vez de en el bundle que descarga cualquier usuario.
type TesseractModule = typeof import('tesseract.js')
let tesseract: TesseractModule | null = null
// deno-lint-ignore no-explicit-any
let trabajador: any = null

async function obtenerTrabajador() {
  if (trabajador) return trabajador
  if (!tesseract) tesseract = await import('tesseract.js')
  trabajador = await tesseract.createWorker('eng')
  await trabajador.setParameters({
    // Una placa solo tiene letras y dígitos: cualquier otro carácter es una alucinación del
    // OCR, y prohibirlos mejora la lectura además de ahorrar limpieza posterior.
    tessedit_char_whitelist: 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789',
    // PSM 7 = "la imagen es una sola línea de texto", que es exactamente lo que queda tras el
    // recorte. Con el modo automático, Tesseract busca párrafos donde no los hay.
    tessedit_pageseg_mode: '7',
  })
  return trabajador
}

/** Libera el worker de Tesseract. La garita lo llama al desmontar el panel. */
export async function liberarLectorLocal() {
  if (trabajador) {
    await trabajador.terminate()
    trabajador = null
  }
}

export interface LecturaPlaca {
  placa: string
  confianza: number
  motor: 'NUBE' | 'LOCAL' | 'MANUAL'
}

/** Lee la placa de una imagen ya preprocesada, en el navegador. */
export async function leerPlacaLocal(imagenDataUrl: string): Promise<LecturaPlaca | null> {
  const worker = await obtenerTrabajador()
  const { data } = await worker.recognize(imagenDataUrl)

  const placa = extraerPlacaDeTexto(data.text ?? '')
  if (!placa) return null

  return {
    placa,
    // Tesseract da la confianza en 0-100; el resto del sistema trabaja en 0-1.
    confianza: Math.max(0, Math.min(1, (data.confidence ?? 0) / 100)),
    motor: 'LOCAL',
  }
}
