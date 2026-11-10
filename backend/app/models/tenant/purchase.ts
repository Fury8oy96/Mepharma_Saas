import { DateTime } from 'luxon'
import { BaseModel, column, hasMany, belongsTo } from '@adonisjs/lucid/orm'
import type { HasMany, BelongsTo } from '@adonisjs/lucid/types/relations'
import Supplier from '#models/tenant/supplier'
import PurchaseItem from '#models/tenant/purchase_item'

export default class Purchase extends BaseModel {
  public static table = 'purchases'

  @column({ isPrimary: true })
  declare id: number

  @column()
  declare invoiceNumber: string

  @column()
  declare supplierId: number | null

  @column()
  declare userId: number | null

  @column()
  declare subtotal: number

  @column()
  declare taxAmount: number

  @column()
  declare totalAmount: number

  @column()
  declare paidAmount: number

  @column()
  declare status: string

  @column()
  declare notes: string | null

  @belongsTo(() => Supplier)
  declare supplier: BelongsTo<typeof Supplier>

  @hasMany(() => PurchaseItem)
  declare items: HasMany<typeof PurchaseItem>

  @column.dateTime({ autoCreate: true })
  declare createdAt: DateTime

  @column.dateTime({ autoCreate: true, autoUpdate: true })
  declare updatedAt: DateTime
}
