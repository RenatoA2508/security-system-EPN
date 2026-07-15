import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { Pencil, Plus, Search, Ban, ArrowLeft } from 'lucide-react'
import { fromTable, mensajeError } from '../lib/supabase'
import { useAuth } from '../auth/AuthProvider'
import type { FieldConfig, Opcion, ResourceConfig } from '../resources/types'
import {
  Badge, Button, Card, CenterSpinner, EmptyState, ErrorBanner, Field, Input, Modal,
  Select, SidePanel, Textarea, useToast,
} from './ui'

type Row = Record<string, any>

/** Resuelve opciones (estáticas o async) de todos los campos select, una vez. */
function useFieldOptions(campos: FieldConfig[]) {
  const [opts, setOpts] = useState<Record<string, Opcion[]>>({})
  useEffect(() => {
    let vivo = true
    ;(async () => {
      const entries = await Promise.all(
        campos
          .filter((c) => c.type === 'select' && c.options)
          .map(async (c) => {
            const o = typeof c.options === 'function' ? await c.options() : (c.options as Opcion[])
            return [c.name, o] as const
          }),
      )
      if (vivo) setOpts(Object.fromEntries(entries))
    })()
    return () => {
      vivo = false
    }
  }, [campos])
  return opts
}

export function ResourceScreen({ config }: { config: ResourceConfig }) {
  const { tiene } = useAuth()
  const toast = useToast()
  const puedeLeer = config.permisos.select.some(tiene)
  const puedeCrear = !!config.permisos.insert?.some(tiene)
  const puedeEditar = !!config.permisos.update?.some(tiene)

  const [rows, setRows] = useState<Row[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [busqueda, setBusqueda] = useState('')
  const [seleccion, setSeleccion] = useState<Row | null>(null)
  const [vista, setVista] = useState<'lista' | 'form'>('lista')
  const [editando, setEditando] = useState<Row | null>(null)
  const [bajaOpen, setBajaOpen] = useState(false)

  const opciones = useFieldOptions(config.campos)

  const cargar = useCallback(async () => {
    setCargando(true)
    setError(null)
    let q = fromTable(config.tabla).select(config.select ?? '*')
    if (config.filtroFijo) for (const [k, v] of Object.entries(config.filtroFijo)) q = q.eq(k, v)
    if (config.orderBy) q = q.order(config.orderBy.columna, { ascending: config.orderBy.ascendente ?? true })
    const { data, error } = await q
    if (error) setError(mensajeError(error))
    setRows((data as Row[] | null) ?? [])
    setCargando(false)
  }, [config])

  useEffect(() => {
    if (puedeLeer) cargar()
    else setCargando(false)
  }, [puedeLeer, cargar])

  const filtradas = useMemo(() => {
    const t = busqueda.trim().toLowerCase()
    if (!t || !config.buscarEn?.length) return rows
    return rows.filter((r) =>
      config.buscarEn!.some((campo) => {
        const val = campo.split('.').reduce<any>((o, k) => o?.[k], r)
        return String(val ?? '').toLowerCase().includes(t)
      }),
    )
  }, [rows, busqueda, config.buscarEn])

  if (!puedeLeer) {
    return (
      <EmptyState
        title="No tienes acceso a esta sección"
        hint="Tu rol no incluye el permiso de lectura requerido. Si crees que es un error, contacta al administrador."
      />
    )
  }

  if (vista === 'form') {
    return (
      <RecordForm
        config={config}
        opciones={opciones}
        registro={editando}
        onCancel={() => setVista('lista')}
        onSaved={async () => {
          setVista('lista')
          setEditando(null)
          await cargar()
          toast('ok', editando ? 'Cambios guardados.' : `${config.singular} registrado.`)
        }}
      />
    )
  }

  return (
    <div>
      <div className="mb-4 flex flex-wrap items-center gap-3">
        <div className="relative flex-1 min-w-[220px]">
          <Search className="pointer-events-none absolute left-3 top-2.5 h-4 w-4 text-slate-400" />
          <Input
            value={busqueda}
            onChange={(e) => setBusqueda(e.target.value)}
            placeholder={`Buscar ${config.titulo.toLowerCase()}...`}
            className="pl-9"
          />
        </div>
        {puedeCrear && (
          <Button
            onClick={() => {
              setEditando(null)
              setVista('form')
            }}
          >
            <Plus className="h-4 w-4" /> Registrar {config.singular}
          </Button>
        )}
      </div>

      <ErrorBanner message={error} />

      <Card className="mt-3 overflow-hidden">
        {cargando ? (
          <CenterSpinner label="Cargando..." />
        ) : filtradas.length === 0 ? (
          <EmptyState title={busqueda ? 'Sin resultados' : `No hay ${config.titulo.toLowerCase()} registrados`} />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-slate-200 bg-slate-50 text-left text-xs font-medium uppercase tracking-wide text-ink-soft">
                  {config.columnas.map((c) => (
                    <th key={c.key} className="px-4 py-2.5">{c.label}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {filtradas.map((r) => (
                  <tr
                    key={r[config.idField]}
                    onClick={() => setSeleccion(r)}
                    className="cursor-pointer border-b border-slate-100 last:border-0 hover:bg-slate-50"
                  >
                    {config.columnas.map((c) => (
                      <td key={c.key} className="px-4 py-2.5 text-navy">
                        {c.badge ? <Badge value={String(r[c.key] ?? '')} /> : c.render ? c.render(r) : (r[c.key] ?? '—')}
                      </td>
                    ))}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Card>
      <p className="mt-2 text-xs text-slate-400">{filtradas.length} registro(s)</p>

      {/* Panel lateral de detalle (Patrón A) */}
      <SidePanel
        open={!!seleccion}
        onClose={() => setSeleccion(null)}
        title={seleccion ? config.campoTituloDetalle(seleccion) : undefined}
        footer={
          (puedeEditar || config.baja) && seleccion ? (
            <>
              {puedeEditar && (
                <Button
                  variant="secondary"
                  className="flex-1"
                  onClick={() => {
                    setEditando(seleccion)
                    setSeleccion(null)
                    setVista('form')
                  }}
                >
                  <Pencil className="h-4 w-4" /> Editar
                </Button>
              )}
              {config.baja && puedeEditar && (
                <Button variant="danger" className="flex-1" onClick={() => setBajaOpen(true)}>
                  <Ban className="h-4 w-4" /> {config.baja.etiqueta ?? 'Dar de baja'}
                </Button>
              )}
            </>
          ) : null
        }
      >
        {seleccion && (
          <div>
            {config.campoSubtituloDetalle && (
              <div className="mb-4 text-sm text-ink-soft">{config.campoSubtituloDetalle(seleccion)}</div>
            )}
            <dl className="divide-y divide-slate-100">
              {config.detalle.map((d, i) => (
                <div key={i} className="grid grid-cols-3 gap-2 py-2">
                  <dt className="text-xs font-medium text-ink-soft">{d.label}</dt>
                  <dd className="col-span-2 text-sm text-navy">{d.render(seleccion)}</dd>
                </div>
              ))}
            </dl>
          </div>
        )}
      </SidePanel>

      {config.baja && seleccion && (
        <BajaModal
          open={bajaOpen}
          config={config}
          registro={seleccion}
          onClose={() => setBajaOpen(false)}
          onDone={async () => {
            setBajaOpen(false)
            setSeleccion(null)
            await cargar()
            toast('ok', 'Baja registrada.')
          }}
        />
      )}
    </div>
  )
}

/* -------------------- Formulario de registro / edición (Patrón B / C) -------------------- */
function RecordForm({
  config, opciones, registro, onCancel, onSaved,
}: {
  config: ResourceConfig
  opciones: Record<string, Opcion[]>
  registro: Row | null
  onCancel: () => void
  onSaved: () => void
}) {
  const { session } = useAuth()
  const esEdicion = !!registro
  const [valores, setValores] = useState<Row>(() => {
    const init: Row = {}
    for (const c of config.campos) {
      init[c.name] = registro ? registro[c.name] ?? '' : c.default ?? (c.type === 'checkbox' ? false : '')
    }
    return init
  })
  const [guardando, setGuardando] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const set = (name: string, v: unknown) => setValores((s) => ({ ...s, [name]: v }))

  const bloqueadoEnEdicion = (c: FieldConfig) => esEdicion && c.editable === false

  const guardar = async () => {
    setError(null)
    // Validación mínima de requeridos
    for (const c of config.campos) {
      if (c.required && !bloqueadoEnEdicion(c) && (valores[c.name] === '' || valores[c.name] == null)) {
        setError(`El campo "${c.label}" es obligatorio.`)
        return
      }
    }
    setGuardando(true)
    const payload: Row = {}
    for (const c of config.campos) {
      if (esEdicion && (c.insertOnly || bloqueadoEnEdicion(c))) continue
      let v = valores[c.name]
      if (v === '') v = null
      if (c.type === 'number' && v != null) v = Number(v)
      payload[c.name] = v
    }
    if (!esEdicion) {
      if (config.defaultsInsert) Object.assign(payload, config.defaultsInsert)
      if (config.autoUsuarioRegistro && session?.user.id)
        for (const col of config.autoUsuarioRegistro) payload[col] = session.user.id
    }

    const res = esEdicion
      ? await fromTable(config.tabla).update(payload).eq(config.idField, registro![config.idField])
      : await fromTable(config.tabla).insert(payload)
    setGuardando(false)
    if (res.error) {
      setError(mensajeError(res.error))
      return
    }
    onSaved()
  }

  return (
    <Card className="p-6">
      <button onClick={onCancel} className="mb-4 inline-flex items-center gap-1 text-sm text-ink-soft hover:text-navy">
        <ArrowLeft className="h-4 w-4" /> Volver al panel
      </button>
      <h2 className="mb-1 text-lg font-bold text-navy">
        {esEdicion ? `Editar ${config.singular}` : `Registrar ${config.singular}`}
      </h2>
      {esEdicion && (
        <p className="mb-4 rounded-md bg-amber-50 px-3 py-2 text-xs text-amber-700">
          Los campos en gris no son editables por diseño (identidad del registro o política de permisos).
        </p>
      )}

      <div className="mb-5"><ErrorBanner message={error} /></div>

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {config.campos.map((c) => {
          const disabled = bloqueadoEnEdicion(c)
          const span = c.colSpan === 3 ? 'lg:col-span-3' : c.colSpan === 2 ? 'sm:col-span-2' : ''
          return (
            <div key={c.name} className={span}>
              {c.type === 'checkbox' ? (
                <label className="flex items-center gap-2 pt-6 text-sm text-navy">
                  <input
                    type="checkbox"
                    checked={!!valores[c.name]}
                    disabled={disabled}
                    onChange={(e) => set(c.name, e.target.checked)}
                    className="h-4 w-4"
                  />
                  {c.label}
                </label>
              ) : (
                <Field label={c.label} required={c.required && !disabled} hint={c.hint}>
                  {c.type === 'select' ? (
                    <Select
                      value={valores[c.name] ?? ''}
                      disabled={disabled}
                      onChange={(e) => set(c.name, e.target.value)}
                      placeholder="— Seleccionar —"
                      options={opciones[c.name] ?? (Array.isArray(c.options) ? (c.options as Opcion[]) : [])}
                    />
                  ) : c.type === 'textarea' ? (
                    <Textarea
                      value={valores[c.name] ?? ''}
                      disabled={disabled}
                      placeholder={c.placeholder}
                      onChange={(e) => set(c.name, e.target.value)}
                    />
                  ) : (
                    <Input
                      type={c.type === 'number' ? 'number' : c.type === 'date' ? 'date' : c.type === 'time' ? 'time' : c.type === 'email' ? 'email' : 'text'}
                      value={valores[c.name] ?? ''}
                      disabled={disabled}
                      placeholder={c.placeholder}
                      onChange={(e) => set(c.name, e.target.value)}
                    />
                  )}
                </Field>
              )}
            </div>
          )
        })}
      </div>

      <div className="mt-6 flex justify-end gap-2">
        <Button variant="secondary" onClick={onCancel}>Volver al panel</Button>
        <Button onClick={guardar} loading={guardando}>{esEdicion ? 'Guardar cambios' : 'Registrar'}</Button>
      </div>
    </Card>
  )
}

/* -------------------- Modal "Dar de baja" (Patrón D) -------------------- */
function BajaModal({
  open, config, registro, onClose, onDone,
}: {
  open: boolean
  config: ResourceConfig
  registro: Row
  onClose: () => void
  onDone: () => void
}) {
  const baja = config.baja!
  const [motivo, setMotivo] = useState('')
  const [tipo, setTipo] = useState(baja.tipos?.[0]?.value ?? '')
  const [guardando, setGuardando] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const ref = useRef<HTMLTextAreaElement>(null)

  useEffect(() => {
    if (open) {
      setMotivo('')
      setError(null)
      setTimeout(() => ref.current?.focus(), 50)
    }
  }, [open])

  const confirmar = async () => {
    if (!motivo.trim()) {
      setError('El motivo es obligatorio.')
      return
    }
    setGuardando(true)
    const payload: Row = { [baja.campoEstado]: baja.valorBaja }
    if (baja.campoMotivo) payload[baja.campoMotivo] = motivo.trim()
    const { error } = await fromTable(config.tabla).update(payload).eq(config.idField, registro[config.idField])
    setGuardando(false)
    if (error) {
      setError(mensajeError(error))
      return
    }
    onDone()
  }

  return (
    <Modal
      open={open}
      onClose={onClose}
      title={`${baja.etiqueta ?? 'Dar de baja'} — ${config.singular}`}
      footer={
        <>
          <Button variant="secondary" onClick={onClose}>Cancelar</Button>
          <Button variant="danger" onClick={confirmar} loading={guardando}>Confirmar baja</Button>
        </>
      }
    >
      <div className="space-y-4">
        <p className="text-sm text-ink-soft">
          Esta acción cambia el estado a <b>{baja.valorBaja}</b>. No elimina el registro (sin borrado físico).
        </p>
        {baja.tipos && (
          <Field label="Tipo de baja">
            <Select value={tipo} onChange={(e) => setTipo(e.target.value)} options={baja.tipos} />
          </Field>
        )}
        <Field label="Motivo" required>
          <Textarea ref={ref} value={motivo} onChange={(e) => setMotivo(e.target.value)} placeholder="Describe el motivo de la baja..." />
        </Field>
        <ErrorBanner message={error} />
      </div>
    </Modal>
  )
}
