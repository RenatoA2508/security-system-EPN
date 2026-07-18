import { beforeEach, describe, expect, it, vi } from 'vitest'
import { act, renderHook } from '@testing-library/react'
import { useBorrador } from './useBorrador'

/**
 * Persistencia de formularios (req 32). Cubre lo que solo se verificaba a mano:
 * que al ocultar la pestaña (Alt+Tab) el borrador quede guardado y se pueda
 * restaurar, y que nunca se guarden datos sensibles.
 */
describe('useBorrador', () => {
  const CLAVE = 'usuario-1:ADM:vehiculo:nuevo'

  beforeEach(() => {
    localStorage.clear()
    vi.useRealTimers()
  })

  /** Simula que el usuario cambia de pestaña o hace Alt+Tab. */
  function ocultarPestana() {
    Object.defineProperty(document, 'visibilityState', { value: 'hidden', configurable: true })
    act(() => {
      document.dispatchEvent(new Event('visibilitychange'))
    })
  }

  it('guarda el borrador al ocultar la pestaña y lo restaura después', () => {
    const { result } = renderHook(() => useBorrador(CLAVE, { placa: 'PDF1234', marca: 'Toyota' }))

    ocultarPestana()

    expect(result.current.restaurar()).toEqual({ placa: 'PDF1234', marca: 'Toyota' })
  })

  it('no guarda nada cuando no hay clave (sin usuario)', () => {
    const { result } = renderHook(() => useBorrador(null, { placa: 'PDF1234' }))
    ocultarPestana()
    expect(result.current.restaurar()).toBeNull()
  })

  it('descarta el borrador al guardar o cancelar', () => {
    const { result } = renderHook(() => useBorrador(CLAVE, { placa: 'PDF1234' }))
    ocultarPestana()
    expect(result.current.restaurar()).not.toBeNull()

    act(() => result.current.descartar())

    expect(result.current.restaurar()).toBeNull()
  })

  it('NUNCA guarda contraseñas, tokens ni biometría', () => {
    const { result } = renderHook(() =>
      useBorrador(CLAVE, {
        placa: 'PDF1234',
        password: 'secreto123',
        access_token: 'jwt-secreto',
        descriptor_biometrico: [1, 2, 3],
      }),
    )

    ocultarPestana()

    const guardado = result.current.restaurar()
    expect(guardado).toEqual({ placa: 'PDF1234' })
    expect(JSON.stringify(localStorage)).not.toContain('secreto123')
    expect(JSON.stringify(localStorage)).not.toContain('jwt-secreto')
  })

  it('avisa de un borrador previo al volver a abrir el formulario', () => {
    const primero = renderHook(() => useBorrador(CLAVE, { placa: 'PDF1234' }))
    ocultarPestana()
    primero.unmount()

    const segundo = renderHook(() => useBorrador(CLAVE, { placa: '' }))
    expect(segundo.result.current.hayBorrador).toBe(true)
  })
})
