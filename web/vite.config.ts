import path from 'node:path'
import { defineConfig } from 'vitest/config'
import preact from '@preact/preset-vite'
import { VitePWA } from 'vite-plugin-pwa'
import { fidelContent } from './plugins/content'

// GitHub Pages serves a project site from /<repo>/; CI sets FIDEL_BASE=/fidel/.
const base = process.env.FIDEL_BASE ?? '/'

export default defineConfig({
  base,
  server: { fs: { allow: [path.resolve(__dirname, '..')] } },
  plugins: [
    preact(),
    fidelContent(),
    VitePWA({
      registerType: 'autoUpdate',
      injectRegister: false,
      includeAssets: ['icon.svg', 'apple-touch-icon.png'],
      manifest: {
        name: 'Fidel — Learn Amharic',
        short_name: 'Fidel',
        description: 'Learn the Amharic script, words and phrases. Works offline.',
        start_url: `${base}app/`,
        scope: base,
        display: 'standalone',
        background_color: '#F6F0E4',
        theme_color: '#B55130',
        lang: 'en',
        icons: [
          { src: 'icon-192.png', sizes: '192x192', type: 'image/png' },
          { src: 'icon-512.png', sizes: '512x512', type: 'image/png' },
          { src: 'icon-512.png', sizes: '512x512', type: 'image/png', purpose: 'maskable' },
        ],
      },
      workbox: {
        globPatterns: ['**/*.{js,css,html,json,woff2,svg,png,webmanifest}'],
        globIgnores: ['strokes/**', 'audio/**', 'screenshots/**'],
        maximumFileSizeToCacheInBytes: 3 * 1024 * 1024,
        navigateFallback: null,
        runtimeCaching: [
          {
            urlPattern: ({ url }) => url.pathname.includes('/audio/'),
            handler: 'CacheFirst',
            options: { cacheName: 'fidel-audio', rangeRequests: true, expiration: { maxEntries: 4000 } },
          },
          {
            urlPattern: ({ url }) => url.pathname.includes('/strokes/') || url.pathname.includes('/screenshots/'),
            handler: 'CacheFirst',
            options: { cacheName: 'fidel-assets', expiration: { maxEntries: 600 } },
          },
        ],
      },
    }),
  ],
  build: {
    target: 'es2022',
    rollupOptions: {
      input: {
        landing: path.resolve(__dirname, 'index.html'),
        app: path.resolve(__dirname, 'app/index.html'),
      },
    },
  },
  test: {
    environment: 'node',
    include: ['src/**/*.test.ts', 'tests/unit/**/*.test.ts'],
  },
})
