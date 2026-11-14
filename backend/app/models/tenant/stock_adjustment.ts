import { DateTime } from 'luxon'
import { BaseModel, column } from '@adonisjs/lucid/orm'

export default class StockAdjustment extends BaseModel {
  public static table = 'stock_adjustments'

  @column({ isPrimary: true })
  declare id: number

  @column()
  declare productId: number

  @column()
  declare userId: number | null

  @column()
  declare type: 'add' | 'subtract' | 'set' | 'damaged' | 'expired'

  @column()
  declare quantity: number

  @column()
  declare reason: string | null

  @column()
  declare reference: string | null

  @column.dateTime({ autoCreate: true })
  declare createdAt: DateTime
}
