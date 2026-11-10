#!/usr/bin/env node
import 'reflect-metadata'
import { register } from 'node:module'

try {
  register('@adonisjs/assembler/node_loader', import.meta.url)
} catch (_) {}

await import('./bin/console.js')
