import { DateTime } from 'luxon'
import { BaseModel, column } from '@adonisjs/lucid/orm'

export default class ReturnItem extends BaseModel {
  public static table = 'return_items'

  @column({ isPrimary: true })
  declare id: number

  @column()
  declare returnId: number

  @column()
  declare saleItemId: number | null

  @column()
  declare productId: number | null

  @column()
  declare productName: string | null

  @column()
  declare unitPrice: number

  @column()
  declare quantity: number

  @column()
  declare refundAmount: number

  @column.dateTime({ autoCreate: true })
  declare createdAt: DateTime
}

