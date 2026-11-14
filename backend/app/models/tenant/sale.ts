import { DateTime } from 'luxon'
import { BaseModel, column, hasMany } from '@adonisjs/lucid/orm'
import type { HasMany } from '@adonisjs/lucid/types/relations'
import SaleItem from '#models/tenant/sale_item'

export default class Sale extends BaseModel {
  public static table = 'sales'

  @column({ isPrimary: true })
  declare id: number

  @column()
  declare invoiceNumber: string

  @column()
  declare idempotencyKey: string | null

  @column()
  declare userId: number | null

  @column()
  declare customerId: number | null

  @column()
  declare customerName: string | null

  @column()
  declare subtotal: number

  @column()
  declare discount: number

  @column()
  declare discountType: string | null

  @column()
  declare taxAmount: number

  @column()
  declare totalAmount: number

  @column()
  declare paidAmount: number

  @column()
  declare changeAmount: number

  @column()
  declare paymentMethod: string

  @column()
  declare transactionReference: string | null

  @column()
  declare status: 'completed' | 'returned' | 'voided'

  @hasMany(() => SaleItem)
  declare items: HasMany<typeof SaleItem>

  @column.dateTime({ autoCreate: true })
  declare createdAt: DateTime

  @column.dateTime({ autoCreate: true, autoUpdate: true })
  declare updatedAt: DateTime
}
