import { forwardRef, useEffect, useImperativeHandle, useRef, useState } from 'react'
import { Camera as CamIcon, VideoOff } from 'lucide-react'
import { cargarModelos, capturarJpeg, descriptorDesdeVideo } from '../lib/faceapi'
import { mensajeDeErrorDeCamara } from '../lib/errores-camara'
import { Button, Spinner } from './ui'

export interface CameraHandle {
  /** Descriptor 128-d del rostro actual. */
  descriptor: () => Promise<number[]>
  /** JPEG del fotograma actual. */
  jpeg: () => Promise<Blob>
}

/**
 * Panel de cámara con face-api.js. getUserMedia requiere https o localhost.
 * Solo se usa para personal INTERNO (§D20): enrolamiento (GPI) e identificación (guardia).
 */
export const CameraPanel = forwardRef<CameraHandle, { className?: string }>(function CameraPanel(
  { className },
  ref,
) {
  const videoRef = useRef<HTMLVideoElement>(null)
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const [activa, setActiva] = useState(false)
  const [cargando, setCargando] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [detalleTecnico, setDetalleTecnico] = useState<string | null>(null)

  useImperativeHandle(ref, () => ({
    descriptor: () => descriptorDesdeVideo(videoRef.current!),
    jpeg: () => capturarJpeg(videoRef.current!, canvasRef.current!),
  }))

  const encender = async () => {
    setError(null)
    setCargando(true)
    try {
      await cargarModelos()
      const stream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: 'user' } })
      if (videoRef.current) videoRef.current.srcObject = stream
      setActiva(true)
    } catch (e) {
      setError(mensajeDeErrorDeCamara(e as Error, 'Mientras tanto, puedes identificar a la persona escribiendo su cédula.'))
      setDetalleTecnico((e as Error).message)
    } finally {
      setCargando(false)
    }
  }

  useEffect(() => {
    return () => {
      const s = videoRef.current?.srcObject as MediaStream | null
      s?.getTracks().forEach((t) => t.stop())
    }
  }, [])

  return (
    <div className={className}>
      <div className="relative overflow-hidden rounded-lg border border-slate-300 bg-slate-900" style={{ aspectRatio: '4/3' }}>
        <video ref={videoRef} autoPlay muted playsInline className="h-full w-full object-cover" />
        {!activa && (
          <div className="absolute inset-0 flex flex-col items-center justify-center gap-2 text-white/70">
            {cargando ? <Spinner className="text-white" /> : <VideoOff className="h-8 w-8" />}
            <span className="text-xs">{cargando ? 'Cargando modelos...' : 'Cámara apagada'}</span>
          </div>
        )}
      </div>
      <canvas ref={canvasRef} width={320} height={240} className="hidden" />
      {!activa && (
        <Button variant="secondary" onClick={encender} loading={cargando} className="mt-2 w-full">
          <CamIcon className="h-4 w-4" /> Activar cámara
        </Button>
      )}
      {error && (
        // El detalle técnico no se pierde —hace falta para depurar—, pero va en el
        // title y no en la cara del guardia.
        <p className="mt-2 text-xs text-red" title={detalleTecnico ?? undefined}>{error}</p>
      )}
    </div>
  )
})
