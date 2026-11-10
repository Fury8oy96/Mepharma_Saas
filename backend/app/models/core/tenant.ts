import { DateTime } from 'luxon'
import { BaseModel, column, hasMany } from '@adonisjs/lucid/orm'
import type { HasMany } from '@adonisjs/lucid/types/relations'
import Terminal from '#models/core/terminal'

export default class Tenant extends BaseModel {
  public static table = 'tenants'

  @column({ isPrimary: true })
  declare id: number

  @column()
  declare code: string

  @column()
  declare name: string

  @column()
  declare status: 'active' | 'suspended' | 'trial' | 'expired'

  @column()
  declare licenseKey: string | null

  @column()
  declare plan: 'starter' | 'professional' | 'enterprise'

  @column()
  declare maxTerminals: number

  @column()
  declare maxUsers: number

  @column({
    prepare: (val: any) => JSON.stringify(val),
    consume: (val: any) => (typeof val === 'string' ? JSON.parse(val) : val || []),
  })
  declare enabledModules: string[]

  @column.dateTime()
  declare licenseExpiresAt: DateTime | null

  @hasMany(() => Terminal, {
    foreignKey: 'tenantId',
  })
  declare terminals: HasMany<typeof Terminal>

  @column.dateTime({ autoCreate: true })
  declare createdAt: DateTime

  @column.dateTime({ autoCreate: true, autoUpdate: true })
  declare updatedAt: DateTime
}
