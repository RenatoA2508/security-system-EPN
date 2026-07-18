import { describe, expect, it, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MemoryRouter, Route, Routes } from 'react-router-dom'

const { iniciarSesion, setRecordarSesion } = vi.hoisted(() => ({
  iniciarSesion: vi.fn(),
  setRecordarSesion: vi.fn(),
}))

vi.mock('../lib/supabase', () => ({ iniciarSesion, setRecordarSesion }))
vi.mock('../auth/password', () => ({ consumirAvisoLogin: () => null }))

const { LoginPage } = await import('./LoginPage')

/** Monta el login en una ruta cualquiera para comprobar a dónde navega después. */
function montar(rutaInicial: string) {
  return render(
    <MemoryRouter initialEntries={[rutaInicial]}>
      <Routes>
        <Route path="/" element={<div>PANEL PRINCIPAL</div>} />
        <Route path="*" element={<LoginPage />} />
      </Routes>
    </MemoryRouter>,
  )
}

async function iniciarSesionEnFormulario() {
  const usuario = userEvent.setup()
  await usuario.type(screen.getByLabelText(/usuario/i), 'admin@epn.edu.ec')
  await usuario.type(screen.getByLabelText(/^contraseña/i), 'admin1234')
  await usuario.click(screen.getByRole('button', { name: /ingresar/i }))
  return usuario
}

describe('LoginPage', () => {
  /**
   * REGRESIÓN: el login se renderiza con la ruta comodín, así que la URL podía
   * quedar en una pantalla previa (p. ej. /cuenta tras cambiar la contraseña).
   * Sin redirigir, al volver a entrar el enrutador regresaba allí en vez de al
   * panel principal.
   */
  it('entra al panel principal aunque la URL viniera de otra pantalla', async () => {
    iniciarSesion.mockResolvedValue(null)
    montar('/cuenta')

    expect(screen.queryByText('PANEL PRINCIPAL')).not.toBeInTheDocument()
    await iniciarSesionEnFormulario()

    expect(await screen.findByText('PANEL PRINCIPAL')).toBeInTheDocument()
  })

  it('no navega y muestra el error en español si las credenciales fallan', async () => {
    iniciarSesion.mockResolvedValue('Correo o contraseña incorrectos.')
    montar('/cuenta')

    await iniciarSesionEnFormulario()

    expect(await screen.findByText('Correo o contraseña incorrectos.')).toBeInTheDocument()
    expect(screen.queryByText('PANEL PRINCIPAL')).not.toBeInTheDocument()
  })

  it('comunica la preferencia de "recordar sesión" al autenticar', async () => {
    iniciarSesion.mockResolvedValue(null)
    montar('/login')

    const usuario = userEvent.setup()
    await usuario.click(screen.getByLabelText(/recordar sesión/i))
    await usuario.type(screen.getByLabelText(/usuario/i), 'admin@epn.edu.ec')
    await usuario.type(screen.getByLabelText(/^contraseña/i), 'admin1234')
    await usuario.click(screen.getByRole('button', { name: /ingresar/i }))

    expect(setRecordarSesion).toHaveBeenCalledWith(true)
  })
})
