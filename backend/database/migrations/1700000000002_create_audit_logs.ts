import { BaseSchema } from '@adonisjs/lucid/schema'

export default class extends BaseSchema {
  protected tableName = 'audit_logs'

  async up() {
    this.schema.createTable(this.tableName, (table) => {
      table.increments('id').primary()
      table.string('actor_username', 100).notNullable()
      table.string('action', 100).notNullable().index()
      table.string('entity_type', 100).notNullable()
      table.string('entity_id', 100).notNullable()
      table.jsonb('details').notNullable().defaultTo('{}')
      table.string('ip_address', 50).defaultTo('127.0.0.1')
      table.timestamp('created_at', { useTz: true }).defaultTo(this.now()).index()
    })
  }

  async down() {
    this.schema.dropTable(this.tableName)
  }
}
