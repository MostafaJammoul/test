import { defineConfig, loadEnv } from 'vite'
import react from '@vitejs/plugin-react'

// https://vitejs.dev/config/
export default defineConfig(({ mode }) => {
  // Load environment variables
  const env = loadEnv(mode, process.cwd(), '')
  const backendUrl = env.VITE_BACKEND_URL || 'http://127.0.0.1:8080'

  return {
    plugins: [react()],
    server: {
      host: '0.0.0.0', // Listen on all network interfaces
      port: 3000,
      proxy: {
        '/api': {
          target: backendUrl, // Use environment variable
          changeOrigin: true,
          secure: false, // Accept self-signed certificates in development
        }
      }
    },
    build: {
      outDir: '../apps/static/frontend',
      emptyOutDir: true,
    }
  }
})
