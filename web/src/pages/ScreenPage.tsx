import { Navigate, useParams } from 'react-router-dom'
import { useAuth } from '../auth/AuthProvider'
import { moduloPorCodigo } from '../resources/registry'
import { Breadcrumb } from '../components/layout/Shell'

/** Renderiza el submódulo (pantalla de recurso o pantalla custom) con su breadcrumb. */
export function ScreenPage() {
  const { codigo = '', sub = '' } = useParams()
  const { modulos, tiene } = useAuth()
  const modulo = moduloPorCodigo(codigo)
  const submodulo = modulo?.submodulos.find((s) => s.key === sub)

  if (!modulo || !submodulo) return <Navigate to="/" replace />
  const permitidoModulo = modulo.codigo === 'MON' ? tiene('CAC_EVENTO_SELECT') || tiene('ADM_PERSONA_SELECT') : modulos.includes(modulo.codigo)
  if (!permitidoModulo) return <Navigate to="/" replace />

  return (
    <div>
      <Breadcrumb
        items={[
          { label: 'Panel Principal', to: '/' },
          { label: modulo.titulo, to: `/m/${modulo.codigo}` },
          { label: submodulo.titulo },
        ]}
      />
      <h1 className="mb-4 text-xl font-bold text-navy">{submodulo.titulo}</h1>
      {submodulo.render()}
    </div>
  )
}
