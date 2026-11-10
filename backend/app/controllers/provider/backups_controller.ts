import { HttpContext } from '@adonisjs/core/http'
import fs from 'node:fs'
import path from 'node:path'
import { exec } from 'node:child_process'
import { promisify } from 'node:util'
import { logAuditEvent } from './audit_logs_controller.js'

const execAsync = promisify(exec)
const BACKUP_DIR = path.resolve('backups')

export default class BackupsController {
  private ensureBackupDir() {
    if (!fs.existsSync(BACKUP_DIR)) {
      fs.mkdirSync(BACKUP_DIR, { recursive: true })
    }
  }

  async index({ response }: HttpContext) {
    this.ensureBackupDir()
    const files = fs.readdirSync(BACKUP_DIR)
      .filter((f) => f.endsWith('.sql') || f.endsWith('.sql.gz'))
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
    const targetPath = path.join(BACKUP_DIR, filename)

    const dbHost = process.env.DB_HOST || 'db'
    const dbUser = process.env.DB_USER || 'mepharma_user'
    const dbName = process.env.DB_DATABASE || 'mepharma'
    const dbPass = process.env.DB_PASSWORD || 'mepharma_password'

    try {
      // Execute pg_dump with PGPASSWORD
      const cmd = `PGPASSWORD="${dbPass}" pg_dump -h ${dbHost} -U ${dbUser} -d ${dbName} --clean --if-exists -f "${targetPath}"`
      await execAsync(cmd)

      const stats = fs.statSync(targetPath)
      const actor = authUser?.username || 'superadmin'
      await logAuditEvent(
        actor,
        'SYSTEM_BACKUP_CREATED',
        'BACKUP',
        filename,
        { sizeBytes: stats.size, targetPath },
        request.ip()
      )

      return response.status(201).json({
        success: true,
        filename,
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
    const filename = params.filename || request.input('filename')
    if (!filename) {
      return response.status(400).json({ error: 'Filename is required for restore.' })
    }

    // Security check: path traversal prevention
    const safeFilename = path.basename(filename)
    const filePath = path.join(BACKUP_DIR, safeFilename)

    if (!fs.existsSync(filePath)) {
      return response.status(404).json({ error: 'Backup file not found.' })
    }

    const dbHost = process.env.DB_HOST || 'db'
    const dbUser = process.env.DB_USER || 'mepharma_user'
    const dbName = process.env.DB_DATABASE || 'mepharma'
    const dbPass = process.env.DB_PASSWORD || 'mepharma_password'

    try {
      const cmd = `PGPASSWORD="${dbPass}" psql -h ${dbHost} -U ${dbUser} -d ${dbName} -f "${filePath}"`
      await execAsync(cmd)

      const actor = authUser?.username || 'superadmin'
      await logAuditEvent(
        actor,
        'SYSTEM_BACKUP_RESTORED',
        'BACKUP',
        safeFilename,
        { filePath },
        request.ip()
      )

      return response.ok({
        success: true,
        message: `Database successfully restored from ${safeFilename}.`,
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
    const safeFilename = path.basename(params.filename)
    const filePath = path.join(BACKUP_DIR, safeFilename)

    if (!fs.existsSync(filePath)) {
      return response.status(404).json({ error: 'Backup file not found.' })
    }

    return response.download(filePath)
  }
}
