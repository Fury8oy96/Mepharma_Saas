import { DateTime } from 'luxon'
import { BaseModel, column } from '@adonisjs/lucid/orm'

export default class Return extends BaseModel {
  public static table = 'returns'

  @column({ isPrimary: true })
  declare id: number

  @column()
  declare returnNumber: string

  @column()
  declare saleId: number | null

  @column()
  declare userId: number | null

  @column()
  declare totalRefund: number

  @column()
  declare reason: string | null

  @column.dateTime({ autoCreate: true })
  declare createdAt: DateTime
}
