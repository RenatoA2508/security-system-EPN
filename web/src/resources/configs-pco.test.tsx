import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MemoryRouter } from 'react-router-dom'

/**
 * Pantallas de PCO: infraestructura física y asignaciones de guardia.
 *
 * Cubre los bugs que reportó el módulo y que resultaron tener dos causas distintas:
 *
 *  - Combos de cascada vacíos al EDITAR ("en la parte de Zona no aparece nada", "el campo Punto
 *    de control no tiene nada para seleccionar"). Causa: los filtros auxiliares no son columnas
 *    de la tabla, así que no venían en el registro y arrancaban en "".
 *  - El nombre del guardia, que era un problema de RLS: el embed devolvía null y la columna
 *    mostraba "—". Aquí se comprueba la parte de pantalla; la política se prueba contra la base.
 *
 * Y los cambios de criterio: sin combo de Estado al registrar, con Reactivar en la ficha, y la
 * jerarquía Campus -> Edificio -> Parqueadero en el combo de zona padre.
 */

const { supabase, updatesHechos } = vi.hoisted(() => {
  const updatesHechos: { tabla: string; valores: unknown }[] = []

  const CAMPUS = { id_zona: 'z-campus', nombre_zona: 'Campus EPN', tipo_zona: 'CAMPUS', estado_zona: 'ACTIVA', id_zona_padre: null }
  const EDIF20 = { id_zona: 'z-e20', nombre_zona: 'Edificio 20', tipo_zona: 'EDIFICIO', estado_zona: 'ACTIVA', id_zona_padre: 'z-campus' }
  const EDIF15 = { id_zona: 'z-e15', nombre_zona: 'Edificio 15', tipo_zona: 'EDIFICIO', estado_zona: 'ACTIVA', id_zona_padre: 'z-campus' }
  // Una zona ya inactivada: es la que debe ofrecer "Reactivar" y no "Inactivar".
  const PARQUE = { id_zona: 'z-parq', nombre_zona: 'Parqueadero Subsuelo', tipo_zona: 'PARQUEADERO', estado_zona: 'INACTIVA', id_zona_padre: 'z-e20' }

  const PUNTO_E20 = { id_punto_control: 'p-1', id_zona: 'z-e20', nombre_punto: 'Puerta Norte', estado_punto: 'ACTIVO', fecha_registro: '2026-07-01T00:00:00Z', zona: { nombre_zona: 'Edificio 20' } }
  // Una garita de entrada a la universidad: cuelga del CAMPUS, que es el tipo que se retiró del
  // formulario de alta. Este caso lo detectó TestSprite, no las pruebas de aquí (§V25).
  const PUNTO_CAMPUS = { id_punto_control: 'p-2', id_zona: 'z-campus', nombre_punto: 'Acceso A', estado_punto: 'ACTIVO', fecha_registro: '2026-07-01T00:00:00Z', zona: { nombre_zona: 'Campus EPN' } }

  const filasPorTabla: Record<string, Record<string, unknown>[]> = {
    zona: [CAMPUS, EDIF20, EDIF15, PARQUE],
    punto_control: [PUNTO_E20, PUNTO_CAMPUS],
    dispositivo: [{
      id_dispositivo: 'd-1', id_punto_control: 'p-1', codigo_mac: 'AA:BB:CC:DD:EE:FF',
      direccion_ip: '10.0.0.10', tipo_tecnologia: 'BIOMETRIA_FACIAL', estado_dispositivo: 'OPERATIVO',
      punto: { nombre_punto: 'Puerta Norte' },
    }],
    guardia_punto_control: [{
      id_asignacion: 'a-1', id_usuario: 'u-g1', id_punto_control: 'p-1',
      turno: '07:00–17:00', hora_inicio: '07:00:00', hora_fin: '17:00:00',
      fecha_inicio: '2026-07-01T00:00:00Z', fecha_fin: '2026-07-31T00:00:00Z',
      estado_asignacion: 'ACTIVA',
      guardia: {
        nombre_usuario: 'guardia_demo',
        correo_electronico: 'guardia.demo@epn.edu.ec',
        persona: { nombres: 'Guardia', apellidos: 'Demo', cedula: '1750000018' },
      },
      punto: { nombre_punto: 'Puerta Norte', estado_punto: 'ACTIVO' },
    }, {
      // Asignación impecable sobre un punto que está en mantenimiento: el guardia no puede
      // operar y hasta ahora nada lo decía en pantalla (§V29).
      id_asignacion: 'a-2', id_usuario: 'u-g2', id_punto_control: 'p-3',
      turno: '08:00–16:00', hora_inicio: '08:00:00', hora_fin: '16:00:00',
      fecha_inicio: '2026-07-01T00:00:00Z', fecha_fin: '2026-07-31T00:00:00Z',
      estado_asignacion: 'ACTIVA',
      guardia: {
        nombre_usuario: 'otro_guardia',
        correo_electronico: 'otro@epn.edu.ec',
        persona: { nombres: 'Otro', apellidos: 'Guardia', cedula: '1750000209' },
      },
      punto: { nombre_punto: 'Puerta en obras', estado_punto: 'MANTENIMIENTO' },
    }],
  }

  const cadena = (tabla: string) => {
    const todas = filasPorTabla[tabla] ?? []
    const filtros: [string, unknown][] = []
    const filtradas = () => todas.filter((f) => filtros.every(([c, v]) => f[c] === v))
    const chain: Record<string, unknown> = {}
    const mismo = () => chain
    Object.assign(chain, {
      select: mismo,
      eq: (col: string, val: unknown) => {
        filtros.push([col, val])
        return chain
      },
      neq: mismo, gte: mismo, order: mismo, ilike: mismo,
      maybeSingle: () => Promise.resolve({ data: filtradas()[0] ?? null, error: null }),
      insert: () => Promise.resolve({ error: null }),
      update: (v: unknown) => {
        updatesHechos.push({ tabla, valores: v })
        return { eq: () => Promise.resolve({ error: null }) }
      },
      then: (r: (x: { data: unknown; error: null }) => unknown) =>
        Promise.resolve({ data: filtradas(), error: null }).then(r),
    })
    return chain
  }

  return {
    updatesHechos,
    supabase: {
      from: (t: string) => cadena(t),
      // El combo de guardias sale de un RPC porque PCO no puede leer usuario_rol.
      rpc: (nombre: string) =>
        Promise.resolve({
          data: nombre === 'guardias_disponibles'
            ? [{ id_usuario: 'u-g1', nombre_usuario: 'guardia_demo', correo_electronico: 'guardia.demo@epn.edu.ec' }]
            : [],
          error: null,
        }),
    },
  }
})

vi.mock('../lib/supabase', () => ({
  supabase,
  fromTable: (t: string) => supabase.from(t),
  mensajeError: (e: { message?: string }) => e?.message ?? 'Error',
}))

vi.mock('../auth/AuthProvider', () => ({
  useAuth: () => ({ tiene: () => true, session: { user: { id: 'u-pco' } }, modulos: ['PCO'] }),
}))

const { ResourceScreen } = await import('../components/ResourceScreen')
const { ToastProvider } = await import('../components/ui')
const { cfgZona, cfgPuntoControl, cfgDispositivo, cfgAsignacionGuardia } = await import('./configs')

function montar(config: Parameters<typeof ResourceScreen>[0]['config']) {
  return render(
    <MemoryRouter>
      <ToastProvider>
        <ResourceScreen config={config} />
      </ToastProvider>
    </MemoryRouter>,
  )
}

/** Abre la ficha de una fila del listado y pulsa Editar. */
async function abrirEdicion(usuario: ReturnType<typeof userEvent.setup>, textoFila: RegExp) {
  await usuario.click(await screen.findByText(textoFila))
  await usuario.click(await screen.findByRole('button', { name: /^Editar$/i }))
}

beforeEach(() => {
  window.localStorage.clear()
  updatesHechos.length = 0
  vi.useFakeTimers({ shouldAdvanceTime: true })
  // Dentro del turno 07:00–17:00 en hora de Ecuador.
  vi.setSystemTime(new Date('2026-07-20T12:00:00-05:00'))
})

afterEach(() => {
  vi.useRealTimers()
})

describe('cascada al editar (el bug de los combos vacíos)', () => {
  it('al editar un punto de control, la Zona viene resuelta y con opciones', async () => {
    const usuario = userEvent.setup({ advanceTimers: vi.advanceTimersByTime })
    montar(cfgPuntoControl)

    await abrirEdicion(usuario, /Puerta Norte/)

    // El filtro auxiliar se deriva del registro: el punto vive en un edificio.
    const tipo = await screen.findByRole('combobox', { name: /Tipo de zona/i })
    await waitFor(() => expect(tipo).toHaveValue('EDIFICIO'))

    // Y la consecuencia de eso: el combo Zona tiene opciones y la del registro seleccionada.
    // Antes de este arreglo aquí no había ni una sola opción y no se podía guardar.
    const zona = screen.getByRole('combobox', { name: /^Zona/i })
    await waitFor(() => expect(zona).toHaveValue('z-e20'))
    expect(within(zona).getAllByRole('option').length).toBeGreaterThan(1)
  })

  it('al editar una garita que cuelga del campus, el Tipo de zona no se queda vacío', async () => {
    // Regresión encontrada por TestSprite: al retirar "Campus" del alta, el desplegable se
    // quedaba en "— Seleccionar —" para las seis garitas que sí cuelgan del campus, y como el
    // campo es obligatorio no se podían guardar sin moverlas de zona.
    const usuario = userEvent.setup({ advanceTimers: vi.advanceTimersByTime })
    montar(cfgPuntoControl)

    await abrirEdicion(usuario, /Acceso A/)

    const tipo = await screen.findByRole('combobox', { name: /Tipo de zona/i })
    await waitFor(() => expect(tipo).toHaveValue('CAMPUS'))
    await waitFor(() => expect(screen.getByRole('combobox', { name: /^Zona/i })).toHaveValue('z-campus'))
  })

  it('al editar un dispositivo, el Punto de control viene resuelto y con opciones', async () => {
    const usuario = userEvent.setup({ advanceTimers: vi.advanceTimersByTime })
    montar(cfgDispositivo)

    await abrirEdicion(usuario, /AA:BB:CC:DD:EE:FF/)

    await waitFor(() => expect(screen.getByRole('combobox', { name: /^Zona/i })).toHaveValue('z-e20'))
    const punto = screen.getByRole('combobox', { name: /Punto de control/i })
    await waitFor(() => expect(punto).toHaveValue('p-1'))
    expect(within(punto).getAllByRole('option').length).toBeGreaterThan(1)
  })

  it('al editar una asignación, el Punto de control viene resuelto', async () => {
    const usuario = userEvent.setup({ advanceTimers: vi.advanceTimersByTime })
    montar(cfgAsignacionGuardia)

    await abrirEdicion(usuario, /Guardia Demo/)

    await waitFor(() => expect(screen.getByRole('combobox', { name: /Punto de control/i })).toHaveValue('p-1'))
  })
})

describe('el Estado desaparece del alta pero sigue en la edición', () => {
  it('registrar una zona no pregunta por el estado', async () => {
    const usuario = userEvent.setup({ advanceTimers: vi.advanceTimersByTime })
    montar(cfgZona)

    await usuario.click(await screen.findByRole('button', { name: /Registrar Zona/i }))

    // Positiva primero: el formulario está en pantalla. Sin esto, la negativa de abajo se
    // cumpliría sola aunque no se hubiera abierto nada.
    expect(screen.getByRole('textbox', { name: /Nombre/i })).toBeInTheDocument()
    expect(screen.queryByRole('combobox', { name: /^Estado/i })).not.toBeInTheDocument()
  })

  it('editar una zona sí permite cambiar el estado', async () => {
    const usuario = userEvent.setup({ advanceTimers: vi.advanceTimersByTime })
    montar(cfgZona)

    await abrirEdicion(usuario, /Campus EPN/)

    const estado = await screen.findByRole('combobox', { name: /^Estado/i })
    // Y solo con los dos estados que quedan: BLOQUEADA se retiró del catálogo.
    const opciones = within(estado).getAllByRole('option').map((o) => o.textContent)
    expect(opciones).toContain('Activa')
    expect(opciones).toContain('Inactiva')
    expect(opciones).not.toContain('Bloqueada')
  })

  it('registrar un punto de control no ofrece Campus como tipo de zona', async () => {
    const usuario = userEvent.setup({ advanceTimers: vi.advanceTimersByTime })
    montar(cfgPuntoControl)

    await usuario.click(await screen.findByRole('button', { name: /Registrar Punto de control/i }))

    const tipo = await screen.findByRole('combobox', { name: /Tipo de zona/i })
    const opciones = within(tipo).getAllByRole('option').map((o) => o.textContent)
    expect(opciones).toContain('Edificio')
    expect(opciones).toContain('Parqueadero')
    expect(opciones).not.toContain('Campus')
  })
})

describe('jerarquía de zonas en el combo de zona padre', () => {
  it('un edificio solo puede colgar de un campus', async () => {
    const usuario = userEvent.setup({ advanceTimers: vi.advanceTimersByTime })
    montar(cfgZona)

    await usuario.click(await screen.findByRole('button', { name: /Registrar Zona/i }))
    await usuario.selectOptions(screen.getByRole('combobox', { name: /^Tipo/i }), 'EDIFICIO')

    const padre = await screen.findByRole('combobox', { name: /Zona padre/i })
    await waitFor(() => {
      const opciones = within(padre).getAllByRole('option').map((o) => o.textContent)
      expect(opciones).toContain('Campus EPN')
      expect(opciones).not.toContain('Edificio 20')
    })
  })

  it('un parqueadero solo puede colgar de un edificio', async () => {
    const usuario = userEvent.setup({ advanceTimers: vi.advanceTimersByTime })
    montar(cfgZona)

    await usuario.click(await screen.findByRole('button', { name: /Registrar Zona/i }))
    await usuario.selectOptions(screen.getByRole('combobox', { name: /^Tipo/i }), 'PARQUEADERO')

    const padre = await screen.findByRole('combobox', { name: /Zona padre/i })
    await waitFor(() => {
      const opciones = within(padre).getAllByRole('option').map((o) => o.textContent)
      expect(opciones).toContain('Edificio 20')
      expect(opciones).not.toContain('Campus EPN')
    })
  })
})

describe('inactivar tiene vuelta atrás', () => {
  it('una zona activa ofrece Inactivar y no Reactivar', async () => {
    const usuario = userEvent.setup({ advanceTimers: vi.advanceTimersByTime })
    montar(cfgZona)

    await usuario.click(await screen.findByText(/Campus EPN/))

    expect(await screen.findByRole('button', { name: /Inactivar/i })).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: /Reactivar/i })).not.toBeInTheDocument()
  })

  it('una zona inactiva ofrece Reactivar, y al pulsarlo vuelve a ACTIVA', async () => {
    const usuario = userEvent.setup({ advanceTimers: vi.advanceTimersByTime })
    montar(cfgZona)

    await usuario.click(await screen.findByText(/Parqueadero Subsuelo/))

    const reactivar = await screen.findByRole('button', { name: /Reactivar/i })
    expect(screen.queryByRole('button', { name: /Inactivar/i })).not.toBeInTheDocument()

    await usuario.click(reactivar)

    await waitFor(() =>
      expect(updatesHechos).toContainEqual({ tabla: 'zona', valores: { estado_zona: 'ACTIVA' } }),
    )
  })
})

describe('asignaciones de guardia', () => {
  it('muestra el nombre y la cédula del guardia, no un identificador de cuenta', async () => {
    montar(cfgAsignacionGuardia)

    // El nombre de la persona, no "guardia_demo" ni el correo.
    expect(await screen.findByText(/Guardia Demo/)).toBeInTheDocument()
    // El identificador visible de una persona es siempre la cédula (RF de PCO).
    expect(screen.getByText('1750000018')).toBeInTheDocument()
  })

  it('avisa de si el guardia está en turno en este momento', async () => {
    montar(cfgAsignacionGuardia)

    // Son las 12:00 en Ecuador y el turno de Guardia Demo es 07:00–17:00. Se acota a su fila:
    // hay más asignaciones en pantalla y algunas también están en turno a esa hora.
    const fila = (await screen.findByText(/Guardia Demo/)).closest('tr') as HTMLElement
    expect(within(fila).getByText(/En turno ahora/i)).toBeInTheDocument()
  })

  it('fuera del horario, el mismo turno aparece como fuera de turno', async () => {
    vi.setSystemTime(new Date('2026-07-20T22:00:00-05:00'))
    montar(cfgAsignacionGuardia)

    const fila = (await screen.findByText(/Guardia Demo/)).closest('tr') as HTMLElement
    expect(within(fila).getByText(/Fuera de turno/i)).toBeInTheDocument()
  })

  it('avisa cuando el punto está en mantenimiento y el guardia no puede operar', async () => {
    montar(cfgAsignacionGuardia)

    // Positiva primero: la asignación existe y se ve su punto.
    expect(await screen.findByText(/Puerta en obras/)).toBeInTheDocument()
    // Y el motivo por el que esa asignación no sirve, que antes no aparecía por ninguna parte.
    expect(screen.getByText(/no puede operar aquí/i)).toBeInTheDocument()
  })

  it('el punto operativo no lleva ningún aviso', async () => {
    montar(cfgAsignacionGuardia)

    const fila = (await screen.findByText(/Puerta Norte/)).closest('tr')
    expect(fila).not.toBeNull()
    expect(within(fila as HTMLElement).queryByText(/no puede operar/i)).not.toBeInTheDocument()
  })
})

describe('lista vacía por un filtro', () => {
  it('no dice que no hay registros cuando es el filtro el que los oculta', async () => {
    // Bug detectado por TestSprite: con un filtro de zona aplicado que no casaba con nada, la
    // pantalla de Puntos de control decía "No hay puntos de control registrados" teniendo seis.
    // Cualquiera concluiría que se perdieron los datos.
    const usuario = userEvent.setup({ advanceTimers: vi.advanceTimersByTime })
    montar(cfgPuntoControl)

    // Positiva primero: la lista trae datos antes de filtrar.
    expect(await screen.findByText(/Puerta Norte/)).toBeInTheDocument()

    await usuario.type(screen.getByPlaceholderText(/Buscar/i), 'zzzzz-no-existe')

    await waitFor(() => expect(screen.getByText(/Sin resultados/i)).toBeInTheDocument())
    expect(screen.queryByText(/No hay puntos de control registrados/i)).not.toBeInTheDocument()
    // Y se puede salir del callejón sin buscar el desplegable.
    expect(screen.getByRole('button', { name: /Quitar filtros/i })).toBeInTheDocument()
  })

  it('al quitar los filtros vuelven a verse las filas', async () => {
    const usuario = userEvent.setup({ advanceTimers: vi.advanceTimersByTime })
    montar(cfgPuntoControl)

    await usuario.type(await screen.findByPlaceholderText(/Buscar/i), 'zzzzz-no-existe')
    await waitFor(() => expect(screen.getByText(/Sin resultados/i)).toBeInTheDocument())

    await usuario.click(screen.getByRole('button', { name: /Quitar filtros/i }))

    await waitFor(() => expect(screen.getByText(/Puerta Norte/)).toBeInTheDocument())
  })
})

describe('jornada del guardia', () => {
  it('rechaza un turno de más de 12 horas', async () => {
    const usuario = userEvent.setup({ advanceTimers: vi.advanceTimersByTime })
    montar(cfgAsignacionGuardia)

    await usuario.click(await screen.findByRole('button', { name: /Registrar Asignación/i }))
    await usuario.type(screen.getByLabelText(/Entrada/i), '06:00')
    await usuario.type(screen.getByLabelText(/Salida/i), '20:00')

    // 14 horas: es el turno que tenía registrado frank.jumbo antes de esta ronda.
    expect(await screen.findByText(/no puede durar 14\.0 horas/i)).toBeInTheDocument()
  })

  it('avisa de las horas extra sin bloquear entre 8 y 12 horas', async () => {
    const usuario = userEvent.setup({ advanceTimers: vi.advanceTimersByTime })
    montar(cfgAsignacionGuardia)

    await usuario.click(await screen.findByRole('button', { name: /Registrar Asignación/i }))
    await usuario.type(screen.getByLabelText(/Entrada/i), '07:00')
    await usuario.type(screen.getByLabelText(/Salida/i), '17:00')

    // 10 horas: legal, pero son dos de horas extra y quien lo registra debe saberlo.
    expect(await screen.findByText(/horas extra/i)).toBeInTheDocument()
    expect(screen.queryByText(/no puede durar/i)).not.toBeInTheDocument()
  })

  it('una jornada ordinaria no dice nada', async () => {
    const usuario = userEvent.setup({ advanceTimers: vi.advanceTimersByTime })
    montar(cfgAsignacionGuardia)

    await usuario.click(await screen.findByRole('button', { name: /Registrar Asignación/i }))
    await usuario.type(screen.getByLabelText(/Entrada/i), '08:00')
    await usuario.type(screen.getByLabelText(/Salida/i), '16:00')

    // Positiva primero: el campo tiene el valor que se tecleó.
    expect(screen.getByLabelText(/Salida/i)).toHaveValue('16:00')
    expect(screen.queryByText(/horas extra/i)).not.toBeInTheDocument()
    expect(screen.queryByText(/no puede durar/i)).not.toBeInTheDocument()
  })

  it('el turno nocturno de 8 horas es válido, no uno de 16', async () => {
    const usuario = userEvent.setup({ advanceTimers: vi.advanceTimersByTime })
    montar(cfgAsignacionGuardia)

    await usuario.click(await screen.findByRole('button', { name: /Registrar Asignación/i }))
    await usuario.type(screen.getByLabelText(/Entrada/i), '22:00')
    await usuario.type(screen.getByLabelText(/Salida/i), '06:00')

    expect(screen.getByLabelText(/Salida/i)).toHaveValue('06:00')
    expect(screen.queryByText(/no puede durar/i)).not.toBeInTheDocument()
    expect(screen.queryByText(/horas extra/i)).not.toBeInTheDocument()
  })
})

describe('persistencia del formulario', () => {
  it('conserva lo escrito si se abandona el alta de una zona a medias', async () => {
    const usuario = userEvent.setup({ advanceTimers: vi.advanceTimersByTime })
    const vista = montar(cfgZona)

    await usuario.click(await screen.findByRole('button', { name: /Registrar Zona/i }))
    await usuario.type(screen.getByRole('textbox', { name: /Nombre/i }), 'Edificio 6 - Química')
    await usuario.selectOptions(screen.getByRole('combobox', { name: /^Tipo/i }), 'EDIFICIO')

    // El borrador se guarda con retardo; sin esperar no habría llegado a localStorage.
    await waitFor(
      () => expect(window.localStorage.getItem('epn.borrador:u-pco:zona:nuevo')).not.toBeNull(),
      { timeout: 2000 },
    )
    vista.unmount()

    // Al volver, la pantalla avisa y deja decidir: recuperar el registro sin terminar o no.
    const usuario2 = userEvent.setup({ advanceTimers: vi.advanceTimersByTime })
    montar(cfgZona)
    await usuario2.click(await screen.findByRole('button', { name: /Registrar Zona/i }))
    await usuario2.click(await screen.findByRole('button', { name: /Recuperarlo/i }))

    expect(screen.getByRole('textbox', { name: /Nombre/i })).toHaveValue('Edificio 6 - Química')
    // El tipo también se conserva: si no, la zona padre volvería a quedar sin opciones.
    expect(screen.getByRole('combobox', { name: /^Tipo/i })).toHaveValue('EDIFICIO')
  })

  it('no deja borrador si solo se abre el formulario y se cierra', async () => {
    const usuario = userEvent.setup({ advanceTimers: vi.advanceTimersByTime })
    const vista = montar(cfgZona)

    await usuario.click(await screen.findByRole('button', { name: /Registrar Zona/i }))
    await vi.advanceTimersByTimeAsync(1200)
    vista.unmount()

    montar(cfgZona)
    await usuario.click(await screen.findByRole('button', { name: /Registrar Zona/i }))

    expect(screen.getByRole('textbox', { name: /Nombre/i })).toHaveValue('')
  })
})
