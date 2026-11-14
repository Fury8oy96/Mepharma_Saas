import { HttpContext } from '@adonisjs/core/http'
import User from '#models/tenant/user'
import bcrypt from 'bcryptjs'
import jwt from 'jsonwebtoken'
import { getJwtSecret } from '#core/security/jwt_secret'

export default class PosAuthController {
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

    const token = jwt.sign(
      {
        id: user.id,
        username: user.username,
        role: user.role,
        pharmacyId: tenant.id,
        pharmacyCode: tenant.code,
      },
      getJwtSecret(),
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
    const secretInput = password || pin

    if (!secretInput) {
      return response.status(400).json({ error: 'Password or PIN required for authorization.' })
    }

    const supervisorRoles = ['admin', 'super_admin', 'branch_admin', 'supervisor', 'pharmacy_admin']
    const query = User.query().where('is_active', true)
    if (username) {
      query.where('username', String(username).trim().toLowerCase())
    } else {
      query.whereIn('role', supervisorRoles)
    }

    const users = await query

    for (const user of users) {
      if (supervisorRoles.includes(String(user.role || '').toLowerCase())) {
        const passwordMatch = await bcrypt.compare(String(secretInput).trim(), user.password)
        if (passwordMatch) {
          return response.ok({
            authorized: true,
            supervisor: {
              id: user.id,
              username: user.username,
              role: user.role,
            },
          })
        }
      }
    }

    return response.status(403).json({
      authorized: false,
      error: 'Invalid supervisor credentials or insufficient permissions.',
    })
  }
}
