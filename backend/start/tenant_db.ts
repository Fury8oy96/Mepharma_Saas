import db from '@adonisjs/lucid/services/db'
import { TenantContext } from '#core/tenancy/tenant_context'

/**
 * Binds Lucid's primary database connection lookup to the request-scoped
 * transaction stored in TenantContext (AsyncLocalStorage). This prevents
 * cross-tenant PostgreSQL search_path contamination under concurrent load.
 */
const originalConnection = db.connection.bind(db)

db.connection = ((connectionName?: string, options?: any) => {
  const targetName = connectionName || db.primaryConnectionName
  if (targetName === db.primaryConnectionName && !options?.mode) {
    const activeTrx = TenantContext.getTrx()
    if (activeTrx) {
      return activeTrx
    }
  }
  return originalConnection(connectionName, options)
}) as typeof db.connection

