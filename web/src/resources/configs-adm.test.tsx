import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { render, screen, within } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'

/**
 * ADM — pantalla de empresas: el RUC dice si está verificado (§V12).
 *
 * No hay integración con el SRI en el prototipo, así que ningún RUC llega a VALIDO. Antes la
 * pantalla mostraba el número a secas, que se leía como "verificado". Ahora avisa "sin verificar"
 * cuando el estado es NO_VERIFICADO, para no afirmar algo que el sistema no ha comprobado.
 */

const { supabase } = vi.hoisted(() => {
  const filas: Record<string, Record<string, unknown>[]> = {
    empresa: [
      { id_empresa: 'e-1', nombre: 'Constructora Andes', ruc: '1790012345001', tipo_servicio: 'Obra civil', estado: 'ACTIVO', estado_verificacion_ruc: 'NO_VERIFICADO', fecha_registro: '2026-07-01T00:00:00Z' },
      { id_empresa: 'e-2', nombre: 'Sin RUC S.A.', ruc: null, tipo_servicio: 'Limpieza', estado: 'ACTIVO', estado_verificacion_ruc: 'NO_VERIFICADO', fecha_registro: '2026-07-01T00:00:00Z' },
    ],
  }
  const cadena = (tabla: string) => {
    const todas = filas[tabla] ?? []
    const chain: Record<string, unknown> = {}
    const mismo = () => chain
    Object.assign(chain, {
      select: mismo, eq: mismo, neq: mismo, gte: mismo, order: mismo, ilike: mismo, in: mismo, limit: mismo,
      maybeSingle: () => Promise.resolve({ data: todas[0] ?? null, error: null }),
      insert: () => Promise.resolve({ error: null }),
      update: () => ({ eq: () => Promise.resolve({ error: null }) }),
      then: (r: (x: { data: unknown; error: null }) => unknown) => Promise.resolve({ data: todas, error: null }).then(r),
    })
    return chain
  }
  return { supabase: { from: (t: string) => cadena(t), rpc: () => Promise.resolve({ data: [], error: null }) } }
})

vi.mock('../lib/supabase', () => ({
  supabase,
  fromTable: (t: string) => supabase.from(t),
  mensajeError: (e: { message?: string }) => e?.message ?? 'Error',
}))

vi.mock('../auth/AuthProvider', () => ({
  useAuth: () => ({ tiene: () => true, session: { user: { id: 'u-adm' } }, modulos: ['ADM'] }),
}))

const { ResourceScreen } = await import('../components/ResourceScreen')
const { ToastProvider } = await import('../components/ui')
const { cfgEmpresa } = await import('./configs')

function montar() {
  return render(
    <MemoryRouter>
      <ToastProvider>
        <ResourceScreen config={cfgEmpresa} />
      </ToastProvider>
    </MemoryRouter>,
  )
}

beforeEach(() => window.localStorage.clear())
afterEach(() => vi.clearAllMocks())

describe('empresas: verificación del RUC (§V12)', () => {
  it('un RUC no verificado se marca "sin verificar", no a secas', async () => {
    montar()
    const fila = (await screen.findByText('Constructora Andes')).closest('tr')!
    expect(within(fila).getByText('1790012345001')).toBeInTheDocument()
    expect(within(fila).getByText(/sin verificar/i)).toBeInTheDocument()
  })

  it('una empresa sin RUC muestra un guion, no "sin verificar"', async () => {
    montar()
    const fila = (await screen.findByText('Sin RUC S.A.')).closest('tr')!
    expect(within(fila).queryByText(/sin verificar/i)).not.toBeInTheDocument()
  })
})
