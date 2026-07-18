import { describe, expect, it } from 'vitest'
import {
  autorizacionPermiteAcceso, diasDeVigencia, estadoAutorizacionEfectivo,
  estadoMemorandoEfectivo, memorandoPermiteAcceso, vigenteHastaTexto,
} from './vigencia'

/**
 * Estado real de memorandos y autorizaciones.
 *
 * El bug que originó esto (GPE §2 y §6): los tres memorandos sembrados vencieron el 17/07 y las
 * pantallas seguían mostrándolos como vigentes, porque nada actualizaba `estado_memorando`. El
 * acceso sí se denegaba —la vista de vigencia filtra por fecha— pero quien miraba la pantalla
 * creía lo contrario. Estas pruebas fijan que lo mostrado dependa de la fecha, no de la columna.
 */

const HOY = '2026-07-18'

describe('estado efectivo del memorando', () => {
  it('sigue vigente el último día: fecha_fin es inclusiva (§D24)', () => {
    expect(estadoMemorandoEfectivo({ estado_memorando: 'VIGENTE', fecha_inicio: '2026-07-10', fecha_fin: HOY }, HOY))
      .toBe('VIGENTE')
  })

  it('vence al día siguiente de fecha_fin', () => {
    expect(estadoMemorandoEfectivo({ estado_memorando: 'VIGENTE', fecha_inicio: '2026-07-10', fecha_fin: '2026-07-17' }, HOY))
      .toBe('VENCIDO')
  })

  it('dice VENCIDO aunque la columna siga diciendo VIGENTE', () => {
    // Este es exactamente el caso de la captura del documento: el combo mostraba "Vigente"
    // sobre un memorando que había caducado el día anterior.
    const memorandoDesincronizado = { estado_memorando: 'VIGENTE', fecha_inicio: '2026-07-15', fecha_fin: '2026-07-17' }

    expect(estadoMemorandoEfectivo(memorandoDesincronizado, HOY)).toBe('VENCIDO')
    expect(memorandoPermiteAcceso(memorandoDesincronizado)).toBe(false)
  })

  it('está PROGRAMADO mientras no llega su fecha de inicio', () => {
    expect(estadoMemorandoEfectivo({ estado_memorando: 'VIGENTE', fecha_inicio: '2026-08-01', fecha_fin: '2026-08-30' }, HOY))
      .toBe('PROGRAMADO')
  })

  it('la anulación gana sobre las fechas: es una decisión, no un cálculo', () => {
    expect(estadoMemorandoEfectivo({ estado_memorando: 'ANULADO', fecha_inicio: '2026-07-10', fecha_fin: '2026-12-31' }, HOY))
      .toBe('ANULADO')
  })
})

describe('estado efectivo de la autorización de visita', () => {
  it('vale el día de la visita', () => {
    expect(estadoAutorizacionEfectivo({ estado_autorizacion: 'VIGENTE', fecha_visita: HOY }, HOY)).toBe('VIGENTE')
    expect(autorizacionPermiteAcceso({ estado_autorizacion: 'VIGENTE', fecha_visita: HOY })).toBe(true)
  })

  it('caduca al día siguiente, sin que nadie tenga que tocarla', () => {
    expect(estadoAutorizacionEfectivo({ estado_autorizacion: 'VIGENTE', fecha_visita: '2026-07-17' }, HOY))
      .toBe('CADUCADA')
  })

  it('está PROGRAMADA si la visita es para otro día', () => {
    expect(estadoAutorizacionEfectivo({ estado_autorizacion: 'VIGENTE', fecha_visita: '2026-07-25' }, HOY))
      .toBe('PROGRAMADA')
  })

  it('una autorización revocada no revive por ser de hoy', () => {
    expect(estadoAutorizacionEfectivo({ estado_autorizacion: 'REVOCADA', fecha_visita: HOY }, HOY)).toBe('REVOCADA')
  })
})

describe('días de vigencia', () => {
  it('cuenta ambos extremos', () => {
    // Del 15 al 17 son tres días de acceso, no dos.
    expect(diasDeVigencia('2026-07-15', '2026-07-17')).toBe(3)
    expect(diasDeVigencia('2026-07-15', '2026-07-15')).toBe(1)
  })
})

describe('hasta cuándo se puede entrar', () => {
  it('sin regla de CAC, solo la fecha', () => {
    expect(vigenteHastaTexto('2026-07-17')).toBe('17/07/2026')
  })

  it('con la hora de cierre de CAC, la fecha y la hora (GPE §2)', () => {
    expect(vigenteHastaTexto('2026-07-17', '18:00:00')).toBe('17/07/2026 a las 18:00')
  })
})
