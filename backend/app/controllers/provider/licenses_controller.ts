import { HttpContext } from '@adonisjs/core/http'
import Tenant from '#models/core/tenant'
import { LicenseService } from '#core/licensing/license_service'

export default class LicensesController {
  async issue({ request, response }: HttpContext) {
    const { tenantId, plan, maxTerminals, maxUsers, validityDays = 365, gracePeriodDays = 14 } = request.all()

    const tenant = await Tenant.query().where('id', tenantId).first()
    if (!tenant) {
      return response.status(404).json({ error: 'Tenant not found.' })
    }

    const token = LicenseService.generateLicenseToken({
      tenantId: tenant.id,
      tenantCode: tenant.code,
      plan: plan || tenant.plan,
      maxTerminals: Number(maxTerminals) || tenant.maxTerminals,
      maxUsers: Number(maxUsers) || tenant.maxUsers,
      enabledModules: tenant.enabledModules,
      issuedAt: new Date().toISOString(),
      expiresAt: new Date(Date.now() + validityDays * 24 * 60 * 60 * 1000).toISOString(),
      gracePeriodDays: Number(gracePeriodDays),
    })

    tenant.licenseKey = token
    await tenant.save()

    return response.ok({
      success: true,
      licenseKey: token,
      tenantCode: tenant.code,
    })
  }

  async verify({ request, response }: HttpContext) {
    const { licenseKey } = request.all()
    const result = LicenseService.verifyLicenseToken(licenseKey)
    return response.ok(result)
  }
}
