import { HttpContext } from '@adonisjs/core/http'
import User from '#models/tenant/user'
import bcrypt from 'bcryptjs'
import { TenantContext } from '#core/tenancy/tenant_context'
import { syncHub } from '#core/events/sync_hub'

export default class StaffController {
  private formatUser(user: User) {
    const json = user.toJSON()
    return {
      ...json,
      is_active: Boolean(user.isActive),
      created_at: user.createdAt?.toISO?.() || null,
      updated_at: user.updatedAt?.toISO?.() || null,
    }
  }

  private ensureUserAdmin(authUser: any, response: HttpContext['response']) {
    const role = String(authUser?.role || '').toLowerCase()
    if (!['pharmacy_admin', 'admin', 'branch_admin', 'super_admin'].includes(role)) {
      response.status(403).json({
        error: 'Access Forbidden',
        message: 'Only administrators may create, modify, or delete staff accounts.',
      })
      return false
    }
    return true
  }

  async index({ response }: HttpContext) {
    const users = await User.query().orderBy('id', 'asc')
    return response.ok(users.map((u) => this.formatUser(u)))
  }

  async show({ params, response }: HttpContext) {
    const user = await User.query().where('id', params.id).first()
    if (!user) {
      return response.status(404).json({ error: 'User not found.' })
    }
    return response.ok(this.formatUser(user))
  }

  async findByUsername({ params, response }: HttpContext) {
    const clean = String(params.username || '').trim().toLowerCase()
    const user = await User.query().where('username', clean).first()
    if (!user) {
      return response.status(404).json({ error: 'User not found.' })
    }
    return response.ok(this.formatUser(user))
  }

  async count({ response }: HttpContext) {
    const res = await User.query().count('* as count')
    const count = Number(res[0]?.$extras?.count) || 0
    return response.ok({ count })
  }

  async ensureDefaultAdmin({ response, authUser }: HttpContext & { authUser?: any }) {
    if (authUser && !this.ensureUserAdmin(authUser, response)) return
    const existing = await User.query().where('username', 'admin').first()
    if (existing) {
      return response.ok({ created: false, user: this.formatUser(existing) })
    }
    const password = await bcrypt.hash('admin123', 10)
    const created = await User.create({
      username: 'admin',
      password,
      role: 'pharmacy_admin',
      isActive: true,
    })
    return response.status(201).json({ created: true, user: this.formatUser(created) })
  }

  async store({ request, response, authUser }: HttpContext & { authUser?: any }) {
    if (authUser && !this.ensureUserAdmin(authUser, response)) return
    const { username, password, role = 'pharmacist', is_active = true } = request.all()

    if (!username || !password) {
      return response.status(400).json({ error: 'Username and password are required.' })
    }

    const cleanUsername = String(username).trim().toLowerCase()
    const existing = await User.query().where('username', cleanUsername).first()
    if (existing) {
      return response.status(409).json({ error: `A staff user with username '${cleanUsername}' already exists.` })
    }

    let normalizedRole = String(role || 'pharmacist').trim().toLowerCase()
    if (normalizedRole === 'admin' || normalizedRole === 'pharmacyadmin') normalizedRole = 'pharmacy_admin'
    if (normalizedRole === 'super_admin') normalizedRole = 'supervisor'
    if (normalizedRole === 'staff') normalizedRole = 'pharmacist'
    if (normalizedRole === 'branchadmin' || normalizedRole === 'branch_manager') normalizedRole = 'branch_admin'

    const hashedPassword = await bcrypt.hash(String(password).trim(), 10)
    const user = await User.create({
      username: cleanUsername,
      password: hashedPassword,
      role: normalizedRole as any,
      isActive: Boolean(is_active),
    })

    syncHub.emit(TenantContext.get()?.code || 'main', 'user_created', { id: user.id })
    return response.status(201).json(this.formatUser(user))
  }

  async update({ params, request, response, authUser }: HttpContext & { authUser?: any }) {
    if (authUser && !this.ensureUserAdmin(authUser, response)) return
    const user = await User.query().where('id', params.id).first()
    if (!user) {
      return response.status(404).json({ error: 'User not found.' })
    }

    const { username, password, role, is_active } = request.all()

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

    if (password && typeof password === 'string' && password.trim().length > 0) {
      user.password = await bcrypt.hash(password.trim(), 10)
    }

    if (role) {
      let normalizedRole = String(role).trim().toLowerCase()
      if (normalizedRole === 'admin' || normalizedRole === 'pharmacyadmin') normalizedRole = 'pharmacy_admin'
      if (normalizedRole === 'super_admin') normalizedRole = 'supervisor'
      if (normalizedRole === 'staff') normalizedRole = 'pharmacist'
      if (normalizedRole === 'branchadmin' || normalizedRole === 'branch_manager') normalizedRole = 'branch_admin'
      user.role = normalizedRole as any
    }

    if (is_active !== undefined) {
      user.isActive = Boolean(is_active)
    }

    await user.save()
    syncHub.emit(TenantContext.get()?.code || 'main', 'user_updated', { id: user.id })
    return response.ok(this.formatUser(user))
  }

  async destroy({ params, response, authUser }: HttpContext & { authUser?: any }) {
    if (authUser && !this.ensureUserAdmin(authUser, response)) return
    const user = await User.query().where('id', params.id).first()
    if (!user) {
      return response.status(404).json({ error: 'User not found.' })
    }
    if (user.id === 1 || user.username === 'admin') {
      return response.status(403).json({ error: 'Cannot delete the primary pharmacy administrator account.' })
    }
    await user.delete()
    syncHub.emit(TenantContext.get()?.code || 'main', 'user_updated', { id: Number(params.id), deleted: true })
    return response.ok({ success: true, message: 'User deleted.' })
  }
}
