import { defineConfig } from 'vitest/config'
import react from '@vitejs/plugin-react'
import path from 'node:path'

/**
 * Configuración de pruebas, separada de vite.config.ts para no cargar el plugin
 * de React ni el DOM al construir la aplicación.
 *
 * `environment: 'jsdom'` permite montar componentes y probar navegación y
 * formularios, que era el hueco de cobertura: los fallos de redirección y de
 * pérdida de estado al cambiar de pestaña solo se detectaban probando a mano.
 */
export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: { '@': path.resolve(__dirname, './src') },
  },
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: ['./src/test/setup.ts'],
    // Variables que lib/supabase.ts exige al importarse.
    env: {
      VITE_SUPABASE_URL: 'https://pruebas.supabase.co',
      VITE_SUPABASE_ANON_KEY: 'clave-anonima-de-pruebas',
    },
  },
})
