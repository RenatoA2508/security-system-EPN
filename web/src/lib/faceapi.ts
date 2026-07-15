/**
 * Descriptor facial 128-d calculado EN EL NAVEGADOR con face-api.js.
 * La comparación 1:N ocurre en el backend (pgvector) vía la Edge Function
 * `validar-biometria`; el enrolamiento vía RPC `enrolar_biometria`.
 * Ver docs/01_AUTENTICACION_Y_ROLES.md §6 y scripts/banco_biometria/index.html.
 *
 * Solo aplica a personas INTERNAS (§D20). Los externos NUNCA tienen biometría.
 */
// @vladmandic/face-api es una dependencia pesada usada solo por GPI (enrolamiento) y el
// guardia (identificación). Se importa de forma dinámica para que quede en su propio chunk,
// no en el bundle principal que descarga cualquier usuario (ADM/GPE/PCO nunca la necesitan).
type FaceApiModule = typeof import('@vladmandic/face-api')
let faceapiMod: FaceApiModule | null = null

async function cargarLibreria(): Promise<FaceApiModule> {
  if (!faceapiMod) faceapiMod = await import('@vladmandic/face-api')
  return faceapiMod
}

// Mismos pesos que el banco de pruebas; se cargan por CDN (requiere internet).
const MODELS_URL = 'https://cdn.jsdelivr.net/npm/@vladmandic/face-api@1.7.15/model'

let cargando: Promise<void> | null = null
let listo = false

export function modelosListos(): boolean {
  return listo
}

/** Carga (una sola vez) la librería + los modelos necesarios para detección + descriptor. */
export function cargarModelos(): Promise<void> {
  if (listo) return Promise.resolve()
  if (!cargando) {
    cargando = (async () => {
      const faceapi = await cargarLibreria()
      await faceapi.nets.tinyFaceDetector.loadFromUri(MODELS_URL)
      await faceapi.nets.faceLandmark68Net.loadFromUri(MODELS_URL)
      await faceapi.nets.faceRecognitionNet.loadFromUri(MODELS_URL)
      listo = true
    })()
  }
  return cargando
}

/** Calcula el descriptor (128 floats) del rostro visible en un <video>. */
export async function descriptorDesdeVideo(video: HTMLVideoElement): Promise<number[]> {
  await cargarModelos()
  const faceapi = await cargarLibreria()
  const det = await faceapi
    .detectSingleFace(video, new faceapi.TinyFaceDetectorOptions())
    .withFaceLandmarks()
    .withFaceDescriptor()
  if (!det) throw new Error('No se detectó ningún rostro. Acércate y mira a la cámara.')
  return Array.from(det.descriptor)
}

/** Pinta el fotograma actual del video en un canvas y devuelve el JPEG como Blob. */
export function capturarJpeg(video: HTMLVideoElement, canvas: HTMLCanvasElement): Promise<Blob> {
  canvas.getContext('2d')!.drawImage(video, 0, 0, canvas.width, canvas.height)
  return new Promise((res, rej) =>
    canvas.toBlob((b) => (b ? res(b) : rej(new Error('No se pudo capturar la imagen.'))), 'image/jpeg', 0.9),
  )
}
