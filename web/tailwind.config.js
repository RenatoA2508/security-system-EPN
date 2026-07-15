/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        // Paleta institucional EPN (docs/07_DISENO_FRONTEND.md §1)
        navy: '#14284B',
        'navy-700': '#1d3763',
        red: '#B3262D',
        gold: '#D4AF37',
        beige: '#D8D1A7',
        'gray-bg': '#F5F7FA',
        'ink-soft': '#5a6a82',
      },
      boxShadow: {
        card: '0 1px 3px rgba(20,40,75,.08), 0 1px 2px rgba(20,40,75,.06)',
        panel: '-8px 0 24px rgba(20,40,75,.10)',
      },
      fontFamily: {
        sans: ['system-ui', '-apple-system', 'Segoe UI', 'Roboto', 'sans-serif'],
      },
    },
  },
  plugins: [],
}
