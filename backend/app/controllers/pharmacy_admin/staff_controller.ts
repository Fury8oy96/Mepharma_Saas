import { HttpContext } from '@adonisjs/core/http'
import User from '#models/tenant/user'
import bcrypt from 'bcryptjs'

export default class StaffController {
  private formatUser(user: User) {
    const json = user.toJSON()
    return {
      ...json,
      is_active: Boolean(user.isActive),
    }
  }

  async index({ response }: HttpContext) {
    const users = await User.query().orderBy('id', 'asc')
    return response.ok(users.map((u) => this.formatUser(u)))
  }

  async store({ request, response }: HttpContext) {
    const { username, password, role = 'pharmacist', is_active = true } = request.all()

    if (!username || !password) {
      return response.status(400).json({ error: 'Username and password are required.' })
    }

    const cleanUsername = String(username).trim().toLowerCase()
    const existing = await User.query().where('username', cleanUsername).first()
    if (existing) {
      return response.status(409).json({ error: `A staff user with username '${cleanUsername}' already exists.` })
    }

    // Role normalization
    let normalizedRole = role
    if (role === 'admin' || role === 'pharmacyadmin') normalizedRole = 'pharmacy_admin'
    if (role === 'super_admin') normalizedRole = 'supervisor'
    if (role === 'staff') normalizedRole = 'pharmacist'
    if (role === 'branchadmin' || role === 'branch_manager') normalizedRole = 'branch_admin'

    const hashedPassword = await bcrypt.hash(String(password).trim(), 10)
    const user = await User.create({
      username: cleanUsername,
      password: hashedPassword,
      role: normalizedRole as any,
      isActive: Boolean(is_active),
    })

    return response.status(201).json(this.formatUser(user))
  }

  async update({ params, request, response }: HttpContext) {
    const user = await User.query().where('id', params.id).first()
    if (!user) {
      return response.status(404).json({ error: 'User not found.' })
    }

    const { username, password, role, is_active } = request.all()

    // 1. Update username if provided and changed
    if (username && typeof username === 'string') {
      const cleanUsername = username.trim().toLowerCase()
      if (cleanUsername !== user.username) {
        const existing = await User.query()
          .where('username', cleanUsername)
          .whereNot('id', user.id)
          .first()
        if (existing) {
          return response.status(409).json({ error: `Username '${cleanUsername}' is already taken by another staff member.` })
        }
        user.username = cleanUsername
      }
    }

    // 2. Update password if non-empty
    if (password && typeof password === 'string' && password.trim().length > 0) {
      user.password = await bcrypt.hash(password.trim(), 10)
    }

    // 3. Update role if provided
    if (role) {
      let normalizedRole = role
      if (role === 'admin' || role === 'pharmacyadmin') normalizedRole = 'pharmacy_admin'
      if (role === 'super_admin') normalizedRole = 'supervisor'
      if (role === 'staff') normalizedRole = 'pharmacist'
      if (role === 'branchadmin' || role === 'branch_manager') normalizedRole = 'branch_admin'
      user.role = normalizedRole as any
    }

    // 4. Update status if provided
    if (is_active !== undefined) {
      user.isActive = Boolean(is_active)
    }

    await user.save()
    return response.ok(this.formatUser(user))
  }

  async destroy({ params, response }: HttpContext) {
    const user = await User.query().where('id', params.id).first()
    if (!user) {
      return response.status(404).json({ error: 'User not found.' })
    }
    // Prevent deleting the primary admin account
    if (user.id === 1 || user.username === 'admin') {
      return response.status(403).json({ error: 'Cannot delete the primary pharmacy administrator account.' })
    }
    await user.delete()
    return response.ok({ success: true, message: 'User deleted.' })
  }
}
