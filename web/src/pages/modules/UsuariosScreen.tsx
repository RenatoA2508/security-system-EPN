import { useEffect, useMemo, useState } from 'react'
import { KeyRound, Lock, Search, ShieldCheck, UserX } from 'lucide-react'
import { supabase, mensajeError } from '../../lib/supabase'
import { useAuth } from '../../auth/AuthProvider'
import { fmtFechaHora } from '../../lib/format'
import {
  Badge, Button, Card, CenterSpinner, EmptyState, ErrorBanner, Modal, SidePanel, useToast,
} from '../../components/ui'

interface Usuario {
  id_usuario: string
  nombre_usuario: string
  correo_electronico: string
  estado_usuario: string
  requiere_cambio_password: boolean
  fecha_ultimo_login: string | null
  intentos_fallidos: number
  persona?: { nombres: string; apellidos: string; cedula: string } | null
}

/**
 * Gestión de usuarios (feedback ADM §5.3/§7.2): la pantalla genérica de CRUD no alcanza para
 * esto porque cada transición de estado tiene su propio permiso granular (bloquear/desbloquear/
 * activar/dar de baja) en vez de un solo ADM_USUARIO_UPDATE — y "restablecer contraseña" no es
 * ni siquiera un UPDATE de esta tabla, es la Auth Admin API vía Edge Function.
 */
export function UsuariosScreen() {
  const { tiene } = useAuth()
  const toast = useToast()
  const puedeLeer = tiene('ADM_USUARIO_SELECT')

  const [usuarios, setUsuarios] = useState<Usuario[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [busqueda, setBusqueda] = useState('')
  const [sel, setSel] = useState<Usuario | null>(null)
  const [accionando, setAccionando] = useState(false)
  const [passwordModal, setPasswordModal] = useState<string | null>(null)

  const cargar = async () => {
    setCargando(true)
    const { data, error } = await supabase
      .from('usuario_sistema')
      .select('id_usuario, nombre_usuario, correo_electronico, estado_usuario, requiere_cambio_password, fecha_ultimo_login, intentos_fallidos, persona:persona!usuario_sistema_id_persona_fkey(nombres, apellidos, cedula)')
      .order('nombre_usuario')
    if (error) setError(mensajeError(error))
    setUsuarios((data as Usuario[] | null) ?? [])
    setCargando(false)
  }

  useEffect(() => {
    if (puedeLeer) cargar()
    else setCargando(false)
  }, [puedeLeer])

  const filtrados = useMemo(() => {
    const t = busqueda.trim().toLowerCase()
    if (!t) return usuarios
    return usuarios.filter((u) =>
      [u.nombre_usuario, u.correo_electronico, u.persona?.cedula, u.persona?.apellidos]
        .some((c) => String(c ?? '').toLowerCase().includes(t)),
    )
  }, [usuarios, busqueda])

  const cambiarEstado = async (nuevoEstado: string) => {
    if (!sel) return
    setAccionando(true)
    const { error } = await supabase.from('usuario_sistema').update({ estado_usuario: nuevoEstado }).eq('id_usuario', sel.id_usuario)
    setAccionando(false)
    if (error) {
      toast('error', mensajeError(error))
      return
    }
    toast('ok', 'Estado actualizado.')
    setSel((s) => (s ? { ...s, estado_usuario: nuevoEstado } : s))
    await cargar()
  }

  const resetearPassword = async () => {
    if (!sel) return
    setAccionando(true)
    const { data: sess } = await supabase.auth.getSession()
    const resp = await fetch(`${import.meta.env.VITE_SUPABASE_URL}/functions/v1/resetear-password-usuario`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        apikey: import.meta.env.VITE_SUPABASE_ANON_KEY as string,
        Authorization: `Bearer ${sess.session?.access_token}`,
      },
      body: JSON.stringify({ id_usuario: sel.id_usuario }),
    })
    const json = await resp.json()
    setAccionando(false)
    if (!resp.ok) {
      toast('error', json.error ?? 'No se pudo restablecer la contraseña.')
      return
    }
    setPasswordModal(json.password_temporal)
    await cargar()
  }

  if (!puedeLeer) return <EmptyState title="No tienes acceso a usuarios" hint="Requiere ADM_USUARIO_SELECT." />

  return (
    <div>
      <ErrorBanner message={error} />
      <div className="relative mb-3 max-w-md">
        <Search className="pointer-events-none absolute left-3 top-2.5 h-4 w-4 text-slate-400" />
        <input
          value={busqueda}
          onChange={(e) => setBusqueda(e.target.value)}
          placeholder="Buscar por usuario, correo, cédula..."
          className="epn-input pl-9"
        />
      </div>
      <Card className="overflow-hidden">
        {cargando ? (
          <CenterSpinner label="Cargando usuarios..." />
        ) : filtrados.length === 0 ? (
          <EmptyState title="Sin resultados" />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-slate-200 bg-slate-50 text-left text-xs font-medium uppercase text-ink-soft">
                  <th className="px-4 py-2.5">Usuario</th>
                  <th className="px-4 py-2.5">Correo</th>
                  <th className="px-4 py-2.5">Persona</th>
                  <th className="px-4 py-2.5">Estado</th>
                </tr>
              </thead>
              <tbody>
                {filtrados.map((u) => (
                  <tr key={u.id_usuario} onClick={() => setSel(u)} className="cursor-pointer border-b border-slate-100 last:border-0 hover:bg-slate-50">
                    <td className="px-4 py-2.5 font-medium text-navy">{u.nombre_usuario}</td>
                    <td className="px-4 py-2.5">{u.correo_electronico}</td>
                    <td className="px-4 py-2.5">{u.persona ? `${u.persona.nombres} ${u.persona.apellidos}` : '—'}</td>
                    <td className="px-4 py-2.5"><Badge value={u.estado_usuario} /></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Card>
      <p className="mt-2 text-xs text-slate-400">{filtrados.length} usuario(s)</p>

      <SidePanel open={!!sel} onClose={() => setSel(null)} title={sel?.nombre_usuario}>
        {sel && (
          <div>
            <div className="mb-4 flex flex-wrap gap-2">
              <Badge value={sel.estado_usuario} />
              {sel.requiere_cambio_password && <Badge value="CAMBIO_PENDIENTE" />}
            </div>
            <dl className="mb-5 divide-y divide-slate-100">
              <Row label="Correo" val={sel.correo_electronico} />
              <Row label="Persona" val={sel.persona ? `${sel.persona.nombres} ${sel.persona.apellidos}` : '—'} />
              <Row label="Cédula" val={sel.persona?.cedula ?? '—'} />
              <Row label="Último login" val={fmtFechaHora(sel.fecha_ultimo_login)} />
              <Row label="Intentos fallidos" val={String(sel.intentos_fallidos)} />
            </dl>
            <div className="space-y-2">
              {tiene('ADM_USUARIO_BLOQUEAR') && sel.estado_usuario === 'ACTIVO' && (
                <Button variant="danger" className="w-full" loading={accionando} onClick={() => cambiarEstado('BLOQUEADO')}>
                  <Lock className="h-4 w-4" /> Bloquear usuario
                </Button>
              )}
              {tiene('ADM_USUARIO_DESBLOQUEAR') && sel.estado_usuario === 'BLOQUEADO' && (
                <Button className="w-full" loading={accionando} onClick={() => cambiarEstado('ACTIVO')}>
                  <ShieldCheck className="h-4 w-4" /> Desbloquear usuario
                </Button>
              )}
              {tiene('ADM_USUARIO_ACTIVAR') && sel.estado_usuario !== 'ACTIVO' && sel.estado_usuario !== 'BLOQUEADO' && (
                <Button className="w-full" loading={accionando} onClick={() => cambiarEstado('ACTIVO')}>
                  <ShieldCheck className="h-4 w-4" /> Activar usuario
                </Button>
              )}
              {tiene('ADM_USUARIO_DAR_BAJA') && sel.estado_usuario !== 'DADO_DE_BAJA' && (
                <Button variant="danger" className="w-full" loading={accionando} onClick={() => cambiarEstado('DADO_DE_BAJA')}>
                  <UserX className="h-4 w-4" /> Dar de baja
                </Button>
              )}
              {tiene('ADM_USUARIO_RESETEAR_PASSWORD') && (
                <Button variant="secondary" className="w-full" loading={accionando} onClick={resetearPassword}>
                  <KeyRound className="h-4 w-4" /> Restablecer contraseña
                </Button>
              )}
            </div>
          </div>
        )}
      </SidePanel>

      <Modal open={!!passwordModal} onClose={() => setPasswordModal(null)} title="Contraseña restablecida">
        <p className="mb-3 text-sm text-ink-soft">
          Comunica esta contraseña temporal al usuario por un canal seguro. Deberá cambiarla en su próximo inicio de sesión.
        </p>
        <p className="rounded-md bg-slate-100 px-3 py-2 font-mono text-sm text-navy">{passwordModal}</p>
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
