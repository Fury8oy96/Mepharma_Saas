import { defineConfig } from 'vite';
import { svelte, vitePreprocess } from '@sveltejs/vite-plugin-svelte';

export default defineConfig({
  plugins: [
    svelte({
      preprocess: vitePreprocess(),
    }),
  ],
  server: {
    port: 5173,
    proxy: {
      '/api': 'http://localhost:8000',
      '/sync': 'http://localhost:8000',
      '/auth': 'http://localhost:8000',
      '/products': 'http://localhost:8000',
      '/purchases': 'http://localhost:8000',
      '/sales': 'http://localhost:8000',
      '/users': 'http://localhost:8000',
      '/categories': 'http://localhost:8000',
      '/suppliers': 'http://localhost:8000',
      '/customers': 'http://localhost:8000',
      '/reports': 'http://localhost:8000',
      '/settings': 'http://localhost:8000',
    }
  }
});
