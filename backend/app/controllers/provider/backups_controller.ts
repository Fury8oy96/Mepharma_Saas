import { HttpContext } from '@adonisjs/core/http'
import fs from 'node:fs'
import path from 'node:path'
import { execFile } from 'node:child_process'
import { promisify } from 'node:util'
import { logAuditEvent } from './audit_logs_controller.js'

const execFileAsync = promisify(execFile)
const BACKUP_DIR = path.resolve('backups')
const SAFE_BACKUP_FILENAME = /^mepharma_[a-zA-Z0-9._-]+\.sql(\.gz)?$/

export default class BackupsController {
  private ensureBackupDir() {
    if (!fs.existsSync(BACKUP_DIR)) {
      fs.mkdirSync(BACKUP_DIR, { recursive: true })
    }
  }

  private resolveSafeBackupPath(filename: unknown): { safeName: string; fullPath: string } | null {
    if (typeof filename !== 'string' || !filename.trim()) {
      return null
    }
    const base = path.basename(filename.trim())
    if (!SAFE_BACKUP_FILENAME.test(base) || base.includes('..')) {
      return null
    }
    const fullPath = path.resolve(BACKUP_DIR, base)
    if (!fullPath.startsWith(BACKUP_DIR + path.sep)) {
      return null
    }
    return { safeName: base, fullPath }
  }

  async index({ response }: HttpContext) {
    this.ensureBackupDir()
    const files = fs.readdirSync(BACKUP_DIR)
      .filter((f) => SAFE_BACKUP_FILENAME.test(f))
      .map((f) => {
        const filePath = path.join(BACKUP_DIR, f)
        const stats = fs.statSync(filePath)
        return {
          filename: f,
          sizeBytes: stats.size,
          sizeMb: Math.round((stats.size / (1024 * 1024)) * 100) / 100,
          createdAt: stats.mtime.toISOString(),
        }
      })
      .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime())

    return response.ok(files)
  }

  async create({ request, response, authUser }: HttpContext) {
    this.ensureBackupDir()
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-')
    const filename = `mepharma_full_backup_${timestamp}.sql`
    const resolved = this.resolveSafeBackupPath(filename)
    if (!resolved) {
      return response.status(400).json({ error: 'Invalid backup filename generated.' })
    }

    const dbHost = process.env.DB_HOST || 'db'
    const dbPort = String(process.env.DB_PORT || '5432')
    const dbUser = process.env.DB_USER || 'mepharma_user'
    const dbName = process.env.DB_DATABASE || 'mepharma'
    const dbPass = process.env.DB_PASSWORD || 'mepharma_password'

    try {
      await execFileAsync(
        'pg_dump',
        ['-h', dbHost, '-p', dbPort, '-U', dbUser, '-d', dbName, '--clean', '--if-exists', '-f', resolved.fullPath],
        { env: { ...process.env, PGPASSWORD: dbPass }, maxBuffer: 64 * 1024 * 1024 }
      )

      const stats = fs.statSync(resolved.fullPath)
      const actor = authUser?.username || 'superadmin'
      await logAuditEvent(
        actor,
        'SYSTEM_BACKUP_CREATED',
        'BACKUP',
        resolved.safeName,
        { sizeBytes: stats.size, targetPath: resolved.fullPath },
        request.ip()
      )

      return response.status(201).json({
        success: true,
        filename: resolved.safeName,
        sizeMb: Math.round((stats.size / (1024 * 1024)) * 100) / 100,
        createdAt: stats.mtime.toISOString(),
      })
    } catch (err: any) {
      console.error('pg_dump error:', err)
      return response.status(500).json({
        error: 'Backup Generation Failed',
        message: err.message || 'Unable to execute database snapshot.',
      })
    }
  }

  async restore({ request, params, response, authUser }: HttpContext) {
    this.ensureBackupDir()
    const rawFilename = params.filename || request.input('filename')
    const resolved = this.resolveSafeBackupPath(rawFilename)
    if (!resolved) {
      return response.status(400).json({ error: 'Invalid or unsafe backup filename.' })
    }

    if (!fs.existsSync(resolved.fullPath)) {
      return response.status(404).json({ error: 'Backup file not found.' })
    }

    const dbHost = process.env.DB_HOST || 'db'
    const dbPort = String(process.env.DB_PORT || '5432')
    const dbUser = process.env.DB_USER || 'mepharma_user'
    const dbName = process.env.DB_DATABASE || 'mepharma'
    const dbPass = process.env.DB_PASSWORD || 'mepharma_password'

    try {
      await execFileAsync(
        'psql',
        ['-h', dbHost, '-p', dbPort, '-U', dbUser, '-d', dbName, '-v', 'ON_ERROR_STOP=1', '-f', resolved.fullPath],
        { env: { ...process.env, PGPASSWORD: dbPass }, maxBuffer: 64 * 1024 * 1024 }
      )

      const actor = authUser?.username || 'superadmin'
      await logAuditEvent(
        actor,
        'SYSTEM_BACKUP_RESTORED',
        'BACKUP',
        resolved.safeName,
        { filePath: resolved.fullPath },
        request.ip()
      )

      return response.ok({
        success: true,
        message: `Database successfully restored from ${resolved.safeName}.`,
      })
    } catch (err: any) {
      console.error('psql restore error:', err)
      return response.status(500).json({
        error: 'Database Restore Failed',
        message: err.message || 'Error occurred while applying snapshot.',
      })
    }
  }

  async download({ params, response }: HttpContext) {
    this.ensureBackupDir()
    const resolved = this.resolveSafeBackupPath(params.filename)
    if (!resolved) {
      return response.status(400).json({ error: 'Invalid backup filename.' })
    }

    if (!fs.existsSync(resolved.fullPath)) {
      return response.status(404).json({ error: 'Backup file not found.' })
    }

    return response.download(resolved.fullPath)
  }
}
