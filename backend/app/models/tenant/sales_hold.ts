import { DateTime } from 'luxon'
import { BaseModel, column } from '@adonisjs/lucid/orm'

export default class SalesHold extends BaseModel {
  public static table = 'sales_holds'

  @column({ isPrimary: true })
  declare id: number

  @column()
  declare reference: string

  @column()
  declare customerId: number | null

  @column()
  declare customerName: string | null

  @column({
    prepare: (val: any) => JSON.stringify(val),
    consume: (val: any) => (typeof val === 'string' ? JSON.parse(val) : val || []),
  })
  declare items: any[]

  @column()
  declare notes: string | null

  @column.dateTime({ autoCreate: true })
  declare createdAt: DateTime
}
