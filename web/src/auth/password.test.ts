import { beforeEach, describe, expect, it, vi } from 'vitest'

// vi.hoisted: vi.mock se eleva por encima de las declaraciones, así que los dobles
// deben existir antes de que se evalúe la fábrica del mock.
const { signOut, signInWithPassword } = vi.hoisted(() => ({
  signOut: vi.fn(),
  signInWithPassword: vi.fn(),
}))

vi.mock('@supabase/supabase-js', () => ({
  createClient: () => ({ auth: { signInWithPassword, signOut } }),
}))

// Evita cargar el cliente real (exige VITE_SUPABASE_URL / ANON_KEY).
vi.mock('../lib/supabase', () => ({
  supabase: { auth: { updateUser: vi.fn() }, rpc: vi.fn() },
  mensajeError: (e: unknown) => String(e),
}))

const { reautenticar } = await import('./password')

describe('reautenticar (verificación de la contraseña actual)', () => {
  beforeEach(() => {
    signOut.mockReset().mockResolvedValue({ error: null })
    signInWithPassword.mockReset().mockResolvedValue({ error: null })
  })

  /**
   * REGRESIÓN: signOut() usa scope 'global' por defecto, lo que revoca TODOS los
   * refresh tokens del usuario en el servidor — incluida la sesión real de la app.
   * Eso rompía el cambio de contraseña con "Auth session missing!". El cliente
   * desechable debe cerrarse SOLO a sí mismo.
   */
  it('cierra el cliente desechable con scope local, nunca global', async () => {
    await reautenticar('admin@epn.edu.ec', 'unaClaveValida')
    expect(signOut).toHaveBeenCalledWith({ scope: 'local' })
    expect(signOut).not.toHaveBeenCalledWith()
    expect(signOut).not.toHaveBeenCalledWith({ scope: 'global' })
  })

  it('acepta la contraseña correcta sin lanzar error', async () => {
    await expect(reautenticar('admin@epn.edu.ec', 'unaClaveValida')).resolves.toBeUndefined()
  })

  it('rechaza una contraseña incorrecta con un mensaje en español', async () => {
    signInWithPassword.mockResolvedValueOnce({ error: { message: 'Invalid login credentials' } })
    await expect(reautenticar('admin@epn.edu.ec', 'incorrecta')).rejects.toThrow(
      'La contraseña actual no es correcta.',
    )
  })

  it('no filtra el mensaje crudo del proveedor al usuario', async () => {
    signInWithPassword.mockResolvedValueOnce({ error: { message: 'Invalid login credentials' } })
    await expect(reautenticar('admin@epn.edu.ec', 'incorrecta')).rejects.not.toThrow(
      /Invalid login credentials/,
    )
  })
})
