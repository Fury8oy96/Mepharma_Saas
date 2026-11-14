import { HttpContext } from '@adonisjs/core/http'
import Tenant from '#models/core/tenant'
import Terminal from '#models/core/terminal'
import { SchemaManager } from '#core/tenancy/schema_manager'
import { LicenseService } from '#core/licensing/license_service'
import db from '@adonisjs/lucid/services/db'
import bcrypt from 'bcryptjs'
import { logAuditEvent } from './audit_logs_controller.js'

export default class TenantsController {
  async index({ response }: HttpContext) {
    const tenants = await Tenant.query().preload('terminals').orderBy('id', 'asc')
    return response.ok(tenants)
  }

  async show({ params, response }: HttpContext) {
    const tenant = await Tenant.query().where('id', params.id).preload('terminals').first()
    if (!tenant) {
      return response.status(404).json({ error: 'Tenant not found.' })
    }
    return response.ok(tenant)
  }

  async store({ request, response }: HttpContext) {
    const {
      code,
      name,
      plan = 'professional',
      maxTerminals = 3,
      maxUsers = 10,
      adminUsername = 'admin',
      adminPassword = 'admin123',
    } = request.all()

    if (!code || !name) {
      return response.status(400).json({ error: 'Tenant code and name are required.' })
    }

    const cleanCode = code.toLowerCase().trim().replace(/[^a-z0-9_-]/g, '_')
    const existing = await Tenant.query().where('code', cleanCode).first()
    if (existing) {
      return response.status(409).json({ error: 'A pharmacy with this code already exists.' })
    }

    // 1. Create Tenant Record
    const tenant = await Tenant.create({
      code: cleanCode,
      name,
      status: 'active',
      plan,
      maxTerminals: Number(maxTerminals) || 3,
      maxUsers: Number(maxUsers) || 10,
      enabledModules: ['pos_core', 'inventory_advanced', 'customer_loyalty_credit', 'prescriptions_clinical'],
    })

    // 2. Provision Tenant Schema & Tables
    const schemaName = await SchemaManager.provisionTenantSchema(cleanCode)

    // 3. Seed Default Pharmacy Admin in the tenant schema
    const hashedPassword = await bcrypt.hash(adminPassword, 10)
    await db.rawQuery(
      `INSERT INTO "${schemaName}".users (name, username, password, role, is_active)
       VALUES ('System Administrator', ?, ?, 'pharmacy_admin', true)
       ON CONFLICT (username) DO NOTHING;`,
      [adminUsername.toLowerCase(), hashedPassword]
    )

    // 4. Generate Cryptographic License Token
    const licenseToken = LicenseService.generateLicenseToken({
      tenantId: tenant.id,
      tenantCode: tenant.code,
      plan: tenant.plan,
      maxTerminals: tenant.maxTerminals,
      maxUsers: tenant.maxUsers,
      enabledModules: tenant.enabledModules,
      issuedAt: new Date().toISOString(),
      expiresAt: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000).toISOString(),
      gracePeriodDays: 14,
    })

    tenant.licenseKey = licenseToken
    await tenant.save()

    await logAuditEvent(
      'superadmin',
      'TENANT_PROVISIONED',
      'TENANT',
      tenant.code,
      { name: tenant.name, plan: tenant.plan, maxTerminals: tenant.maxTerminals },
      request.ip()
    )

    return response.status(201).json({
      success: true,
      tenant,
      adminUser: {
        username: adminUsername,
        role: 'pharmacy_admin',
      },
      licenseKey: licenseToken,
    })
  }

  async update({ params, request, response }: HttpContext) {
    const tenant = await Tenant.query().where('id', params.id).first()
    if (!tenant) {
      return response.status(404).json({ error: 'Tenant not found.' })
    }

    const { name, status, plan, maxTerminals, maxUsers, enabledModules } = request.all()

    if (name) tenant.name = name
    if (status) tenant.status = status
    if (plan) tenant.plan = plan
    if (maxTerminals !== undefined) tenant.maxTerminals = Number(maxTerminals)
    if (maxUsers !== undefined) tenant.maxUsers = Number(maxUsers)
    if (enabledModules) tenant.enabledModules = enabledModules

    // Regenerate cryptographic license token if quota, plan, or modules changed
    if (maxTerminals !== undefined || plan !== undefined || enabledModules !== undefined) {
      tenant.licenseKey = LicenseService.generateLicenseToken({
        tenantId: tenant.id,
        tenantCode: tenant.code,
        plan: tenant.plan,
        maxTerminals: tenant.maxTerminals,
        maxUsers: tenant.maxUsers,
        enabledModules: tenant.enabledModules || ['pos_core', 'inventory_advanced', 'customer_loyalty_credit', 'prescriptions_clinical'],
        issuedAt: new Date().toISOString(),
        expiresAt: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000).toISOString(),
        gracePeriodDays: 14,
      })
    }

    await tenant.save()

    await logAuditEvent(
      'superadmin',
      status === 'suspended' ? 'TENANT_SUSPENDED' : (status === 'active' ? 'TENANT_ACTIVATED' : 'TENANT_UPDATED'),
      'TENANT',
      tenant.code,
      { status: tenant.status, plan: tenant.plan, maxTerminals: tenant.maxTerminals },
      request.ip()
    )

    return response.ok({ success: true, tenant })
  }

  /**
   * Get all registered terminals / hardware seats for a tenant.
   */
  async getTerminals({ params, response }: HttpContext) {
    const tenant = await Tenant.query().where('id', params.id).first()
    if (!tenant) {
      return response.status(404).json({ error: 'Tenant not found.' })
    }

    const terminals = await Terminal.query()
      .where('tenant_id', tenant.id)
      .orderBy('last_seen_at', 'desc')

    return response.ok({
      tenantId: tenant.id,
      tenantCode: tenant.code,
      tenantName: tenant.name,
      maxTerminals: tenant.maxTerminals,
      activeCount: terminals.filter(t => t.isActive).length,
      totalCount: terminals.length,
      licenseKey: tenant.licenseKey,
      terminals,
    })
  }

  /**
   * Update seat quota (maxTerminals) for a tenant, regenerating cryptographic license token.
   */
  async updateSeats({ params, request, response }: HttpContext) {
    const tenant = await Tenant.query().where('id', params.id).first()
    if (!tenant) {
      return response.status(404).json({ error: 'Tenant not found.' })
    }

    const { maxTerminals } = request.all()
    const newQuota = Number(maxTerminals)
    if (!newQuota || newQuota < 1) {
      return response.status(400).json({ error: 'Valid seat quota (at least 1) is required.' })
    }

    const previousQuota = tenant.maxTerminals
    tenant.maxTerminals = newQuota

    // Regenerate cryptographic license token with updated quota
    const licenseToken = LicenseService.generateLicenseToken({
      tenantId: tenant.id,
      tenantCode: tenant.code,
      plan: tenant.plan,
      maxTerminals: tenant.maxTerminals,
      maxUsers: tenant.maxUsers,
      enabledModules: tenant.enabledModules || ['pos_core', 'inventory_advanced', 'customer_loyalty_credit', 'prescriptions_clinical'],
      issuedAt: new Date().toISOString(),
      expiresAt: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000).toISOString(),
      gracePeriodDays: 14,
    })

    tenant.licenseKey = licenseToken
    await tenant.save()

    await logAuditEvent(
      'superadmin',
      'TENANT_SEATS_UPDATED',
      'TENANT',
      tenant.code,
      { previousQuota, newQuota, licenseKey: licenseToken },
      request.ip()
    )

    const terminals = await Terminal.query().where('tenant_id', tenant.id).orderBy('last_seen_at', 'desc')

    return response.ok({
      success: true,
      tenant,
      licenseKey: licenseToken,
      maxTerminals: tenant.maxTerminals,
      activeCount: terminals.filter(t => t.isActive).length,
      terminals,
    })
  }

  /**
   * Update terminal details (e.g. rename terminal or toggle active status).
   */
  async updateTerminal({ params, request, response }: HttpContext) {
    const tenant = await Tenant.query().where('id', params.id).first()
    if (!tenant) {
      return response.status(404).json({ error: 'Tenant not found.' })
    }

    const terminal = await Terminal.query()
      .where('id', params.terminalId)
      .where('tenant_id', tenant.id)
      .first()

    if (!terminal) {
      return response.status(404).json({ error: 'Terminal not found.' })
    }

    const { name, isActive } = request.all()
    if (name !== undefined) terminal.name = String(name).trim()
    if (isActive !== undefined) terminal.isActive = Boolean(isActive)

    await terminal.save()

    return response.ok({ success: true, terminal })
  }

  /**
   * Unlink/Delete a hardware terminal from the pharmacy to release the seat immediately.
   */
  async unlinkTerminal({ params, request, response }: HttpContext) {
    const tenant = await Tenant.query().where('id', params.id).first()
    if (!tenant) {
      return response.status(404).json({ error: 'Tenant not found.' })
    }

    const terminal = await Terminal.query()
      .where('id', params.terminalId)
      .where('tenant_id', tenant.id)
      .first()

    if (!terminal) {
      return response.status(404).json({ error: 'Terminal not found.' })
    }

    const terminalInfo = {
      id: terminal.id,
      name: terminal.name,
      hardwareUuid: terminal.hardwareUuid,
    }

    await terminal.delete()

    await logAuditEvent(
      'superadmin',
      'TERMINAL_UNLINKED',
      'TERMINAL',
      tenant.code,
      terminalInfo,
      request.ip()
    )

    const remainingTerminals = await Terminal.query()
      .where('tenant_id', tenant.id)
      .orderBy('last_seen_at', 'desc')

    return response.ok({
      success: true,
      message: `Terminal '${terminalInfo.name}' (${terminalInfo.hardwareUuid}) was unlinked successfully.`,
      unlinkedTerminal: terminalInfo,
      terminals: remainingTerminals,
      activeCount: remainingTerminals.filter(t => t.isActive).length,
      maxTerminals: tenant.maxTerminals,
    })
  }

  async destroy({ params, response }: HttpContext) {
    const tenant = await Tenant.query().where('id', params.id).first()
    if (!tenant) {
      return response.status(404).json({ error: 'Tenant not found.' })
    }

    // Drop schema
    const schemaName = SchemaManager.getSchemaName(tenant.code)
    await db.rawQuery(`DROP SCHEMA IF EXISTS "${schemaName}" CASCADE;`)
    await tenant.delete()

    return response.ok({ success: true, message: `Pharmacy '${tenant.code}' deleted.` })
  }
}
