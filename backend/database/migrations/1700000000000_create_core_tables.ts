import { BaseSchema } from '@adonisjs/lucid/schema'

export default class extends BaseSchema {
  async up() {
    // 1. System Users (Provider / Platform Admins)
    this.schema.createTable('system_users', (table) => {
      table.increments('id').primary()
      table.string('username', 100).unique().notNullable()
      table.string('email', 255).unique().notNullable()
      table.string('password', 255).notNullable()
      table.string('role', 50).notNullable().defaultTo('system_admin')
      table.boolean('is_active').defaultTo(true)
      table.timestamp('created_at', { useTz: true }).defaultTo(this.now())
      table.timestamp('updated_at', { useTz: true }).defaultTo(this.now())
    })

    // 2. Tenants (Pharmacies)
    this.schema.createTable('tenants', (table) => {
      table.increments('id').primary()
      table.string('code', 50).unique().notNullable()
      table.string('name', 255).notNullable()
      table.string('status', 50).notNullable().defaultTo('active')
      table.text('license_key').nullable()
      table.string('plan', 50).notNullable().defaultTo('professional')
      table.integer('max_terminals').notNullable().defaultTo(3)
      table.integer('max_users').notNullable().defaultTo(10)
      table.jsonb('enabled_modules').defaultTo('["pos_core","inventory_advanced"]')
      table.timestamp('license_expires_at', { useTz: true }).nullable()
      table.timestamp('created_at', { useTz: true }).defaultTo(this.now())
      table.timestamp('updated_at', { useTz: true }).defaultTo(this.now())
    })

    // 3. Registered Terminal Hardware Seats
    this.schema.createTable('terminals', (table) => {
      table.increments('id').primary()
      table.integer('tenant_id').unsigned().references('id').inTable('tenants').onDelete('CASCADE')
      table.string('hardware_uuid', 255).notNullable()
      table.string('name', 100).defaultTo('Counter Terminal')
      table.boolean('is_active').defaultTo(true)
      table.timestamp('last_seen_at', { useTz: true }).nullable()
      table.unique(['tenant_id', 'hardware_uuid'])
      table.timestamp('created_at', { useTz: true }).defaultTo(this.now())
      table.timestamp('updated_at', { useTz: true }).defaultTo(this.now())
    })

    // 4. System Telemetry & Aggregated Health
    this.schema.createTable('system_telemetry', (table) => {
      table.increments('id').primary()
      table.integer('tenant_id').unsigned().references('id').inTable('tenants').onDelete('CASCADE')
      table.string('metric_type', 100).notNullable()
      table.jsonb('metric_data').notNullable().defaultTo('{}')
      table.timestamp('created_at', { useTz: true }).defaultTo(this.now())
    })
  }

  async down() {
    this.schema.dropTable('system_telemetry')
    this.schema.dropTable('terminals')
    this.schema.dropTable('tenants')
    this.schema.dropTable('system_users')
  }
}
