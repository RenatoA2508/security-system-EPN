import { createContext, useCallback, useContext, useEffect, useRef, useState } from 'react'
import type { ReactNode } from 'react'
import type { Session } from '@supabase/supabase-js'
import { supabase } from '../lib/supabase'

export type ModuloCodigo = 'ADM' | 'GPI' | 'GPE' | 'PCO' | 'CAC'

interface Perfil {
  id_usuario: string
  nombre_usuario: string
  correo_electronico: string
  requiere_cambio_password: boolean
  id_persona: string
  nombre_completo: string
}

interface AuthState {
  session: Session | null
  perfil: Perfil | null
  /** Best-effort: `usuario_rol` solo es legible por ADM/DIR (doc 02). Puede quedar vacío para el resto. */
  roles: string[]
  /** Etiqueta de rol para mostrar en UI, derivada de permisos/módulos — funciona para los 7 roles. */
  rolLabel: string
  permisos: Set<string>
  modulos: ModuloCodigo[]
  esGuardia: boolean
  cargando: boolean
  tiene: (codigo: string) => boolean
  refrescarPerfil: () => Promise<void>
  cerrarSesion: () => Promise<void>
}

/**
 * Deriva una etiqueta de rol legible SIN depender de `usuario_rol` (bloqueada por RLS para
 * todos los roles salvo ADM/DIR, doc 02 matriz ADM). Se basa en permisos efectivos + módulos
 * permitidos — nunca en el nombre de rol (05 §2.6). CAC_EVENTO_INSERT es exclusivo del guardia
 * (única fila con INSERT en evento_acceso fuera de DISP, doc 02 tabla CAC), verificado en vivo
 * contra las cuentas reales guardia.demo y carlos.chavez03 el 2026-07-14.
 */
function derivarRolLabel(permisos: Set<string>, modulos: ModuloCodigo[]): string {
  const tiene = (c: string) => permisos.has(c)
  if (tiene('CAC_EVENTO_INSERT')) return 'Guardia de Seguridad'
  if (modulos.includes('ADM')) return tiene('ADM_USUARIO_INSERT') ? 'Administrador del Sistema' : 'Director Administrativo'
  if (modulos.includes('GPI')) return 'Responsable de Personal Interno'
  if (modulos.includes('GPE')) return 'Responsable de Personal Externo'
  if (modulos.includes('PCO')) return 'Responsable de Puntos de Control'
  if (modulos.includes('CAC')) return 'Responsable de Control de Accesos'
  return '—'
}

const Ctx = createContext<AuthState | null>(null)

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null)
  const [perfil, setPerfil] = useState<Perfil | null>(null)
  const [roles, setRoles] = useState<string[]>([])
  const [permisos, setPermisos] = useState<Set<string>>(new Set())
  const [modulos, setModulos] = useState<ModuloCodigo[]>([])
  const [cargando, setCargando] = useState(true)
  const sesionRegistrada = useRef<string | null>(null)

  /** Carga permisos efectivos, módulos permitidos, roles y el perfil del usuario. */
  const cargarContexto = useCallback(async (uid: string) => {
    const [permRes, modRes, perfilRes, rolesRes] = await Promise.all([
      supabase.rpc('permisos_efectivos'),
      supabase.rpc('allowed_modules'),
      supabase
        .from('usuario_sistema')
        .select('id_usuario, nombre_usuario, correo_electronico, requiere_cambio_password, id_persona, persona:persona!usuario_sistema_id_persona_fkey(nombres, apellidos)')
        .eq('id_usuario', uid)
        .maybeSingle(),
      supabase
        .from('usuario_rol')
        .select('rol:rol(nombre_rol)')
        .eq('id_usuario', uid)
        .eq('estado_asignacion', 'ACTIVO'),
    ])

    setPermisos(new Set((permRes.data as string[] | null) ?? []))
    setModulos(((modRes.data as string[] | null) ?? []) as ModuloCodigo[])

    const p = perfilRes.data as
      | { id_usuario: string; nombre_usuario: string; correo_electronico: string; requiere_cambio_password: boolean; id_persona: string; persona: { nombres: string; apellidos: string } | null }
      | null
    if (p) {
      setPerfil({
        id_usuario: p.id_usuario,
        nombre_usuario: p.nombre_usuario,
        correo_electronico: p.correo_electronico,
        requiere_cambio_password: p.requiere_cambio_password,
        id_persona: p.id_persona,
        nombre_completo: p.persona ? `${p.persona.nombres} ${p.persona.apellidos}` : p.nombre_usuario,
      })
    }
    const rr = (rolesRes.data as { rol: { nombre_rol: string } | null }[] | null) ?? []
    setRoles(rr.map((r) => r.rol?.nombre_rol).filter(Boolean) as string[])
  }, [])

  const refrescarPerfil = useCallback(async () => {
    if (session?.user.id) await cargarContexto(session.user.id)
  }, [session, cargarContexto])

  const cerrarSesion = useCallback(async () => {
    await supabase.auth.signOut()
  }, [])

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      setSession(data.session)
      if (!data.session) setCargando(false)
    })

    // Reaccionar a SIGNED_OUT y a la expiración de sesión de Supabase (01 §5, 05 §2.4).
    const { data: sub } = supabase.auth.onAuthStateChange((event, sess) => {
      setSession(sess)
      if (event === 'SIGNED_OUT' || !sess) {
        setPerfil(null)
        setRoles([])
        setPermisos(new Set())
        setModulos([])
        sesionRegistrada.current = null
        setCargando(false)
      }
    })
    return () => sub.subscription.unsubscribe()
  }, [])

  useEffect(() => {
    if (!session?.user.id) return
    let vivo = true
    setCargando(true)
    ;(async () => {
      await cargarContexto(session.user.id)
      // Registrar la fila de auditoría en `sesion` una sola vez por sesión (05 §2.2). No bloquea.
      if (sesionRegistrada.current !== session.user.id) {
        sesionRegistrada.current = session.user.id
        supabase.rpc('registrar_sesion', { p_recordar_sesion: false }).then(({ error }) => {
          if (error) console.warn('registrar_sesion:', error.message)
        })
      }
      if (vivo) setCargando(false)
    })()
    return () => {
      vivo = false
    }
  }, [session, cargarContexto])

  const tiene = useCallback((codigo: string) => permisos.has(codigo), [permisos])
  const esGuardia = permisos.has('CAC_EVENTO_INSERT')
  const rolLabel = roles[0]?.replaceAll('_', ' ').replace(/^\w/, (c) => c.toUpperCase()) || derivarRolLabel(permisos, modulos)

  return (
    <Ctx.Provider
      value={{
        session, perfil, roles, rolLabel, permisos, modulos, esGuardia, cargando,
        tiene, refrescarPerfil, cerrarSesion,
      }}
    >
      {children}
    </Ctx.Provider>
  )
}

export function useAuth(): AuthState {
  const ctx = useContext(Ctx)
  if (!ctx) throw new Error('useAuth debe usarse dentro de <AuthProvider>')
  return ctx
}
