import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    host: '0.0.0.0', // Listen on all network interfaces
    port: 3000,
    proxy: {
      '/api': {
        target: 'http://127.0.0.1:8080', // Proxy to local Django backend
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
