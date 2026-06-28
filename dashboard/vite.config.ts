import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const projectRoot = fileURLToPath(new URL('.', import.meta.url))

// https://vite.dev/config/
export default defineConfig({
  root: projectRoot,
  plugins: [vue()],
  build: {
    rolldownOptions: {
      input: {
        index: path.resolve(projectRoot, 'index.html'),
      },
    },
  },
})
