import { HttpContext } from '@adonisjs/core/http'
import User from '#models/tenant/user'
import bcrypt from 'bcryptjs'
import jwt from 'jsonwebtoken'
import env from '#start/env'

export default class AdminAuthController {
  async login({ request, response, tenant }: HttpContext) {
    const { username, password } = request.all()

    if (!username || !password) {
      return response.status(400).json({ error: 'Username and password are required.' })
    }

    const user = await User.query()
      .where('username', username.toLowerCase())
      .where('is_active', true)
      .first()

    if (!user) {
      return response.status(401).json({ error: 'Invalid pharmacy username or password.' })
    }

    const valid = await bcrypt.compare(password, user.password)
    if (!valid) {
      return response.status(401).json({ error: 'Invalid pharmacy username or password.' })
    }

    // STRICT ROLE GATEKEEPING:
    // If the account is a Branch Admin, Pharmacist, Supervisor, or Cashier, BLOCK login from the Web Dashboard.
    const role = (user.role || '').toLowerCase()
    if (role === 'branch_admin' || role === 'pharmacist' || role === 'supervisor' || role === 'cashier' || role === 'staff') {
      return response.status(403).json({
        error: 'Access Denied',
        code: 'DESKTOP_CLIENT_REQUIRED',
        message:
          'Branch Administrators, Pharmacists, and Cashiers must use the MePharma Desktop Application. Web dashboard access is reserved exclusively for the Pharmacy Owner / Administrator.',
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
      { expiresIn: '24h' }
    )

    return response.ok({
      token,
      user: {
        id: user.id,
        username: user.username,
        role: user.role,
        pharmacyCode: tenant.code,
      },
    })
  }

  async me({ response, authUser, tenant }: HttpContext) {
    if (!authUser) {
      return response.status(401).json({ error: 'Unauthorized.' })
    }

    const user = await User.query().where('id', authUser.id).first()
    if (!user) {
      return response.status(404).json({ error: 'User not found.' })
    }
    return response.ok({
      id: user.id,
      username: user.username,
      role: user.role,
      pharmacyCode: tenant.code,
    })
  }

  async info({ response, tenant }: HttpContext) {
    if (!tenant) {
      return response.status(404).json({ error: 'Pharmacy branch not found in registry.' })
    }
    return response.ok({
      id: tenant.id,
      code: tenant.code,
      name: tenant.name,
      status: tenant.status,
      plan: tenant.plan,
      maxTerminals: tenant.maxTerminals,
    })
  }
}
