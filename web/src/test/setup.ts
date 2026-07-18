import '@testing-library/jest-dom/vitest'
import { afterEach, vi } from 'vitest'
import { cleanup } from '@testing-library/react'

// Desmonta lo renderizado entre pruebas para que no se filtre estado de una a otra.
afterEach(() => {
  cleanup()
  localStorage.clear()
  sessionStorage.clear()
  vi.clearAllMocks()
})
