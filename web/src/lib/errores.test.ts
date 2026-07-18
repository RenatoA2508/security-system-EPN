import { describe, expect, it } from 'vitest'
import { traducirError } from './errores'

/**
 * Ningún mensaje mostrado al usuario puede quedar en inglés (req 25).
 * Se excluyen a propósito palabras idénticas en ambos idiomas ("error", "token"),
 * que sí aparecen legítimamente en los mensajes en español.
 */
const PALABRAS_INGLESAS =
  /\b(invalid|failed|should be at least|credentials|not found|session missing|violates|constraint|relation|user|email|password|rate limit|unable|banned|already registered)\b/i

describe('traducirError', () => {
  it('traduce el error de credenciales del login', () => {
    // Caso exacto reportado en pantalla.
    expect(traducirError({ message: 'Invalid login credentials' })).toBe('Correo o contraseña incorrectos.')
  })

  it('usa el código estable del proveedor aunque cambie la redacción', () => {
    // Respuesta real de GoTrue: {code:400, error_code:'invalid_credentials', msg:'...'}
    expect(traducirError({ error_code: 'invalid_credentials', msg: 'Whatever wording they ship next' })).toBe(
      'Correo o contraseña incorrectos.',
    )
    expect(traducirError({ error_code: 'user_banned', msg: 'User is banned' })).toMatch(/bloqueada/i)
  })

  it('traduce la sesión perdida', () => {
    expect(traducirError({ message: 'Auth session missing!' })).toMatch(/sesión expiró/i)
    expect(traducirError({ message: 'Invalid Refresh Token: Refresh Token Not Found' })).toMatch(/sesión expiró/i)
  })

  it('conserva el número al informar la longitud mínima', () => {
    expect(traducirError({ message: 'Password should be at least 8 characters' })).toBe(
      'La contraseña debe tener al menos 8 caracteres.',
    )
  })

  it('conserva los segundos de espera del rate limiting', () => {
    expect(
      traducirError({ message: 'For security purposes, you can only request this after 43 seconds.' }),
    ).toBe('Por seguridad, espere 43 segundos antes de volver a intentarlo.')
  })

  it('traduce restricciones de la base por nombre de constraint', () => {
    expect(
      traducirError({
        code: '23514',
        message: 'new row for relation "persona" violates check constraint "persona_cedula_valida"',
      }),
    ).toBe('La cédula no es válida.')

    expect(
      traducirError({
        code: '23505',
        message: 'duplicate key value violates unique constraint "usuario_sistema_correo_electronico_key"',
      }),
    ).toBe('Ese correo ya está asociado con otro usuario.')
  })

  it('traduce una violación de RLS sin revelar la tabla', () => {
    const msg = traducirError({
      code: '42501',
      message: 'new row violates row-level security policy for table "vehiculo"',
    })
    expect(msg).toBe('No tiene permiso para realizar esta acción.')
    expect(msg).not.toMatch(/vehiculo|table/i)
  })

  it('deja pasar los mensajes en español de nuestras propias funciones', () => {
    const propio = 'La persona ya tiene 2 vehiculos activos (maximo 2). Cierra una relacion antes de asociar otra.'
    expect(traducirError({ code: '23514', message: propio })).toBe(propio)

    const turno = 'Su turno no se encuentra habilitado a esta hora.'
    expect(traducirError({ code: '42501', message: turno })).toBe('No tiene permiso para realizar esta acción.')
  })

  it('traduce errores de red', () => {
    expect(traducirError(new TypeError('Failed to fetch'))).toMatch(/conexión a internet/i)
  })

  it('nunca muestra un mensaje desconocido del proveedor', () => {
    const msg = traducirError({ message: 'Something totally unexpected happened in the backend' })
    expect(msg).toBe('Ocurrió un error al procesar la solicitud. Inténtelo nuevamente.')
    expect(msg).not.toMatch(/backend|unexpected/i)
  })

  it('devuelve un mensaje útil si no hay error', () => {
    expect(traducirError(null)).toMatch(/Ocurrió un error/i)
  })

  it('ningún mensaje traducido contiene palabras en inglés', () => {
    const entradas: unknown[] = [
      { message: 'Invalid login credentials' },
      { message: 'Email not confirmed' },
      { message: 'User already registered' },
      { message: 'Auth session missing!' },
      { message: 'Token has expired or is invalid' },
      { message: 'Email rate limit exceeded' },
      { message: 'Unable to validate email address: invalid format' },
      { message: 'User is banned' },
      { message: 'Database error saving new user' },
      { code: '23505', message: 'duplicate key value violates unique constraint "persona_cedula_key"' },
      { code: '42501', message: 'new row violates row-level security policy for table "persona"' },
      { code: 'PGRST116', message: 'The result contains 0 rows' },
      { message: 'Something totally unexpected happened' },
      new TypeError('Failed to fetch'),
    ]
    for (const entrada of entradas) {
      const traducido = traducirError(entrada)
      expect(traducido, `no debería quedar en inglés: ${traducido}`).not.toMatch(PALABRAS_INGLESAS)
    }
  })
})
