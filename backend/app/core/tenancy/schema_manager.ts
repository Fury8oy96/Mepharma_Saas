import db from '@adonisjs/lucid/services/db'

export class SchemaManager {
  /**
   * Sanitizes a tenant code into a safe PostgreSQL schema name.
   */
  static getSchemaName(tenantCode: string): string {
    const clean = tenantCode.toLowerCase().replace(/[^a-z0-9_]/g, '_')
    return `tenant_${clean}`
  }

  /**
   * Creates a schema if it does not already exist.
   */
  static async ensureSchema(schemaName: string): Promise<void> {
    await db.rawQuery(`CREATE SCHEMA IF NOT EXISTS "${schemaName}";`)
  }

  /**
   * Switches the active search path for a database connection.
   */
  static async setSearchPath(schemaName: string): Promise<void> {
    await db.rawQuery(`SET search_path TO "${schemaName}", public;`)
  }

  /**
   * Provisions all tables for a tenant schema.
   */
  static async provisionTenantSchema(tenantCode: string): Promise<string> {
    const schemaName = this.getSchemaName(tenantCode)
    await this.ensureSchema(schemaName)

    // Execute schema creation inside the tenant schema
    const queries = [
      `CREATE TABLE IF NOT EXISTS "${schemaName}".users (
        id SERIAL PRIMARY KEY,
        username VARCHAR(100) UNIQUE NOT NULL,
        password VARCHAR(255) NOT NULL,
        role VARCHAR(50) NOT NULL DEFAULT 'pharmacist',
        is_active BOOLEAN DEFAULT TRUE,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      );`,

      `CREATE TABLE IF NOT EXISTS "${schemaName}".categories (
        id SERIAL PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        description TEXT,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      );`,

      `CREATE TABLE IF NOT EXISTS "${schemaName}".suppliers (
        id SERIAL PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        phone VARCHAR(100),
        email VARCHAR(255),
        address TEXT,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      );`,

      `CREATE TABLE IF NOT EXISTS "${schemaName}".products (
        id SERIAL PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        sku VARCHAR(100) UNIQUE NOT NULL,
        barcode VARCHAR(100),
        category_id INTEGER REFERENCES "${schemaName}".categories(id) ON DELETE SET NULL,
        supplier_id INTEGER REFERENCES "${schemaName}".suppliers(id) ON DELETE SET NULL,
        cost_price BIGINT DEFAULT 0,
        selling_price BIGINT DEFAULT 0,
        stock_quantity INTEGER DEFAULT 0,
        low_stock_threshold INTEGER DEFAULT 10,
        version INTEGER DEFAULT 1,
        expiry_date DATE,
        description TEXT,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      );`,

      `CREATE TABLE IF NOT EXISTS "${schemaName}".customers (
        id SERIAL PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        phone VARCHAR(100),
        email VARCHAR(255),
        address TEXT,
        credit_limit BIGINT DEFAULT 0,
        balance BIGINT DEFAULT 0,
        loyalty_points BIGINT DEFAULT 0,
        loyalty_tier VARCHAR(50) DEFAULT 'silver',
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      );`,

      `CREATE TABLE IF NOT EXISTS "${schemaName}".customer_payments (
        id SERIAL PRIMARY KEY,
        customer_id INTEGER REFERENCES "${schemaName}".customers(id) ON DELETE CASCADE,
        amount BIGINT NOT NULL,
        payment_method VARCHAR(50) DEFAULT 'cash',
        notes TEXT,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      );`,

      `CREATE TABLE IF NOT EXISTS "${schemaName}".sales (
        id SERIAL PRIMARY KEY,
        invoice_number VARCHAR(100) UNIQUE NOT NULL,
        idempotency_key VARCHAR(100) UNIQUE,
        user_id INTEGER REFERENCES "${schemaName}".users(id) ON DELETE SET NULL,
        customer_id INTEGER REFERENCES "${schemaName}".customers(id) ON DELETE SET NULL,
        customer_name VARCHAR(255),
        subtotal BIGINT NOT NULL,
        discount BIGINT DEFAULT 0,
        discount_type VARCHAR(50),
        tax_amount BIGINT DEFAULT 0,
        total_amount BIGINT NOT NULL,
        paid_amount BIGINT DEFAULT 0,
        change_amount BIGINT DEFAULT 0,
        payment_method VARCHAR(50) DEFAULT 'cash',
        status VARCHAR(50) DEFAULT 'completed',
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      );`,

      `CREATE TABLE IF NOT EXISTS "${schemaName}".sale_items (
        id SERIAL PRIMARY KEY,
        sale_id INTEGER REFERENCES "${schemaName}".sales(id) ON DELETE CASCADE,
        product_id INTEGER REFERENCES "${schemaName}".products(id) ON DELETE SET NULL,
        product_name VARCHAR(255) NOT NULL,
        barcode VARCHAR(100),
        quantity INTEGER NOT NULL,
        unit_price BIGINT NOT NULL,
        cost_price BIGINT DEFAULT 0,
        subtotal BIGINT NOT NULL,
        discount BIGINT DEFAULT 0,
        total BIGINT NOT NULL,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      );`,

      `CREATE TABLE IF NOT EXISTS "${schemaName}".sales_holds (
        id SERIAL PRIMARY KEY,
        reference VARCHAR(100) UNIQUE NOT NULL,
        customer_id INTEGER REFERENCES "${schemaName}".customers(id) ON DELETE SET NULL,
        customer_name VARCHAR(255),
        items JSONB NOT NULL,
        notes TEXT,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      );`,

      `CREATE TABLE IF NOT EXISTS "${schemaName}".purchases (
        id SERIAL PRIMARY KEY,
        invoice_number VARCHAR(100) UNIQUE NOT NULL,
        supplier_id INTEGER REFERENCES "${schemaName}".suppliers(id) ON DELETE SET NULL,
        user_id INTEGER REFERENCES "${schemaName}".users(id) ON DELETE SET NULL,
        subtotal BIGINT NOT NULL,
        tax_amount BIGINT DEFAULT 0,
        total_amount BIGINT NOT NULL,
        paid_amount BIGINT DEFAULT 0,
        status VARCHAR(50) DEFAULT 'received',
        notes TEXT,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      );`,

      `CREATE TABLE IF NOT EXISTS "${schemaName}".purchase_items (
        id SERIAL PRIMARY KEY,
        purchase_id INTEGER REFERENCES "${schemaName}".purchases(id) ON DELETE CASCADE,
        product_id INTEGER REFERENCES "${schemaName}".products(id) ON DELETE SET NULL,
        product_name VARCHAR(255) NOT NULL,
        quantity INTEGER NOT NULL,
        unit_cost BIGINT NOT NULL,
        subtotal BIGINT NOT NULL,
        expiry_date DATE,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      );`,

      `CREATE TABLE IF NOT EXISTS "${schemaName}".returns (
        id SERIAL PRIMARY KEY,
        return_number VARCHAR(100) UNIQUE NOT NULL,
        sale_id INTEGER REFERENCES "${schemaName}".sales(id) ON DELETE SET NULL,
        user_id INTEGER REFERENCES "${schemaName}".users(id) ON DELETE SET NULL,
        total_refund BIGINT NOT NULL,
        reason TEXT,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      );`,

      `CREATE TABLE IF NOT EXISTS "${schemaName}".return_items (
        id SERIAL PRIMARY KEY,
        return_id INTEGER REFERENCES "${schemaName}".returns(id) ON DELETE CASCADE,
        product_id INTEGER REFERENCES "${schemaName}".products(id) ON DELETE SET NULL,
        quantity INTEGER NOT NULL,
        refund_amount BIGINT NOT NULL,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      );`,

      `CREATE TABLE IF NOT EXISTS "${schemaName}".stock_adjustments (
        id SERIAL PRIMARY KEY,
        product_id INTEGER REFERENCES "${schemaName}".products(id) ON DELETE CASCADE,
        user_id INTEGER REFERENCES "${schemaName}".users(id) ON DELETE SET NULL,
        type VARCHAR(50) NOT NULL,
        quantity INTEGER NOT NULL,
        reason TEXT,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      );`,

      `CREATE TABLE IF NOT EXISTS "${schemaName}".stock_ledger (
        id SERIAL PRIMARY KEY,
        product_id INTEGER REFERENCES "${schemaName}".products(id) ON DELETE CASCADE,
        change_quantity INTEGER NOT NULL,
        balance_after INTEGER NOT NULL,
        reference_type VARCHAR(50) NOT NULL,
        reference_id INTEGER,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      );`,

      `CREATE TABLE IF NOT EXISTS "${schemaName}".settings (
        id SERIAL PRIMARY KEY,
        key VARCHAR(100) UNIQUE NOT NULL,
        value TEXT,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      );`,

      `CREATE TABLE IF NOT EXISTS "${schemaName}".staff_product_feedbacks (
        id SERIAL PRIMARY KEY,
        product_id INTEGER REFERENCES "${schemaName}".products(id) ON DELETE SET NULL,
        product_name VARCHAR(255) NOT NULL,
        current_stock INTEGER DEFAULT 0,
        staff_user_id INTEGER REFERENCES "${schemaName}".users(id) ON DELETE SET NULL,
        staff_username VARCHAR(100),
        branch_id INTEGER DEFAULT 1,
        urgency VARCHAR(50) DEFAULT 'normal',
        suggested_quantity INTEGER DEFAULT 10,
        notes TEXT,
        status VARCHAR(50) DEFAULT 'pending',
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      );`,

      `INSERT INTO "${schemaName}".suppliers (name, phone, email, address) VALUES
        ('National Pharma Wholesalers', '+966-11-2345678', 'supply@natpharma.com', 'Central Med District'),
        ('Al-Razi Drug Distributing', '+966-11-8765432', 'orders@alrazi.com', 'North Warehouse 4')
      ON CONFLICT DO NOTHING;`
    ]

    for (const q of queries) {
      await db.rawQuery(q)
    }

    return schemaName
  }
}
