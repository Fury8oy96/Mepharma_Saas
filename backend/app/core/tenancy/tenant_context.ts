import { AsyncLocalStorage } from 'node:async_hooks'

export interface TenantData {
  id: number
  code: string
  name: string
  status: string
  plan: string
  licenseKey: string
  maxTerminals: number
  enabledModules: string[]
  schemaName: string
}

export interface TenantStore {
  tenant: TenantData
}

export const tenantLocalStorage = new AsyncLocalStorage<TenantStore>()

export class TenantContext {
  static run<T>(store: TenantStore, callback: () => Promise<T>): Promise<T> {
    return tenantLocalStorage.run(store, callback)
  }

  static get(): TenantData | null {
    const store = tenantLocalStorage.getStore()
    return store?.tenant || null
  }

  static require(): TenantData {
    const tenant = this.get()
    if (!tenant) {
      throw new Error('Tenant context is required but was not resolved for this request.')
    }
    return tenant
  }
}
