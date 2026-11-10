import { DateTime } from 'luxon'
import { BaseModel, column, belongsTo } from '@adonisjs/lucid/orm'
import type { BelongsTo } from '@adonisjs/lucid/types/relations'
import Product from '#models/tenant/product'
import User from '#models/tenant/user'

export default class StaffProductFeedback extends BaseModel {
  public static table = 'staff_product_feedbacks'

  @column({ isPrimary: true })
  declare id: number

  @column()
  declare productId: number | null

  @column()
  declare productName: string

  @column()
  declare currentStock: number

  @column()
  declare staffUserId: number | null

  @column()
  declare staffUsername: string | null

  @column()
  declare branchId: number

  @column()
  declare urgency: string

  @column()
  declare suggestedQuantity: number

  @column()
  declare notes: string | null

  @column()
  declare status: string

  @belongsTo(() => Product)
  declare product: BelongsTo<typeof Product>

  @belongsTo(() => User, { foreignKey: 'staffUserId' })
  declare staffUser: BelongsTo<typeof User>

  @column.dateTime({ autoCreate: true })
  declare createdAt: DateTime

  @column.dateTime({ autoCreate: true, autoUpdate: true })
  declare updatedAt: DateTime
}
