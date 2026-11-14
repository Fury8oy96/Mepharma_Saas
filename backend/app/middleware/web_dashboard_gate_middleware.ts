import { HttpContext } from '@adonisjs/core/http'
import jwt from 'jsonwebtoken'
import { getJwtSecret } from '#core/security/jwt_secret'

export default class WebDashboardGateMiddleware {
  async handle(ctx: HttpContext, next: () => Promise<void>) {
    const authHeader = ctx.request.header('authorization')
    const token = authHeader?.replace(/^Bearer\s+/i, '').trim() || ctx.session?.get('auth_token')

    if (!token) {
      return ctx.response.status(401).json({
        error: 'Unauthorized',
        message: 'Authentication token required to access Pharmacy Admin Dashboard.',
      })
    }

    try {
      const decoded = jwt.verify(token, getJwtSecret()) as any

      if (decoded.isProviderAdmin) {
        return ctx.response.status(403).json({
          error: 'Access Forbidden',
          message: 'Provider tokens cannot access pharmacy admin endpoints.',
        })
      }

      const tenant = (ctx as any).tenant
      if (tenant && decoded.pharmacyCode && decoded.pharmacyCode !== tenant.code) {
        return ctx.response.status(403).json({
          error: 'Tenant Mismatch',
          code: 'TENANT_MISMATCH',
          message: 'Authentication token belongs to a different pharmacy tenant.',
        })
      }

      ;(ctx as any).authUser = decoded

      // STRICT GATEKEEPING RULE:
      // Branch Admins, Pharmacists, Supervisors, and Cashiers MUST NEVER enter the Web Dashboard.
      const role = (decoded.role || '').toLowerCase()
      if (role === 'branch_admin' || role === 'pharmacist' || role === 'supervisor' || role === 'cashier' || role === 'staff') {
        return ctx.response.status(403).json({
          error: 'Access Forbidden',
          code: 'DESKTOP_CLIENT_REQUIRED',
          message:
            'Branch Administrators, Pharmacists, and Cashiers are restricted to the Desktop POS Application. Web dashboard access is reserved exclusively for the Pharmacy Owner / Administrator.',
        })
      }

      if (role !== 'pharmacy_admin' && role !== 'admin' && role !== 'super_admin') {
        return ctx.response.status(403).json({
          error: 'Access Forbidden',
          message: 'Insufficient administrative privileges.',
        })
      }

      return await next()
    } catch {
      return ctx.response.status(401).json({
        error: 'Unauthorized',
        message: 'Invalid or expired session token.',
      })
    }
  }
}
