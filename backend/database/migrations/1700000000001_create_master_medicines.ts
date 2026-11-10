import { BaseSchema } from '@adonisjs/lucid/schema'

export default class extends BaseSchema {
  protected tableName = 'master_medicines'

  async up() {
    this.schema.createTable(this.tableName, (table) => {
      table.increments('id').primary()
      table.string('brand_name', 150).notNullable().index()
      table.string('generic_name', 150).notNullable().index()
      table.string('dosage_form', 50).notNullable().defaultTo('Tablet')
      table.string('strength', 50).notNullable().defaultTo('')
      table.string('barcode', 50).nullable().index()
      table.string('category_name', 100).nullable().index()
      table.string('atc_code', 30).nullable()
      table.string('prescription_schedule', 30).notNullable().defaultTo('OTC')
      table.integer('default_cost_price').notNullable().defaultTo(0)
      table.integer('default_selling_price').notNullable().defaultTo(0)
      table.text('description').nullable()

      table.timestamp('created_at', { useTz: true }).defaultTo(this.now())
      table.timestamp('updated_at', { useTz: true }).defaultTo(this.now())
    })
  }

  async down() {
    this.schema.dropTable(this.tableName)
  }
}
