import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

// // https://vite.dev/config/
// export default defineConfig({
//   plugins: [react()],
// })

export default {
  plugins: [
    tailwindcss(),
  ],

  server: {
    proxy: {
      '/api': 'http://127.0.0.1:8000'
    }
  }
}
