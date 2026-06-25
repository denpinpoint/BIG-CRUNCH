import { defineConfig } from 'vite';

// CrazyGames requires relative paths only (never absolute) so the build can be
// hosted from any subdirectory inside the platform's iframe.
export default defineConfig({
  base: './',
  build: {
    target: 'es2020',
    assetsInlineLimit: 8192,
    cssCodeSplit: false,
    sourcemap: false,
    rollupOptions: {
      output: {
        // Single bundle keeps file count low (CrazyGames cap: 1500 files).
        manualChunks: undefined,
      },
    },
  },
  server: {
    host: true,
    port: 5173,
  },
});
