import { afterEach, describe, expect, it, vi } from 'vitest'
import { estaEnTurno, horaEcuadorHHMM } from './format'
import { esUbicacionEPN, normalizarUbicacionEPN, validarUbicacionEPN } from './validacion'
import { CAT } from './catalogos'

/**
 * Turnos de guardia y ubicaciones de la EPN.
 *
 * Los turnos son espejo de `public.esta_en_turno(time, time, time)` y las ubicaciones de
 * `public.es_ubicacion_epn(text)`. Si estas pruebas y la base discrepan, manda la base.
 */

afterEach(() => {
  vi.useRealTimers()
})

describe('estaEnTurno', () => {
  it('un turno diurno contiene su franja y excluye el resto', () => {
    expect(estaEnTurno('07:00', '17:00', '12:00')).toBe(true)
    expect(estaEnTurno('07:00', '17:00', '06:59')).toBe(false)
    expect(estaEnTurno('07:00', '17:00', '22:00')).toBe(false)
  })

  it('la entrada cuenta como dentro y la salida como fuera', () => {
    // Sin este criterio, dos turnos consecutivos (07:00–15:00 y 15:00–23:00) se solaparían un
    // minuto y ambos guardias constarían en turno a las 15:00.
    expect(estaEnTurno('07:00', '17:00', '07:00')).toBe(true)
    expect(estaEnTurno('07:00', '17:00', '17:00')).toBe(false)
  })

  it('el turno nocturno cruza la medianoche', () => {
    // Este es el caso que el turno guardado como texto libre no sabía resolver (§V10).
    expect(estaEnTurno('22:00', '06:00', '23:30')).toBe(true)
    expect(estaEnTurno('22:00', '06:00', '02:00')).toBe(true)
    expect(estaEnTurno('22:00', '06:00', '05:59')).toBe(true)
    expect(estaEnTurno('22:00', '06:00', '06:00')).toBe(false)
    expect(estaEnTurno('22:00', '06:00', '12:00')).toBe(false)
  })

  it('sin horas no se puede afirmar nada: devuelve null, no false', () => {
    // Las asignaciones anteriores a la estructuración del turno tienen las horas en null (la
    // fila con turno "MATUTINO"). Decir "fuera de turno" sería inventarse un dato.
    expect(estaEnTurno(null, null)).toBeNull()
    expect(estaEnTurno('07:00', null)).toBeNull()
  })

  it('usa la hora de Ecuador, no la del navegador', () => {
    // 03:00 UTC del día 20 son las 22:00 del día 19 en Ecuador: dentro del turno nocturno. Con
    // la hora local de un navegador en UTC daría fuera, que es el fallo de §D52 aplicado a horas.
    vi.useFakeTimers()
    vi.setSystemTime(new Date('2026-07-20T03:00:00Z'))
    expect(horaEcuadorHHMM()).toBe('22:00')
    expect(estaEnTurno('22:00', '06:00')).toBe(true)
  })
})

describe('ubicación con la nomenclatura de la EPN', () => {
  it('acepta el formato oficial', () => {
    expect(esUbicacionEPN('E20/P3/E004')).toBe(true)
    expect(esUbicacionEPN('E1/P0/E001')).toBe(true)
  })

  it('exige los tres dígitos del espacio', () => {
    // "E4" y "E004" serían la misma aula escrita de dos formas.
    expect(esUbicacionEPN('E20/P3/E4')).toBe(false)
    expect(esUbicacionEPN('E20/P3/E04')).toBe(false)
  })

  it('rechaza lo que no es una ubicación', () => {
    expect(esUbicacionEPN('E0/P1/E001')).toBe(false) // no hay edificio 0
    expect(esUbicacionEPN('Edificio 20, piso 3')).toBe(false)
    expect(esUbicacionEPN('')).toBe(false)
  })

  it('normaliza lo tecleado antes de darlo por inválido', () => {
    expect(normalizarUbicacionEPN('e20 / p3 / e4')).toBe('E20/P3/E004')
    expect(normalizarUbicacionEPN('E20/P03/E004')).toBe('E20/P3/E004')
    expect(validarUbicacionEPN('e20 / p3 / e4')).toBeNull()
  })

  it('el validador explica el formato cuando no encaja', () => {
    expect(validarUbicacionEPN('E20-P3-E004')).toMatch(/E20\/P3\/E004/)
  })

  it('un campo vacío no es un error de formato', () => {
    // De eso se encarga `required`; si no, el error saldría antes de escribir nada.
    expect(validarUbicacionEPN('')).toBeNull()
  })
})

describe('catálogos de PCO', () => {
  it('una zona solo puede estar activa o inactiva', () => {
    // BLOQUEADA se retiró: era indistinguible de INACTIVA. Espejo de zona_estado_zona_check.
    expect(CAT.zona_estado).toEqual(['ACTIVA', 'INACTIVA'])
  })

  it('un punto de control no puede estar en falla', () => {
    // Un punto de control es un lugar; lo que falla es el dispositivo que hay en él.
    expect(CAT.punto_estado).not.toContain('FALLA')
    expect(CAT.punto_estado).toEqual(['ACTIVO', 'MANTENIMIENTO'])
  })

  it('un dispositivo sí conserva sus averías', () => {
    expect(CAT.dispositivo_estado).toContain('FALLA_DE_RED')
    expect(CAT.dispositivo_estado).toContain('DANO_FISICO')
  })
})
