import { HttpContext } from '@adonisjs/core/http'
import db from '@adonisjs/lucid/services/db'
import { TenantContext } from '#core/tenancy/tenant_context'
import { SchemaManager } from '#core/tenancy/schema_manager'
import Tenant from '#models/core/tenant'

const TENANT_CODE_REGEX = /^[a-z0-9_-]{1,63}$/

export default class TenantIdentificationMiddleware {
  async handle(ctx: HttpContext, next: () => Promise<void>) {
    const url = ctx.request.url()

    // Root provider / health check routes do not need tenant isolation
    if (
      url.startsWith('/provider') ||
      url === '/status' ||
      url === '/api/status' ||
      url === '/health' ||
      url === '/api/health'
    ) {
      return await next()
    }

    // 1. Resolve tenant code from headers, subdomain, or query param
    const headerCode = ctx.request.header('x-pharmacy-code')
    const queryCode = ctx.request.input('pharmacy')
    const host = ctx.request.hostname() || ''
    const subdomain = host.includes('.') ? host.split('.')[0] : ''

    const effectiveSubdomain =
      subdomain && !['admin', 'provider', 'www', 'localhost', 'api'].includes(subdomain.toLowerCase())
        ? subdomain
        : ''
    const tenantCode = String(headerCode || queryCode || effectiveSubdomain || 'main')
      .trim()
      .toLowerCase()

    if (!TENANT_CODE_REGEX.test(tenantCode)) {
      return ctx.response.status(400).json({
        error: 'Invalid Tenant Identifier',
        message: 'Pharmacy code contains invalid characters.',
      })
    }

    // 2. Fetch tenant from control plane database
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

    // 3. Provision / verify dedicated tenant schema & compatibility columns (cached in-memory)
    const schemaName = SchemaManager.getSchemaName(tenant.code)
    await SchemaManager.ensureSchema(schemaName)
    await SchemaManager.ensureSchemaColumns(schemaName)

    // 4. Build immutable tenant descriptor
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

    // SSE connections stay open indefinitely; do NOT hold a PostgreSQL transaction/connection open for them.
    if (url.startsWith('/sync/events') || url.startsWith('/api/sync/events')) {
      return await TenantContext.run({ tenant: tenantData }, async () => {
        return await next()
      })
    }

    // 5. Run the request inside an isolated DB transaction pinned to SET LOCAL search_path
    return await db.transaction(async (trx) => {
      await trx.rawQuery(`SET LOCAL search_path TO "${schemaName}", public;`)
      return await TenantContext.run({ tenant: tenantData, trx }, async () => {
        return await next()
      })
    })
  }
}
