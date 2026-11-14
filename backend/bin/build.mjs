import { spawnSync } from 'node:child_process'
import { cpSync, existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const __dirname = dirname(fileURLToPath(import.meta.url))
const rootDir = join(__dirname, '..')
const buildDir = join(rootDir, 'build')
const tscBin = join(rootDir, 'node_modules', 'typescript', 'bin', 'tsc')

rmSync(buildDir, { recursive: true, force: true })

const tsc = spawnSync(process.execPath, [tscBin], {
  cwd: rootDir,
  stdio: 'inherit',
})

if (tsc.status !== 0) {
  process.exit(tsc.status ?? 1)
}

mkdirSync(buildDir, { recursive: true })

for (const dir of ['public']) {
  const src = join(rootDir, dir)
  if (existsSync(src)) {
    cpSync(src, join(buildDir, dir), { recursive: true })
  }
}

for (const file of ['package-lock.json', '.env.example', 'docker-entrypoint.sh']) {
  const src = join(rootDir, file)
  if (existsSync(src)) {
    cpSync(src, join(buildDir, file))
  }
}

const pkg = JSON.parse(readFileSync(join(rootDir, 'package.json'), 'utf8'))
if (pkg.scripts) {
  pkg.scripts.start = 'node bin/server.js'
}
writeFileSync(join(buildDir, 'package.json'), JSON.stringify(pkg, null, 2) + '\n', 'utf8')

writeFileSync(
  join(buildDir, 'ace.js'),
  "#!/usr/bin/env node\nimport 'reflect-metadata'\nawait import('./bin/console.js')\n",
  'utf8',
)

console.log('Backend build completed cleanly -> build/')

