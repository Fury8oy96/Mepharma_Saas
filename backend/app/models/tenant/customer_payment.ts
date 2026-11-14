import { DateTime } from 'luxon'
import { BaseModel, column } from '@adonisjs/lucid/orm'

export default class CustomerPayment extends BaseModel {
  public static table = 'customer_payments'

  @column({ isPrimary: true })
  declare id: number

  @column()
  declare customerId: number

  @column()
  declare amount: number

  @column()
  declare paymentMethod: string

  @column()
  declare notes: string | null

  @column.dateTime({ autoCreate: true })
  declare createdAt: DateTime

  @column.dateTime({ autoCreate: true, autoUpdate: true })
  declare updatedAt: DateTime
}

