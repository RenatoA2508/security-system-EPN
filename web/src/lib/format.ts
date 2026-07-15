/** Formateo de fechas/horas para la UI (locale es-EC). */

export function fmtFecha(v?: string | null): string {
  if (!v) return '—'
  const d = new Date(v)
  if (Number.isNaN(d.getTime())) return v
  return d.toLocaleDateString('es-EC', { year: 'numeric', month: '2-digit', day: '2-digit' })
}

export function fmtFechaHora(v?: string | null): string {
  if (!v) return '—'
  const d = new Date(v)
  if (Number.isNaN(d.getTime())) return v
  return d.toLocaleString('es-EC', {
    year: 'numeric', month: '2-digit', day: '2-digit',
    hour: '2-digit', minute: '2-digit',
  })
}

/** Recorta una hora "HH:MM:SS" a "HH:MM". */
export function fmtHora(v?: string | null): string {
  if (!v) return '—'
  return v.slice(0, 5)
}

export function iniciales(nombres?: string | null, apellidos?: string | null): string {
  const a = (nombres || '').trim().charAt(0)
  const b = (apellidos || '').trim().charAt(0)
  return (a + b).toUpperCase() || '?'
}

/** Fecha de hoy en formato YYYY-MM-DD (para inputs date / autorizaciones). */
export function hoyISO(): string {
  return new Date().toISOString().slice(0, 10)
}
