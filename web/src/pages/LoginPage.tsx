import { useState } from 'react'
import { Eye, EyeOff, ShieldCheck } from 'lucide-react'
import { supabase, mensajeError } from '../lib/supabase'
import { Button, ErrorBanner, Field, Input } from '../components/ui'

export function LoginPage() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [ver, setVer] = useState(false)
  const [recordar, setRecordar] = useState(false)
  const [cargando, setCargando] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const entrar = async (e: React.FormEvent) => {
    e.preventDefault()
    setError(null)
    setCargando(true)
    // Login real con Supabase Auth (05 §2.1). El AuthProvider reacciona al cambio de sesión.
    const { error } = await supabase.auth.signInWithPassword({ email: email.trim(), password })
    setCargando(false)
    if (error) setError(mensajeError(error))
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-gray-bg p-4">
      <div className="w-full max-w-md overflow-hidden rounded-2xl bg-white shadow-xl">
        <div className="bg-navy px-6 py-7 text-center text-white">
          <ShieldCheck className="mx-auto h-10 w-10 text-gold" />
          <h1 className="mt-3 text-lg font-semibold">Sistema de Seguridad — EPN</h1>
          <p className="mt-1 text-xs text-white/60">Control de Accesos · Escuela Politécnica Nacional</p>
          <div className="mx-auto mt-3 h-0.5 w-16 rounded bg-gold" />
        </div>

        <form onSubmit={entrar} className="space-y-4 px-6 py-6">
          <Field label="Usuario (correo institucional)" required>
            <Input
              type="email"
              autoComplete="username"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="usuario@epn.edu.ec"
              required
            />
          </Field>
          <Field label="Contraseña" required>
            <div className="relative">
              <Input
                type={ver ? 'text' : 'password'}
                autoComplete="current-password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
              />
              <button
                type="button"
                onClick={() => setVer((v) => !v)}
                className="absolute right-2 top-2 rounded p-1 text-slate-400 hover:text-navy"
                tabIndex={-1}
              >
                {ver ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
              </button>
            </div>
          </Field>

          <div className="flex items-center justify-between text-sm">
            <label className="flex items-center gap-2 text-ink-soft" title="Decorativo: recordar_sesion está deshabilitado a nivel de proyecto (01 §5)">
              <input type="checkbox" checked={recordar} onChange={(e) => setRecordar(e.target.checked)} className="h-4 w-4" />
              Recordar sesión
            </label>
            <span className="cursor-not-allowed text-slate-400" title="Flujo nativo de Supabase Auth (fuera de alcance de este prototipo)">
              ¿Olvidó su contraseña?
            </span>
          </div>

          <ErrorBanner message={error} />

          <Button type="submit" loading={cargando} className="w-full">
            Ingresar al sistema
          </Button>
        </form>
      </div>
    </div>
  )
}
