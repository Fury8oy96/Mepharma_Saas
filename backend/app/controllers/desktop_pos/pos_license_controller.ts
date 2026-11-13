import { HttpContext } from '@adonisjs/core/http'
import Tenant from '#models/core/tenant'
import Terminal from '#models/core/terminal'
import { LicenseService } from '#core/licensing/license_service'
import { SchemaManager } from '#core/tenancy/schema_manager'
import db from '@adonisjs/lucid/services/db'
import { DateTime } from 'luxon'

export default class PosLicenseController {
  /**
   * Activates and validates a cryptographic 1-year license key for a desktop counter terminal,
   * registers the hardware seat within quota, and automatically returns the live pharmacy state.
   */
  async activateLicense({ request, response, tenant }: HttpContext) {
    const { licenseKey, hardwareUuid, terminalName = 'POS Counter Terminal' } = request.all()

    if (!licenseKey || typeof licenseKey !== 'string') {
      return response.status(400).json({
        success: false,
        valid: false,
        error: 'License key is required.',
      })
    }

    // 1. Verify Cryptographic HMAC Signature & Structure
    const verifyResult = LicenseService.verifyLicenseToken(licenseKey.trim())
    if (!verifyResult.valid || !verifyResult.payload) {
      return response.status(400).json({
        success: false,
        valid: false,
        error: verifyResult.error || 'Invalid or malformed license key signature.',
      })
    }

    const payload = verifyResult.payload

    // 2. Validate Expiration & Grace Period
    const expiresAtMs = new Date(payload.expiresAt).getTime()
    const now = Date.now()
    const gracePeriodMs = (payload.gracePeriodDays || 14) * 24 * 60 * 60 * 1000

    if (now > expiresAtMs + gracePeriodMs) {
      return response.status(403).json({
        success: false,
        valid: false,
        code: 'LICENSE_EXPIRED',
        error: `License has expired on ${new Date(payload.expiresAt).toLocaleDateString()}. Please renew your annual subscription with provider administration.`,
        expiresAt: payload.expiresAt,
      })
    }

    // 3. Resolve Target Tenant
    const targetCode = payload.tenantCode.toLowerCase().trim()
    let tenantRecord = await Tenant.query().where('code', targetCode).first()

    // Cross-check with context tenant if request was made to a specific subdomain
    if (tenant && tenant.code !== targetCode) {
      return response.status(400).json({
        success: false,
        valid: false,
        error: `License key belongs to pharmacy '${targetCode}', but this request was addressed to '${tenant.code}'.`,
      })
    }

    if (!tenantRecord) {
      return response.status(404).json({
        success: false,
        valid: false,
        error: `Pharmacy tenant '${targetCode}' was not found in the platform registry.`,
      })
    }

    if (tenantRecord.status === 'suspended') {
      return response.status(403).json({
        success: false,
        valid: false,
        code: 'TENANT_SUSPENDED',
        error: 'This pharmacy account is currently suspended. Please contact provider administration.',
      })
    }

    // Update license key on the tenant record if not yet recorded
    if (!tenantRecord.licenseKey || tenantRecord.licenseKey !== licenseKey) {
      tenantRecord.licenseKey = licenseKey
      tenantRecord.licenseExpiresAt = DateTime.fromISO(payload.expiresAt)
      await tenantRecord.save()
    }

    // 4. Hardware Terminal Seat Registration & Quota Enforcement
    const effectiveHardwareId = (hardwareUuid && String(hardwareUuid).trim()) || 'TERM-WIN-COUNTER-1'
    let terminal = await Terminal.query()
      .where('tenant_id', tenantRecord.id)
      .where('hardware_uuid', effectiveHardwareId)
      .first()

    if (!terminal) {
      const activeCountRes = await Terminal.query()
        .where('tenant_id', tenantRecord.id)
        .where('is_active', true)
        .count('* as total')

      const currentActive = Number(activeCountRes[0].$extras.total) || 0
      const allowedMax = payload.maxTerminals || tenantRecord.maxTerminals || 1

      if (currentActive >= allowedMax) {
        return response.status(402).json({
          success: false,
          valid: false,
          code: 'TERMINAL_QUOTA_REACHED',
          error: `Terminal seat limit reached (${allowedMax} seats registered). Please contact provider administration to upgrade terminal seats.`,
          allowedMax,
          currentActive,
        })
      }

      terminal = await Terminal.create({
        tenantId: tenantRecord.id,
        hardwareUuid: effectiveHardwareId,
        name: terminalName,
        isActive: true,
        lastSeenAt: DateTime.now(),
      })
    } else {
      terminal.name = terminalName
      terminal.isActive = true
      terminal.lastSeenAt = DateTime.now()
      await terminal.save()
    }

    // 5. Auto-Grab Pharmacy Information from Tenant Schema
    const schemaName = SchemaManager.getSchemaName(tenantRecord.code)
    await SchemaManager.ensureSchema(schemaName)

    let settingsMap: Record<string, string> = {}
    try {
      const settingsRows = await db.rawQuery(`SELECT key, value FROM "${schemaName}".settings;`)
      for (const row of settingsRows.rows || []) {
        settingsMap[row.key] = row.value
      }
    } catch (_) {
      settingsMap = {}
    }

    // Calculate 1-based seat number (and branch number) by order of active terminal installs/seats
    const activeTerminals = await Terminal.query()
      .where('tenant_id', tenantRecord.id)
      .where('is_active', true)
      .orderBy('id', 'asc')

    const terminalIndex = activeTerminals.findIndex(t => t.id === terminal.id)
    const seatNumber = terminalIndex >= 0 ? terminalIndex + 1 : 1
    const branchNumber = seatNumber

    const daysRemaining = Math.max(0, Math.ceil((expiresAtMs - now) / (24 * 60 * 60 * 1000)))

    return response.ok({
      success: true,
      valid: true,
      license: {
        plan: payload.plan || tenantRecord.plan,
        issuedAt: payload.issuedAt,
        expiresAt: payload.expiresAt,
        validityDaysRemaining: daysRemaining,
        maxTerminals: payload.maxTerminals || tenantRecord.maxTerminals,
        maxUsers: payload.maxUsers || tenantRecord.maxUsers,
        enabledModules: payload.enabledModules || tenantRecord.enabledModules,
      },
      pharmacy: {
        id: tenantRecord.id,
        code: tenantRecord.code,
        name: settingsMap['store_name'] || settingsMap['name'] || tenantRecord.name,
        phone: settingsMap['store_phone'] || settingsMap['phone'] || '',
        address: settingsMap['store_address'] || settingsMap['address'] || '',
        taxId: settingsMap['store_tax_id'] || settingsMap['taxNumber'] || settingsMap['tax_number'] || '',
        currency: settingsMap['currency'] || 'SDG',
        currencySymbol: settingsMap['currency_symbol'] || settingsMap['currency'] || 'SDG',
        taxRate: Number(settingsMap['tax_rate'] || settingsMap['taxRate']) || 0,
        profitMargin: settingsMap['profit_margin'] || settingsMap['profitMargin'] || '0.3',
        lowStockThreshold: settingsMap['low_stock_threshold'] || settingsMap['lowStockThreshold'] || '10',
        receiptFooter: settingsMap['receipt_footer'] || settingsMap['receiptFooter'] || 'Thank you for choosing MePharma!',
        receiptStyle: settingsMap['receipt_style'] || 'modern',
        receiptFormat: settingsMap['receipt_format'] || '80mm',
        receiptFont: settingsMap['receipt_font'] || 'Tajawal',
      },
      terminal: {
        id: terminal.id,
        hardwareUuid: terminal.hardwareUuid,
        name: terminal.name,
        seatNumber: seatNumber,
        branchNumber: branchNumber,
        maxTerminals: payload.maxTerminals || tenantRecord.maxTerminals,
      },
    })
  }

  /**
   * Fast identity endpoint for testing connectivity and viewing basic branch metadata.
   */
  async info({ response, tenant }: HttpContext) {
    if (!tenant) {
      return response.status(404).json({ error: 'Pharmacy branch not resolved.' })
    }

    return response.ok({
      id: tenant.id,
      code: tenant.code,
      name: tenant.name,
      status: tenant.status,
      plan: tenant.plan,
      maxTerminals: tenant.maxTerminals,
      hasLicense: !!tenant.licenseKey,
    })
  }
}
