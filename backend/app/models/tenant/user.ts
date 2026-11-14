import { DateTime } from 'luxon'
import { BaseModel, column, computed } from '@adonisjs/lucid/orm'

export default class User extends BaseModel {
  public static table = 'users'

  @column({ isPrimary: true })
  declare id: number

  @column()
  declare name: string | null

  @column()
  declare username: string

  @column({ serializeAs: null })
  declare password: string

  @column()
  declare role: 'pharmacy_admin' | 'branch_admin' | 'supervisor' | 'pharmacist' | 'cashier'

  @column({ columnName: 'is_active' })
  declare isActive: boolean

  @computed()
  get is_active(): boolean {
    return Boolean(this.isActive)
  }

  @column.dateTime({ autoCreate: true })
  declare createdAt: DateTime

  @column.dateTime({ autoCreate: true, autoUpdate: true })
  declare updatedAt: DateTime
}
