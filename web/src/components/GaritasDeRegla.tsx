import { useEffect, useState } from 'react'
import { MapPin } from 'lucide-react'
import { supabase, mensajeError } from '../lib/supabase'
import { useAuth } from '../auth/AuthProvider'
import { Button, ErrorBanner, Spinner, useToast } from './ui'

interface PuntoLite {
  id_punto_control: string
  nombre_punto: string
  estado_punto: string
}

/**
 * Garitas en las que aplica una regla de acceso (RF-CA-002 y RF-CA-007).
 *
 * El documento de CAC habla de "garitas" en plural tanto al modificar la regla como al
 * validarla, pero el esquema solo permitía una: para autorizar a los docentes por las tres
 * garitas del campus había que crear tres reglas iguales y mantenerlas sincronizadas a mano.
 *
 * La semántica de "ninguna marcada" es deliberada y se explica en pantalla, porque es la
 * diferencia entre una regla que no sirve para nada y una que vale en todas partes: sin
 * garitas marcadas la regla aplica en TODOS los puntos de control. Es la misma que tenía la
 * columna anterior cuando estaba a NULL, así que las reglas que ya existían no cambiaron de
 * comportamiento al migrar.
 */
export function GaritasDeRegla({
  idRegla,
  onCambio,
}: {
  idRegla: string
  onCambio: () => Promise<void>
}) {
  const { tiene } = useAuth()
  const toast = useToast()
  const puedeEditar = tiene('CAC_REGLA_UPDATE')

  const [puntos, setPuntos] = useState<PuntoLite[]>([])
  const [seleccion, setSeleccion] = useState<Set<string>>(new Set())
  const [original, setOriginal] = useState<Set<string>>(new Set())
  const [cargando, setCargando] = useState(true)
  const [guardando, setGuardando] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const cargar = async () => {
    setCargando(true)
    const [{ data: todos }, { data: asignadas }] = await Promise.all([
      supabase
        .from('punto_control')
        .select('id_punto_control, nombre_punto, estado_punto')
        .order('nombre_punto'),
      supabase
        .from('regla_acceso_punto_control')
        .select('id_punto_control')
        .eq('id_regla_acceso', idRegla),
    ])
    setPuntos((todos ?? []) as PuntoLite[])
    const marcadas = new Set(((asignadas ?? []) as { id_punto_control: string }[]).map((g) => g.id_punto_control))
    setSeleccion(marcadas)
    setOriginal(new Set(marcadas))
    setCargando(false)
  }

  useEffect(() => { void cargar() }, [idRegla])

  const alternar = (id: string) => {
    setSeleccion((prev) => {
      const siguiente = new Set(prev)
      if (siguiente.has(id)) siguiente.delete(id)
      else siguiente.add(id)
      return siguiente
    })
  }

  const hayCambios =
    seleccion.size !== original.size || [...seleccion].some((id) => !original.has(id))

  const guardar = async () => {
    setGuardando(true)
    setError(null)

    const aAnadir = [...seleccion].filter((id) => !original.has(id))
    const aQuitar = [...original].filter((id) => !seleccion.has(id))

    try {
      if (aQuitar.length > 0) {
        const { error: errorBorrado } = await supabase
          .from('regla_acceso_punto_control')
          .delete()
          .eq('id_regla_acceso', idRegla)
          .in('id_punto_control', aQuitar)
        if (errorBorrado) throw errorBorrado
      }
      if (aAnadir.length > 0) {
        const { error: errorAlta } = await supabase
          .from('regla_acceso_punto_control')
          .insert(aAnadir.map((id) => ({ id_regla_acceso: idRegla, id_punto_control: id })))
        if (errorAlta) throw errorAlta
      }
      setOriginal(new Set(seleccion))
      toast('ok', 'Garitas de la regla actualizadas.')
      await onCambio()
    } catch (e) {
      setError(mensajeError(e))
    } finally {
      setGuardando(false)
    }
  }

  if (cargando) return <div className="py-4"><Spinner /></div>

  return (
    <div>
      <p className="mb-1 flex items-center gap-2 text-sm font-semibold text-navy">
        <MapPin className="h-4 w-4" /> Garitas donde aplica
      </p>
      <p className="mb-3 text-xs text-ink-soft">
        {seleccion.size === 0
          ? 'Sin ninguna marcada, la regla aplica en todas las garitas.'
          : `La regla solo autoriza el ingreso por ${seleccion.size === 1 ? 'la garita marcada' : `las ${seleccion.size} garitas marcadas`}.`}
      </p>

      <ul className="space-y-1">
        {puntos.map((p) => (
          <li key={p.id_punto_control}>
            <label className="flex cursor-pointer items-center gap-2 rounded-md px-2 py-1.5 text-sm hover:bg-slate-50">
              <input
                type="checkbox"
                checked={seleccion.has(p.id_punto_control)}
                onChange={() => alternar(p.id_punto_control)}
                disabled={!puedeEditar}
              />
              <span className="text-navy">{p.nombre_punto}</span>
              {p.estado_punto !== 'ACTIVO' && (
                <span className="text-xs text-amber-700">(en mantenimiento)</span>
              )}
            </label>
          </li>
        ))}
      </ul>

      <div className="mt-2"><ErrorBanner message={error} /></div>

      {puedeEditar && (
        <Button className="mt-3" onClick={guardar} loading={guardando} disabled={!hayCambios}>
          Guardar garitas
        </Button>
      )}
    </div>
  )
}
