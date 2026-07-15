import { Link, Navigate, useParams } from 'react-router-dom'
import { ArrowRight } from 'lucide-react'
import { useAuth } from '../auth/AuthProvider'
import { moduloPorCodigo, type SubmoduloDef } from '../resources/registry'
import { Breadcrumb } from '../components/layout/Shell'
import { Card } from '../components/ui'

export function ModuleHome() {
  const { codigo = '' } = useParams()
  const { modulos, tiene, rolLabel } = useAuth()
  const modulo = moduloPorCodigo(codigo)

  if (!modulo) return <Navigate to="/" replace />
  const permitido = modulo.codigo === 'MON' ? tiene('CAC_EVENTO_SELECT') || tiene('ADM_PERSONA_SELECT') : modulos.includes(modulo.codigo)
  if (!permitido) return <Navigate to="/" replace />

  const puedeVer = (s: SubmoduloDef) => !s.permisoVer || s.permisoVer.some(tiene)
  const subs = modulo.submodulos.filter(puedeVer)

  return (
    <div>
      <Breadcrumb items={[{ label: 'Panel Principal', to: '/' }, { label: modulo.titulo }]} />
      <div className="mb-6">
        <h1 className="text-xl font-bold text-navy">{modulo.titulo}</h1>
        <p className="mt-0.5 text-sm text-ink-soft">
          {modulo.descripcion} <span className="text-slate-400">· Actúas como {rolLabel}</span>
        </p>
      </div>

      <div className="grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
        {subs.map((s) => (
          <Link key={s.key} to={`/m/${modulo.codigo}/${s.key}`}>
            <Card className="group h-full p-5 transition-shadow hover:shadow-lg">
              <div className="mb-3 flex h-11 w-11 items-center justify-center rounded-lg bg-navy/5 text-navy">{s.icono}</div>
              <h2 className="text-base font-semibold text-navy">{s.titulo}</h2>
              <p className="mt-1 text-sm text-ink-soft">{s.descripcion}</p>
              <span className="mt-4 inline-flex items-center gap-1 text-sm font-medium text-navy group-hover:gap-2 transition-all">
                Abrir <ArrowRight className="h-4 w-4" />
              </span>
            </Card>
          </Link>
        ))}
      </div>
    </div>
  )
}
