import { DateTime } from 'luxon'
import { BaseModel, column, belongsTo } from '@adonisjs/lucid/orm'
import type { BelongsTo } from '@adonisjs/lucid/types/relations'
import Category from '#models/tenant/category'
import Supplier from '#models/tenant/supplier'

export default class Product extends BaseModel {
  public static table = 'products'

  @column({ isPrimary: true })
  declare id: number

  @column()
  declare name: string

  @column()
  declare sku: string

  @column()
  declare barcode: string | null

  @column()
  declare categoryId: number | null

  @column()
  declare supplierId: number | null

  @column()
  declare costPrice: number

  @column()
  declare sellingPrice: number

  @column()
  declare stockQuantity: number

  @column()
  declare lowStockThreshold: number

  @column()
  declare version: number

  @column.date()
  declare expiryDate: DateTime | null

  @column()
  declare description: string | null

  @belongsTo(() => Category)
  declare category: BelongsTo<typeof Category>

  @belongsTo(() => Supplier)
  declare supplier: BelongsTo<typeof Supplier>

  @column.dateTime({ autoCreate: true })
  declare createdAt: DateTime

  @column.dateTime({ autoCreate: true, autoUpdate: true })
  declare updatedAt: DateTime
}
