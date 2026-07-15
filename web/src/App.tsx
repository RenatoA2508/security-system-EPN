import { Link, Navigate, Route, Routes } from 'react-router-dom'
import { KeyRound, X } from 'lucide-react'
import { useState } from 'react'
import { useAuth } from './auth/AuthProvider'
import { CenterSpinner, ToastProvider } from './components/ui'
import { TopBar, PageContainer } from './components/layout/Shell'
import { LoginPage } from './pages/LoginPage'
import { HomePage } from './pages/HomePage'
import { ModuleHome } from './pages/ModuleHome'
import { ScreenPage } from './pages/ScreenPage'
import { CuentaPage } from './pages/CuentaPage'
import { GuardiaView } from './pages/GuardiaView'

/** Aviso suave de cambio de contraseña en el primer login (no bloquea; decisión de la sesión). */
function BannerPassword() {
  const { perfil } = useAuth()
  const [oculto, setOculto] = useState(false)
  if (!perfil?.requiere_cambio_password || oculto) return null
  return (
    <div className="border-b border-amber-200 bg-amber-50 px-4 py-2 text-sm text-amber-800">
      <div className="mx-auto flex max-w-6xl items-center justify-between gap-3">
        <span className="flex items-center gap-2">
          <KeyRound className="h-4 w-4" /> Debes cambiar tu contraseña de arranque.
          <Link to="/cuenta" className="font-semibold underline">Cambiar ahora</Link>
        </span>
        <button onClick={() => setOculto(true)} className="rounded p-1 hover:bg-amber-100"><X className="h-4 w-4" /></button>
      </div>
    </div>
  )
}

export default function App() {
  const { session, cargando, esGuardia } = useAuth()

  if (cargando) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-gray-bg">
        <CenterSpinner label="Cargando sesión..." />
      </div>
    )
  }

  if (!session) return <LoginPage />

  return (
    <ToastProvider>
      {esGuardia ? (
        // Vista operativa del guardia: reemplaza el grid de módulos (07 §5).
        <GuardiaView />
      ) : (
        <div className="min-h-screen">
          <TopBar />
          <BannerPassword />
          <PageContainer>
            <Routes>
              <Route path="/" element={<HomePage />} />
              <Route path="/cuenta" element={<CuentaPage />} />
              <Route path="/m/:codigo" element={<ModuleHome />} />
              <Route path="/m/:codigo/:sub" element={<ScreenPage />} />
              <Route path="*" element={<Navigate to="/" replace />} />
            </Routes>
          </PageContainer>
        </div>
      )}
    </ToastProvider>
  )
}
