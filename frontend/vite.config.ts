import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import svgr from "vite-plugin-svgr";
import path from 'path'

export default defineConfig({
  plugins: [react(), svgr()],
  resolve: {
    alias: {
      '@cinezoo/shared': path.resolve(__dirname, '../shared/src'),
    },
  },
  css: {
    preprocessorOptions: {
      scss: {
        api: 'modern-compiler'
      }
    }
  },
  server: {
    watch: {
      usePolling: true,
    },
    proxy: {
      "/api": {
        target: "http://localhost:4000", // Rails API (backend/)
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/api/, "/api"),
      },
      "/uploads": {
        target: "http://localhost:4000",
        changeOrigin: true,
      },
      "/cable": {
        target: "http://localhost:4000",
        changeOrigin: true,
        ws: true,
      },
    },
  },
  assetsInclude: ["**/*.mp4"],
});
