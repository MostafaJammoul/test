import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    port: 3000,
    proxy: {
      '/api': {
        target: 'https://192.168.148.154',
        changeOrigin: true,
        secure: false, // Accept self-signed certificates
      }
    }
  },
  build: {
    outDir: '../apps/static/frontend',
    emptyOutDir: true,
  }
})
