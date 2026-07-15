import { createClient } from '@supabase/supabase-js'
import type { Database } from './database.types'

const url = import.meta.env.VITE_SUPABASE_URL as string
const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY as string

if (!url || !anonKey) {
  throw new Error(
    'Faltan VITE_SUPABASE_URL / VITE_SUPABASE_ANON_KEY. Copia web/.env.example a web/.env.local.',
  )
}

// Un ÚNICO cliente, anon key pública (nunca service_role). docs/05_API_PARA_FRONTEND.md §1.
export const supabase = createClient<Database>(url, anonKey, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    // "recordar sesión" está deshabilitado a nivel de proyecto (01 §5); es decorativo en la UI.
    detectSessionInUrl: true,
  },
})

/**
 * Acceso a una tabla por nombre dinámico (motor genérico de recursos). El cliente tipado
 * exige un literal de tabla; aquí el nombre viene de la config, así que relajamos el tipo.
 */
export function fromTable(tabla: string) {
  return (supabase as any).from(tabla)
}

/** Traduce un error de PostgREST/Supabase a texto legible. Un 403/permiso se muestra tal cual (05 §2.6). */
export function mensajeError(error: unknown): string {
  if (!error) return 'Error desconocido.'
  const e = error as { message?: string; error_description?: string; hint?: string }
  return e.message || e.error_description || e.hint || String(error)
}
