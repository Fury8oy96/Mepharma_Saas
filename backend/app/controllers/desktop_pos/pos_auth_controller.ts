import { HttpContext } from '@adonisjs/core/http'
import User from '#models/tenant/user'
import bcrypt from 'bcryptjs'
import jwt from 'jsonwebtoken'
import env from '#start/env'

export default class PosAuthController {
  private static failedSupervisorAttempts = new Map<string, { count: number; lockedUntil: number }>()

  async login({ request, response, tenant }: HttpContext) {
    const { username, password } = request.all()

    if (!username || !password) {
      return response.status(400).json({ error: 'Username and password required.' })
    }

    const cleanUsername = String(username).trim().toLowerCase()
    const user = await User.query()
      .where('username', cleanUsername)
      .first()

    if (!user) {
      return response.status(401).json({ error: 'Invalid cashier or staff credentials.' })
    }

    const valid = await bcrypt.compare(String(password).trim(), user.password)
    if (!valid) {
      return response.status(401).json({ error: 'Invalid cashier or staff credentials.' })
    }

    if (!user.isActive) {
      return response.status(403).json({
        error: 'Account Deactivated',
        code: 'ACCOUNT_DEACTIVATED',
        message: 'This staff account has been deactivated. Please contact your pharmacy administrator.',
      })
    }

    const secret = env.get('JWT_SECRET') || env.get('APP_KEY')
    const token = jwt.sign(
      {
        id: user.id,
        username: user.username,
        role: user.role,
        pharmacyId: tenant.id,
        pharmacyCode: tenant.code,
      },
      secret,
      { expiresIn: '30d' }
    )

    return response.ok({
      token,
      user: {
        id: user.id,
        username: user.username,
        role: user.role,
        is_active: user.isActive,
        created_at: user.createdAt.toISO(),
        pharmacyId: tenant.id,
        pharmacyCode: tenant.code,
      },
    })
  }

  async verifySupervisor({ request, response }: HttpContext) {
    const { username, password, pin } = request.all()
    const clientIp = request.ip() || 'unknown'
    const attemptKey = `${clientIp}:${String(username || 'all').toLowerCase()}`

    const now = Date.now()
    const record = PosAuthController.failedSupervisorAttempts.get(attemptKey)
    if (record && record.lockedUntil > now) {
      const remainingSeconds = Math.ceil((record.lockedUntil - now) / 1000)
      return response.status(429).json({
        authorized: false,
        error: `Too many failed supervisor attempts. Please wait ${remainingSeconds} seconds before trying again.`,
        retryAfter: remainingSeconds,
      })
    }

    if (!password && !pin) {
      return response.status(400).json({ error: 'Password or PIN required for authorization.' })
    }

    const query = User.query().where('is_active', true)
    if (username) {
      query.where('username', String(username).trim().toLowerCase())
    } else {
      query.whereIn('role', ['branch_admin', 'supervisor', 'pharmacy_admin'])
    }

    const users = await query

    for (const user of users) {
      if (user.role === 'branch_admin' || user.role === 'supervisor' || user.role === 'pharmacy_admin') {
        const passwordMatch = await bcrypt.compare(String(password || pin).trim(), user.password)
        if (passwordMatch) {
          PosAuthController.failedSupervisorAttempts.delete(attemptKey)
          const secret = env.get('JWT_SECRET') || env.get('APP_KEY')
          const supervisorToken = jwt.sign(
            {
              supervisorId: user.id,
              supervisorUsername: user.username,
              supervisorRole: user.role,
              action: 'supervisor_override',
            },
            secret,
            { expiresIn: '5m' }
          )

          return response.ok({
            authorized: true,
            supervisorToken,
            supervisor: {
              id: user.id,
              username: user.username,
              role: user.role,
            },
          })
        }
      }
    }

    const count = (record?.count || 0) + 1
    const lockedUntil = count >= 3 ? now + 5 * 60 * 1000 : 0
    PosAuthController.failedSupervisorAttempts.set(attemptKey, { count, lockedUntil })

    return response.status(403).json({
      authorized: false,
      error:
        count >= 3
          ? 'Too many failed supervisor attempts. Account locked for 5 minutes.'
          : `Invalid supervisor credentials or insufficient permissions. (${3 - count} attempts remaining)`,
    })
  }
}
