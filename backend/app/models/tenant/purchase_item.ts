import { DateTime } from 'luxon'
import { BaseModel, column, belongsTo } from '@adonisjs/lucid/orm'
import type { BelongsTo } from '@adonisjs/lucid/types/relations'
import Purchase from '#models/tenant/purchase'
import Product from '#models/tenant/product'

export default class PurchaseItem extends BaseModel {
  public static table = 'purchase_items'

  @column({ isPrimary: true })
  declare id: number

  @column()
  declare purchaseId: number

  @column()
  declare productId: number | null

  @column()
  declare productName: string

  @column()
  declare quantity: number

  @column()
  declare unitCost: number

  @column()
  declare subtotal: number

  @column.date()
  declare expiryDate: DateTime | null

  @belongsTo(() => Purchase)
  declare purchase: BelongsTo<typeof Purchase>

  @belongsTo(() => Product)
  declare product: BelongsTo<typeof Product>

  @column.dateTime({ autoCreate: true })
  declare createdAt: DateTime
}
