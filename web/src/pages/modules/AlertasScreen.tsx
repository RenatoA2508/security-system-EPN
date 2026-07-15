import { useEffect, useState } from 'react'
import { ShieldAlert } from 'lucide-react'
import { supabase, mensajeError } from '../../lib/supabase'
import { useAuth } from '../../auth/AuthProvider'
import { fmtFechaHora } from '../../lib/format'
import {
  Badge, Button, Card, CenterSpinner, EmptyState, ErrorBanner, Field, Modal, SidePanel, Textarea, useToast,
} from '../../components/ui'

interface Alerta {
  id_alerta: string
  tipo_alerta: string
  nivel_riesgo: string
  estado_alerta: string
  fecha_hora: string
  accion_atencion: string | null
  observacion_atencion: string | null
  id_evento: string
  evento?: { fecha_hora: string; tipo_movimiento: string; resultado: string; persona?: { nombres: string; apellidos: string; cedula: string } | null } | null
}

/** Alertas de seguridad. Solo el Supervisor CAC las atiende (matriz doc 02, nota ¹⁰). */
export function AlertasScreen() {
  const { tiene } = useAuth()
  const toast = useToast()
  const puedeLeer = tiene('CAC_ALERTA_SELECT')
  const puedeAtender = tiene('CAC_ALERTA_ATENDER')

  const [alertas, setAlertas] = useState<Alerta[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [sel, setSel] = useState<Alerta | null>(null)
  const [atenderOpen, setAtenderOpen] = useState(false)
  const [accion, setAccion] = useState('')
  const [obs, setObs] = useState('')
  const [guardando, setGuardando] = useState(false)

  const cargar = async () => {
    setCargando(true)
    const { data, error } = await supabase
      .from('alerta_seguridad')
      .select('*, evento:evento_acceso(fecha_hora, tipo_movimiento, resultado, persona:persona(nombres, apellidos, cedula))')
      .order('fecha_hora', { ascending: false })
    if (error) setError(mensajeError(error))
    setAlertas((data as Alerta[] | null) ?? [])
    setCargando(false)
  }

  useEffect(() => {
    if (puedeLeer) cargar()
    else setCargando(false)
  }, [puedeLeer])

  const atender = async () => {
    if (!accion.trim()) return
    setGuardando(true)
    const { error } = await supabase
      .from('alerta_seguridad')
      .update({
        estado_alerta: 'ATENDIDA',
        accion_atencion: accion.trim(),
        observacion_atencion: obs.trim() || null,
      })
      .eq('id_alerta', sel!.id_alerta)
    setGuardando(false)
    if (error) {
      toast('error', mensajeError(error))
      return
    }
    toast('ok', 'Alerta atendida.')
    setAtenderOpen(false)
    setSel(null)
    setAccion('')
    setObs('')
    await cargar()
  }

  if (!puedeLeer) return <EmptyState title="No tienes acceso a alertas" hint="Requiere CAC_ALERTA_SELECT." />

  const pendientes = alertas.filter((a) => a.estado_alerta === 'PENDIENTE')

  return (
    <div>
      <ErrorBanner message={error} />
      <div className="mb-3 flex items-center gap-2 text-sm text-ink-soft">
        <ShieldAlert className="h-4 w-4 text-red" />
        {pendientes.length} pendiente(s) de {alertas.length} alerta(s)
      </div>
      <Card className="overflow-hidden">
        {cargando ? (
          <CenterSpinner label="Cargando alertas..." />
        ) : alertas.length === 0 ? (
          <EmptyState title="No hay alertas" hint="Las alertas nacen automáticamente de eventos denegados o permanencia excedida." />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-slate-200 bg-slate-50 text-left text-xs font-medium uppercase text-ink-soft">
                  <th className="px-4 py-2.5">Fecha</th>
                  <th className="px-4 py-2.5">Tipo</th>
                  <th className="px-4 py-2.5">Riesgo</th>
                  <th className="px-4 py-2.5">Persona</th>
                  <th className="px-4 py-2.5">Estado</th>
                </tr>
              </thead>
              <tbody>
                {alertas.map((a) => (
                  <tr key={a.id_alerta} onClick={() => setSel(a)} className="cursor-pointer border-b border-slate-100 last:border-0 hover:bg-slate-50">
                    <td className="px-4 py-2.5">{fmtFechaHora(a.fecha_hora)}</td>
                    <td className="px-4 py-2.5 text-navy">{a.tipo_alerta.replaceAll('_', ' ')}</td>
                    <td className="px-4 py-2.5"><Badge value={a.nivel_riesgo} /></td>
                    <td className="px-4 py-2.5">{a.evento?.persona ? `${a.evento.persona.apellidos} ${a.evento.persona.nombres}` : '—'}</td>
                    <td className="px-4 py-2.5"><Badge value={a.estado_alerta} /></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Card>

      <SidePanel
        open={!!sel}
        onClose={() => setSel(null)}
        title={sel ? sel.tipo_alerta.replaceAll('_', ' ') : undefined}
        footer={
          sel && puedeAtender && sel.estado_alerta === 'PENDIENTE' ? (
            <Button className="flex-1" onClick={() => setAtenderOpen(true)}>Atender alerta</Button>
          ) : null
        }
      >
        {sel && (
          <div>
            <div className="mb-4 flex gap-2"><Badge value={sel.nivel_riesgo} /> <Badge value={sel.estado_alerta} /></div>
            <dl className="divide-y divide-slate-100">
              <Row label="Fecha" val={fmtFechaHora(sel.fecha_hora)} />
              <Row label="Persona" val={sel.evento?.persona ? `${sel.evento.persona.nombres} ${sel.evento.persona.apellidos}` : '—'} />
              <Row label="Cédula" val={sel.evento?.persona?.cedula ?? '—'} />
              <Row label="Evento" val={sel.evento ? `${sel.evento.tipo_movimiento} · ${sel.evento.resultado}` : '—'} />
              <Row label="Acción de atención" val={sel.accion_atencion ?? '—'} />
              <Row label="Observación" val={sel.observacion_atencion ?? '—'} />
            </dl>
          </div>
        )}
      </SidePanel>

      <Modal
        open={atenderOpen}
        onClose={() => setAtenderOpen(false)}
        title="Atender alerta"
        footer={
          <>
            <Button variant="secondary" onClick={() => setAtenderOpen(false)}>Cancelar</Button>
            <Button onClick={atender} loading={guardando} disabled={!accion.trim()}>Marcar como atendida</Button>
          </>
        }
      >
        <div className="space-y-4">
          <Field label="Acción tomada" required>
            <Textarea value={accion} onChange={(e) => setAccion(e.target.value)} placeholder="Describe la acción tomada..." />
          </Field>
          <Field label="Observación (opcional)">
            <Textarea value={obs} onChange={(e) => setObs(e.target.value)} />
          </Field>
        </div>
      </Modal>
    </div>
  )
}

function Row({ label, val }: { label: string; val: string }) {
  return (
    <div className="grid grid-cols-3 gap-2 py-2">
      <dt className="text-xs font-medium text-ink-soft">{label}</dt>
      <dd className="col-span-2 text-sm text-navy">{val}</dd>
    </div>
  )
}
