import { DateTime } from 'luxon'
import { BaseModel, column, belongsTo } from '@adonisjs/lucid/orm'
import type { BelongsTo } from '@adonisjs/lucid/types/relations'
import Sale from '#models/tenant/sale'
import Product from '#models/tenant/product'

export default class SaleItem extends BaseModel {
  public static table = 'sale_items'

  @column({ isPrimary: true })
  declare id: number

  @column()
  declare saleId: number

  @column()
  declare productId: number | null

  @column()
  declare productName: string

  @column()
  declare barcode: string | null

  @column()
  declare quantity: number

  @column()
  declare unitPrice: number

  @column()
  declare costPrice: number

  @column()
  declare subtotal: number

  @column()
  declare discount: number

  @column()
  declare total: number

  @belongsTo(() => Sale)
  declare sale: BelongsTo<typeof Sale>

  @belongsTo(() => Product)
  declare product: BelongsTo<typeof Product>

  @column.dateTime({ autoCreate: true })
  declare createdAt: DateTime
}
