import { describe, expect, it, vi, afterEach } from 'vitest'
import { mensajeDeErrorDeCamara } from './errores-camara'

/** Construye un DOMException-like con el `name` que devuelve getUserMedia. */
function errorDe(name: string, message = 'detalle tecnico en ingles'): Error {
  const e = new Error(message)
  e.name = name
  return e
}

const ALTERNATIVA = 'Mientras tanto, puedes identificar a la persona escribiendo su cédula.'

describe('mensajeDeErrorDeCamara', () => {
  afterEach(() => vi.unstubAllGlobals())

  it('explica que falta el permiso del navegador', () => {
    const m = mensajeDeErrorDeCamara(errorDe('NotAllowedError'), ALTERNATIVA)
    expect(m).toContain('no dio permiso')
    expect(m).toContain('candado')
  })

  it('distingue que no hay cámara conectada', () => {
    expect(mensajeDeErrorDeCamara(errorDe('NotFoundError'), ALTERNATIVA)).toContain('No se encontró ninguna cámara')
  })

  it('distingue que otro programa la tiene ocupada', () => {
    expect(mensajeDeErrorDeCamara(errorDe('NotReadableError'), ALTERNATIVA)).toContain('ocupada por otro programa')
  })

  it('menciona la conexión segura cuando el contexto no lo es', () => {
    vi.stubGlobal('isSecureContext', false)
    expect(mensajeDeErrorDeCamara(errorDe('AbortError'), ALTERNATIVA)).toContain('conexión segura')
  })

  // Es el caso que apareció en la garita: face-api lanza un error de wasm que no
  // es ninguno de los DOMException conocidos, y el guardia veía el texto crudo.
  it('nunca deja pasar la jerga técnica del error original', () => {
    const wasm = new Error("The highest priority backend 'wasm' has not yet been initialized.")
    const m = mensajeDeErrorDeCamara(wasm, ALTERNATIVA)
    expect(m).not.toContain('wasm')
    expect(m).not.toContain('backend')
    expect(m).toContain('Avisa a soporte')
  })

  it('siempre recuerda la vía alternativa', () => {
    for (const name of ['NotAllowedError', 'NotFoundError', 'NotReadableError', 'AbortError']) {
      expect(mensajeDeErrorDeCamara(errorDe(name), ALTERNATIVA)).toContain(ALTERNATIVA)
    }
  })
})
