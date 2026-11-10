import { DateTime } from 'luxon'
import { BaseModel, column } from '@adonisjs/lucid/orm'

export default class MasterMedicine extends BaseModel {
  public static table = 'master_medicines'

  @column({ isPrimary: true })
  declare id: number

  @column()
  declare brandName: string

  @column()
  declare genericName: string

  @column()
  declare dosageForm: string

  @column()
  declare strength: string

  @column()
  declare barcode: string | null

  @column()
  declare categoryName: string | null

  @column()
  declare atcCode: string | null

  @column()
  declare prescriptionSchedule: string

  @column()
  declare defaultCostPrice: number

  @column()
  declare defaultSellingPrice: number

  @column()
  declare description: string | null

  @column.dateTime({ autoCreate: true })
  declare createdAt: DateTime

  @column.dateTime({ autoCreate: true, autoUpdate: true })
  declare updatedAt: DateTime
}
