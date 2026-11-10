import { TenantData } from '#core/tenancy/tenant_context'
import Terminal from '#models/core/terminal'

declare module '@adonisjs/core/http' {
  interface HttpContext {
    tenant: TenantData
    authUser?: {
      id: number
      username: string
      role: string
      pharmacyId?: number
      pharmacyCode?: string
      isProviderAdmin?: boolean
    }
    terminal?: Terminal
  }
}
