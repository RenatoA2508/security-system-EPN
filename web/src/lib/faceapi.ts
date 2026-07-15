/**
 * Descriptor facial 128-d calculado EN EL NAVEGADOR con face-api.js.
 * La comparación 1:N ocurre en el backend (pgvector) vía la Edge Function
 * `validar-biometria`; el enrolamiento vía RPC `enrolar_biometria`.
 * Ver docs/01_AUTENTICACION_Y_ROLES.md §6 y scripts/banco_biometria/index.html.
 *
 * Solo aplica a personas INTERNAS (§D20). Los externos NUNCA tienen biometría.
 */
import * as faceapi from '@vladmandic/face-api'

// Mismos pesos que el banco de pruebas; se cargan por CDN (requiere internet).
const MODELS_URL = 'https://cdn.jsdelivr.net/npm/@vladmandic/face-api@1.7.15/model'

let cargando: Promise<void> | null = null
let listo = false

export function modelosListos(): boolean {
  return listo
}

/** Carga (una sola vez) los modelos necesarios para detección + descriptor. */
export function cargarModelos(): Promise<void> {
  if (listo) return Promise.resolve()
  if (!cargando) {
    cargando = (async () => {
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
