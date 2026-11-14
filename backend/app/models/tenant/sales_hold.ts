import { DateTime } from 'luxon'
import { BaseModel, column } from '@adonisjs/lucid/orm'

export default class SalesHold extends BaseModel {
  public static table = 'sales_holds'

  @column({ isPrimary: true })
  declare id: number

  @column()
  declare reference: string

  @column()
  declare userId: number | null

  @column()
  declare customerId: number | null

  @column()
  declare customerName: string | null

  @column({
    prepare: (val: any) => (typeof val === 'string' ? val : JSON.stringify(val || [])),
    consume: (val: any) => {
      if (typeof val === 'string') {
        try {
          return JSON.parse(val)
        } catch {
          return []
        }
      }
      return Array.isArray(val) ? val : []
    },
  })
  declare items: any[]

  @column()
  declare subtotal: number

  @column()
  declare discount: number

  @column()
  declare discountType: string | null

  @column()
  declare totalAmount: number

  @column()
  declare notes: string | null

  @column.dateTime({ autoCreate: true })
  declare createdAt: DateTime
}
