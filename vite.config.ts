import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react(), {
    name: 'brand-entry-routes',
    configureServer(server) {
      server.middlewares.use((req, _res, next) => {
        const request = req as typeof req & { url?: string }
        const path = request.url?.split('?')[0].replace(/\/+$/, '') || '/'
        if (['/development','/games','/entertainment'].includes(path)) request.url='/index.html'
        // Public game exports use directory URLs in production. Resolve their
        // default document in development too, including links inside games.
        else if (/^\/games\/[A-Za-z0-9_/-]+$/.test(path) && request.url?.split('?')[0].endsWith('/')) {
          const query = request.url?.includes('?') ? request.url.slice(request.url.indexOf('?')) : ''
          request.url = path + '/index.html' + query
        }
        next()
      })
    },
  }],
  server: {
    allowedHosts: ['terminal.local'],
    port: 4188,
    strictPort: false,
    proxy: {
      '/skillcred-api': {
        target: 'https://skillcred-pilot-api.onrender.com',
        changeOrigin: true,
        secure: true,
        rewrite: (path) => path.replace(/^\/skillcred-api/, ''),
      },
    },
  },
  build: {
    manifest: true,
    rollupOptions: {
      output: {
        manualChunks(id) {
          if (id.includes('/node_modules/three/')) return 'three'
          if (id.includes('/node_modules/react/') || id.includes('/node_modules/react-dom/')) return 'react'
        },
      },
    },
  },
})
