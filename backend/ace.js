#!/usr/bin/env node
import 'reflect-metadata'
import { existsSync } from 'node:fs'

const compiledConsole = new URL('./bin/console.js', import.meta.url)
const builtConsole = new URL('./build/bin/console.js', import.meta.url)

if (existsSync(compiledConsole)) {
  await import('./bin/console.js')
} else if (existsSync(builtConsole)) {
  await import('./build/bin/console.js')
} else {
  console.error('Compiled AdonisJS console entrypoint not found. Run "npm run build" first.')
  process.exit(1)
}
