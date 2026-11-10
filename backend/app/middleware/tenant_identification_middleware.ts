import { HttpContext } from '@adonisjs/core/http'
import { TenantContext } from '#core/tenancy/tenant_context'
import { SchemaManager } from '#core/tenancy/schema_manager'
import Tenant from '#models/core/tenant'

export default class TenantIdentificationMiddleware {
  async handle(ctx: HttpContext, next: () => Promise<void>) {
    // 1. Resolve tenant code from headers, subdomain, or query param
    const headerCode = ctx.request.header('x-pharmacy-code')
    const queryCode = ctx.request.input('pharmacy')
    const host = ctx.request.hostname() || ''
    const subdomain = host.includes('.') ? host.split('.')[0] : ''

    const effectiveSubdomain = (subdomain && !['admin', 'provider', 'www', 'localhost', 'api'].includes(subdomain)) ? subdomain : ''
    let tenantCode = (headerCode || queryCode || effectiveSubdomain || 'main').toLowerCase()

    // Root provider / health check routes do not need tenant isolation
    if (ctx.request.url().startsWith('/provider') || ctx.request.url() === '/status' || ctx.request.url() === '/health') {
      return await next()
    }

    // 2. Fetch tenant from database
    let tenant = await Tenant.query().where('code', tenantCode).first()

    // If 'main' default doesn't exist yet, auto-create during bootstrap
    if (!tenant && tenantCode === 'main') {
      tenant = await Tenant.create({
        code: 'main',
        name: 'Main Central Pharmacy',
        status: 'active',
        plan: 'enterprise',
        maxTerminals: 5,
        maxUsers: 20,
        enabledModules: ['pos_core', 'inventory_advanced', 'prescriptions_clinical', 'customer_loyalty_credit'],
      })
      await SchemaManager.provisionTenantSchema(tenant.code)
    }

    if (!tenant) {
      return ctx.response.status(404).json({
        error: 'Tenant Not Found',
        message: `Pharmacy '${tenantCode}' was not found in the platform registry.`,
      })
    }

    if (tenant.status === 'suspended') {
      return ctx.response.status(403).json({
        error: 'Pharmacy Account Suspended',
        message: 'This pharmacy account is currently suspended. Please contact provider platform administration.',
      })
    }

    // 3. Switch PostgreSQL search path to the dedicated tenant schema
    const schemaName = SchemaManager.getSchemaName(tenant.code)
    await SchemaManager.ensureSchema(schemaName)
    await SchemaManager.setSearchPath(schemaName)

    // 4. Attach to context and AsyncLocalStorage
    const tenantData = {
      id: tenant.id,
      code: tenant.code,
      name: tenant.name,
      status: tenant.status,
      plan: tenant.plan,
      licenseKey: tenant.licenseKey || '',
      maxTerminals: tenant.maxTerminals,
      enabledModules: tenant.enabledModules,
      schemaName,
    }

    ;(ctx as any).tenant = tenantData

    return await TenantContext.run({ tenant: tenantData }, async () => {
      return await next()
    })
  }
}
