import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const projectRoot = fileURLToPath(new URL('.', import.meta.url))

// https://vite.dev/config/
export default defineConfig({
  root: projectRoot,
  plugins: [react()],
  build: {
    rolldownOptions: {
      input: {
        index: path.resolve(projectRoot, 'index.html'),
      },
    },
  },
})
