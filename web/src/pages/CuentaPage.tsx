import { useState } from 'react'
import { KeyRound } from 'lucide-react'
import { supabase, mensajeError } from '../lib/supabase'
import { useAuth } from '../auth/AuthProvider'
import { Breadcrumb } from '../components/layout/Shell'
import { Badge, Button, Card, ErrorBanner, Field, Input, useToast } from '../components/ui'

/** Cuenta propia: cambiar contraseña (flujo nativo de Supabase Auth, 05 §2.5). */
export function CuentaPage() {
  const { perfil, roles, rolLabel, refrescarPerfil } = useAuth()
  const toast = useToast()
  const [p1, setP1] = useState('')
  const [p2, setP2] = useState('')
  const [guardando, setGuardando] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const cambiar = async (e: React.FormEvent) => {
    e.preventDefault()
    setError(null)
    if (p1.length < 8) { setError('La contraseña debe tener al menos 8 caracteres.'); return }
    if (p1 !== p2) { setError('Las contraseñas no coinciden.'); return }
    setGuardando(true)
    // No se intenta bajar `requiere_cambio_password` en usuario_sistema: la matriz de permisos
    // (doc 02) solo da UPDATE sobre esa tabla a ADMIN; para el resto de roles es un no-op
    // silencioso de RLS (verificado en vivo). El aviso se descarta localmente (ver BannerPassword).
    const { error } = await supabase.auth.updateUser({ password: p1 })
    setGuardando(false)
    if (error) { setError(mensajeError(error)); return }
    setP1(''); setP2('')
    await refrescarPerfil()
    toast('ok', 'Contraseña actualizada.')
  }

  return (
    <div>
      <Breadcrumb items={[{ label: 'Panel Principal', to: '/' }, { label: 'Mi cuenta' }]} />
      <h1 className="mb-4 text-xl font-bold text-navy">Mi cuenta</h1>

      <div className="grid gap-6 lg:grid-cols-2">
        <Card className="p-5">
          <h3 className="mb-3 text-base font-semibold text-navy">Datos del usuario</h3>
          <dl className="space-y-2 text-sm">
            <div className="flex justify-between"><dt className="text-ink-soft">Nombre</dt><dd className="text-navy">{perfil?.nombre_completo}</dd></div>
            <div className="flex justify-between"><dt className="text-ink-soft">Usuario</dt><dd className="text-navy">{perfil?.nombre_usuario}</dd></div>
            <div className="flex justify-between"><dt className="text-ink-soft">Correo</dt><dd className="text-navy">{perfil?.correo_electronico}</dd></div>
            <div className="flex justify-between"><dt className="text-ink-soft">Rol</dt><dd className="text-navy">{roles.length ? roles.map((r) => r.replaceAll('_', ' ')).join(', ') : rolLabel}</dd></div>
            <div className="flex justify-between"><dt className="text-ink-soft">Cambio requerido</dt><dd>{perfil?.requiere_cambio_password ? <Badge value="PENDIENTE" /> : <Badge value="ACTIVO" />}</dd></div>
          </dl>
        </Card>

        <Card className="p-5">
          <h3 className="mb-3 flex items-center gap-2 text-base font-semibold text-navy"><KeyRound className="h-5 w-5" /> Cambiar contraseña</h3>
          <form onSubmit={cambiar} className="space-y-3">
            <Field label="Nueva contraseña" required>
              <Input type="password" value={p1} onChange={(e) => setP1(e.target.value)} autoComplete="new-password" />
            </Field>
            <Field label="Confirmar contraseña" required>
              <Input type="password" value={p2} onChange={(e) => setP2(e.target.value)} autoComplete="new-password" />
            </Field>
            <ErrorBanner message={error} />
            <Button type="submit" loading={guardando}>Actualizar contraseña</Button>
          </form>
        </Card>
      </div>
    </div>
  )
}
