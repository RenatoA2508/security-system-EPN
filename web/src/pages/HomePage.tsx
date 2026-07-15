import { Link } from 'react-router-dom'
import { ArrowRight } from 'lucide-react'
import { useAuth } from '../auth/AuthProvider'
import { MODULOS, type ModuloDef } from '../resources/registry'
import { Card } from '../components/ui'

/** Home — grid de módulos filtrados por allowed_modules() y permisos (07 §2.3, regla §5.3). */
export function HomePage() {
  const { modulos, tiene } = useAuth()

  const visible = (m: ModuloDef): boolean => {
    if (m.codigo === 'MON') {
      // Monitoreo es un módulo de UI (no lo devuelve allowed_modules): visible solo a quien
      // supervisa eventos de acceso (CAC). ADMINISTRADOR_SISTEMA no lo ve (docs/Req_Front, eval ADM).
      return tiene('CAC_EVENTO_SELECT')
    }
    return modulos.includes(m.codigo)
  }

  const disponibles = MODULOS.filter(visible)

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-navy">Panel Principal</h1>
        <p className="mt-1 text-sm text-ink-soft">Selecciona un módulo para comenzar.</p>
      </div>

      {disponibles.length === 0 ? (
        <Card className="p-10 text-center text-ink-soft">
          Tu usuario no tiene módulos habilitados. Contacta al administrador del sistema.
        </Card>
      ) : (
        <div className="grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
          {disponibles.map((m) => (
            <Link key={m.codigo} to={`/m/${m.codigo}`}>
              <Card className="group h-full p-5 transition-shadow hover:shadow-lg">
                <div className="mb-3 flex h-12 w-12 items-center justify-center rounded-lg bg-navy/5 text-navy">
                  {m.icono}
                </div>
                <h2 className="text-base font-semibold text-navy">{m.titulo}</h2>
                <p className="mt-1 text-sm text-ink-soft">{m.descripcion}</p>
                <span className="mt-4 inline-flex items-center gap-1 text-sm font-medium text-navy group-hover:gap-2 transition-all">
                  Acceder al módulo <ArrowRight className="h-4 w-4" />
                </span>
              </Card>
            </Link>
          ))}
        </div>
      )}
    </div>
  )
}
