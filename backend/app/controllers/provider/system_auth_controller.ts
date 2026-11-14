import { HttpContext } from '@adonisjs/core/http'
import SystemUser from '#models/core/system_user'
import bcrypt from 'bcryptjs'
import jwt from 'jsonwebtoken'
import { getJwtSecret } from '#core/security/jwt_secret'

export default class SystemAuthController {
  async login({ request, response }: HttpContext) {
    const { username, password } = request.all()

    if (!username || !password) {
      return response.status(400).json({ error: 'Username and password required.' })
    }

    const user = await SystemUser.query()
      .where('username', String(username).trim().toLowerCase())
      .where('is_active', true)
      .first()

    if (!user) {
      return response.status(401).json({ error: 'Invalid provider administrator credentials.' })
    }

    const valid = await bcrypt.compare(String(password).trim(), user.password)
    if (!valid) {
      return response.status(401).json({ error: 'Invalid provider administrator credentials.' })
    }

    const token = jwt.sign(
      {
        id: user.id,
        username: user.username,
        email: user.email,
        role: user.role,
        isProviderAdmin: true,
      },
      getJwtSecret(),
      { expiresIn: '7d' }
    )

    return response.ok({
      token,
      user: {
        id: user.id,
        username: user.username,
        email: user.email,
        role: user.role,
      },
    })
  }
}
