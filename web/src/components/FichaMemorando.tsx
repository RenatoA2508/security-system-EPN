import { useEffect, useState } from 'react'
import { FileText } from 'lucide-react'
import { supabase } from '../lib/supabase'
import { fmtFecha } from '../lib/format'
import { humanizar } from '../lib/catalogos'
import { estadoMemorandoEfectivo } from '../lib/vigencia'
import { Badge, Spinner } from './ui'

interface MemorandoLite {
  id_memorando: string
  numero_memorando: string
  dependencia_autorizada: string | null
  fecha_inicio: string
  fecha_fin: string
  estado_memorando: string
  motivo_anulacion: string | null
  empresa?: { nombre: string } | null
}

/**
 * RF-CA-011: el guardia debe poder consultar el memorando de la persona ANTES de autorizar o
 * denegar el ingreso, con número, dependencia, fechas, estado y motivo.
 *
 * Hasta ahora la garita solo mostraba una etiqueta con la vía de vigencia ("MEMORANDO"), sin
 * decir cuál, de quién ni hasta cuándo: el guardia tenía que fiarse de una palabra. Si alguien
 * llegaba con un memorando en papel, no había forma de contrastarlo con el sistema.
 *
 * El estado que se muestra es el EFECTIVO, no el almacenado: un memorando cuya fecha de fin ya
 * pasó sigue guardado como VIGENTE hasta que algo lo actualice, y enseñarle eso al guardia
 * sería justo lo contrario de lo que pide RF-CA-010.
 */
export function FichaMemorando({ idPersona }: { idPersona: string }) {
  const [memorandos, setMemorandos] = useState<MemorandoLite[]>([])
  const [cargando, setCargando] = useState(true)

  useEffect(() => {
    let vigente = true
    ;(async () => {
      setCargando(true)
      const { data } = await supabase
        .from('persona_memorando')
        .select(
          'estado_acceso, memorando:memorando(id_memorando, numero_memorando, dependencia_autorizada, fecha_inicio, fecha_fin, estado_memorando, motivo_anulacion, empresa:empresa(nombre))',
        )
        .eq('id_persona', idPersona)
      if (!vigente) return
      const lista = ((data ?? []) as { memorando: MemorandoLite | null }[])
        .map((fila) => fila.memorando)
        .filter((m): m is MemorandoLite => Boolean(m))
      setMemorandos(lista)
      setCargando(false)
    })()
    return () => { vigente = false }
  }, [idPersona])

  if (cargando) return <div className="mt-3"><Spinner /></div>
  if (memorandos.length === 0) return null

  return (
    <div className="mt-3 rounded-lg border border-slate-200 bg-slate-50 p-3">
      <p className="mb-2 flex items-center gap-2 text-xs font-semibold uppercase tracking-wide text-ink-soft">
        <FileText className="h-3.5 w-3.5" /> {memorandos.length === 1 ? 'Memorando' : 'Memorandos'}
      </p>
      <ul className="space-y-3">
        {memorandos.map((m) => {
          const estado = estadoMemorandoEfectivo(m)
          return (
            <li key={m.id_memorando} className="text-sm">
              <div className="flex flex-wrap items-center gap-2">
                <span className="font-medium text-navy">{m.numero_memorando}</span>
                <Badge value={estado} />
              </div>
              <dl className="mt-1 grid grid-cols-[auto_1fr] gap-x-3 gap-y-0.5 text-xs text-ink-soft">
                <dt>Dependencia</dt>
                <dd className="text-navy">{m.dependencia_autorizada ?? '—'}</dd>
                <dt>Empresa</dt>
                <dd className="text-navy">{m.empresa?.nombre ?? '—'}</dd>
                <dt>Vigencia</dt>
                <dd className="text-navy">{fmtFecha(m.fecha_inicio)} — {fmtFecha(m.fecha_fin)}</dd>
              </dl>
              {estado === 'VENCIDO' && (
                <p className="mt-1 text-xs text-red">
                  Venció el {fmtFecha(m.fecha_fin)}. No autoriza el ingreso.
                </p>
              )}
              {estado === 'PROGRAMADO' && (
                <p className="mt-1 text-xs text-amber-700">
                  Entra en vigencia el {fmtFecha(m.fecha_inicio)}. Todavía no autoriza el ingreso.
                </p>
              )}
              {estado === 'ANULADO' && (
                <p className="mt-1 text-xs text-red">
                  Anulado.{m.motivo_anulacion ? ` Motivo: ${humanizar(m.motivo_anulacion)}` : ''}
                </p>
              )}
            </li>
          )
        })}
      </ul>
    </div>
  )
}
