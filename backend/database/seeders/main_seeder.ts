import { BaseSeeder } from '@adonisjs/lucid/seeders'
import SystemUser from '#models/core/system_user'
import Tenant from '#models/core/tenant'
import MasterMedicine from '#models/core/master_medicine'
import { SchemaManager } from '#core/tenancy/schema_manager'
import { LicenseService } from '#core/licensing/license_service'
import bcrypt from 'bcryptjs'
import db from '@adonisjs/lucid/services/db'

export default class MainSeeder extends BaseSeeder {
  async run() {
    console.log('⚡ Starting MePharma Enterprise SaaS database seeding...')

    // 1. Seed Provider Superadmin in Control Plane
    const hashedPasswordSuper = await bcrypt.hash('superadmin123', 10)
    await SystemUser.firstOrCreate(
      { username: 'superadmin' },
      {
        username: 'superadmin',
        email: 'superadmin@mepharma.io',
        password: hashedPasswordSuper,
        role: 'system_admin',
        isActive: true,
      }
    )
    console.log('✅ Provider Superadmin seeded (username: superadmin, password: superadmin123)')

    // 2. Seed Default Tenant (Pharmacy 1: Main)
    const tenant = await Tenant.firstOrCreate(
      { code: 'main' },
      {
        code: 'main',
        name: 'MePharma Central Pharmacy',
        status: 'active',
        plan: 'enterprise',
        maxTerminals: 5,
        maxUsers: 20,
        enabledModules: ['pos_core', 'inventory_advanced', 'prescriptions_clinical', 'customer_loyalty_credit'],
      }
    )

    // 3. Provision Tenant Schema & Tables
    const schemaName = await SchemaManager.provisionTenantSchema(tenant.code)
    console.log(`✅ Tenant schema provisioned: ${schemaName}`)

    // 4. Generate & Save Cryptographic License Key
    const licenseToken = LicenseService.generateLicenseToken({
      tenantId: tenant.id,
      tenantCode: tenant.code,
      plan: tenant.plan,
      maxTerminals: tenant.maxTerminals,
      maxUsers: tenant.maxUsers,
      enabledModules: tenant.enabledModules,
      issuedAt: new Date().toISOString(),
      expiresAt: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000).toISOString(),
      gracePeriodDays: 14,
    })
    tenant.licenseKey = licenseToken
    await tenant.save()
    console.log('✅ Cryptographic license issued and attached to tenant')

    // 5. Seed Master Drug Formulary in Core DB
    const masterMedicines = [
      {
        brandName: 'Panadol Extra',
        genericName: 'Paracetamol / Caffeine',
        dosageForm: 'Tablet',
        strength: '500mg / 65mg',
        barcode: '622000000001',
        categoryName: 'Analgesics & Pain Relief',
        atcCode: 'N02BE51',
        prescriptionSchedule: 'OTC',
        defaultCostPrice: 400,
        defaultSellingPrice: 750,
        description: 'Rapid headache and mild to moderate pain relief with caffeine booster.',
      },
      {
        brandName: 'Augmentin',
        genericName: 'Amoxicillin / Clavulanate Potassium',
        dosageForm: 'Tablet',
        strength: '1000mg',
        barcode: '622000000002',
        categoryName: 'Antibiotics',
        atcCode: 'J01CR02',
        prescriptionSchedule: 'Rx',
        defaultCostPrice: 2500,
        defaultSellingPrice: 3800,
        description: 'Broad-spectrum beta-lactam antibiotic for bacterial infections.',
      },
      {
        brandName: 'Brufen',
        genericName: 'Ibuprofen',
        dosageForm: 'Tablet',
        strength: '400mg',
        barcode: '622000000003',
        categoryName: 'Analgesics & Pain Relief',
        atcCode: 'M01AE01',
        prescriptionSchedule: 'OTC',
        defaultCostPrice: 600,
        defaultSellingPrice: 1100,
        description: 'Non-steroidal anti-inflammatory drug (NSAID) for inflammation and pain.',
      },
      {
        brandName: 'Nexium',
        genericName: 'Esomeprazole Magnesium',
        dosageForm: 'Delayed-Release Capsule',
        strength: '40mg',
        barcode: '622000000004',
        categoryName: 'Gastrointestinal',
        atcCode: 'A02BC05',
        prescriptionSchedule: 'Rx',
        defaultCostPrice: 3000,
        defaultSellingPrice: 4600,
        description: 'Proton pump inhibitor (PPI) for GERD and acid-peptic disorders.',
      },
      {
        brandName: 'Glucophage',
        genericName: 'Metformin Hydrochloride',
        dosageForm: 'Film-Coated Tablet',
        strength: '1000mg',
        barcode: '622000000005',
        categoryName: 'Antidiabetic',
        atcCode: 'A10BA02',
        prescriptionSchedule: 'Rx',
        defaultCostPrice: 800,
        defaultSellingPrice: 1400,
        description: 'First-line biguanide for type 2 diabetes mellitus management.',
      },
      {
        brandName: 'Zyrtec',
        genericName: 'Cetirizine Hydrochloride',
        dosageForm: 'Tablet',
        strength: '10mg',
        barcode: '622000000006',
        categoryName: 'Antihistamines & Allergy',
        atcCode: 'R06AE07',
        prescriptionSchedule: 'OTC',
        defaultCostPrice: 700,
        defaultSellingPrice: 1200,
        description: 'Second-generation non-drowsy antihistamine for allergic rhinitis and urticaria.',
      },
      {
        brandName: 'Lipitor',
        genericName: 'Atorvastatin Calcium',
        dosageForm: 'Tablet',
        strength: '20mg',
        barcode: '622000000007',
        categoryName: 'Cardiovascular',
        atcCode: 'C10AA05',
        prescriptionSchedule: 'Rx',
        defaultCostPrice: 2800,
        defaultSellingPrice: 4200,
        description: 'HMG-CoA reductase inhibitor for hypercholesterolemia and cardiovascular prevention.',
      },
      {
        brandName: 'Concor',
        genericName: 'Bisoprolol Fumarate',
        dosageForm: 'Tablet',
        strength: '5mg',
        barcode: '622000000008',
        categoryName: 'Cardiovascular',
        atcCode: 'C07AB07',
        prescriptionSchedule: 'Rx',
        defaultCostPrice: 1400,
        defaultSellingPrice: 2300,
        description: 'Selective beta-1 blocker for hypertension and stable chronic heart failure.',
      },
      {
        brandName: 'Ventolin',
        genericName: 'Salbutamol Sulfate',
        dosageForm: 'Inhaler',
        strength: '100mcg / puff',
        barcode: '622000000009',
        categoryName: 'Respiratory',
        atcCode: 'R03AC02',
        prescriptionSchedule: 'Rx',
        defaultCostPrice: 1800,
        defaultSellingPrice: 2900,
        description: 'Short-acting beta-2 agonist bronchodilator for acute asthma and COPD bronchospasm.',
      },
      {
        brandName: 'Ciprofar',
        genericName: 'Ciprofloxacin Hydrochloride',
        dosageForm: 'Tablet',
        strength: '500mg',
        barcode: '622000000010',
        categoryName: 'Antibiotics',
        atcCode: 'J01MA02',
        prescriptionSchedule: 'Rx',
        defaultCostPrice: 1100,
        defaultSellingPrice: 1900,
        description: 'Fluoroquinolone antimicrobial for urinary, respiratory and enteric infections.',
      },
      {
        brandName: 'Zithrokan',
        genericName: 'Azithromycin Monohydrate',
        dosageForm: 'Capsule',
        strength: '500mg',
        barcode: '622000000011',
        categoryName: 'Antibiotics',
        atcCode: 'J01FA10',
        prescriptionSchedule: 'Rx',
        defaultCostPrice: 1900,
        defaultSellingPrice: 3100,
        description: 'Macrolide antibiotic 3-day course for respiratory and soft tissue infections.',
      },
      {
        brandName: 'Controloc',
        genericName: 'Pantoprazole Sodium',
        dosageForm: 'Gastro-Resistant Tablet',
        strength: '40mg',
        barcode: '622000000012',
        categoryName: 'Gastrointestinal',
        atcCode: 'A02BC02',
        prescriptionSchedule: 'Rx',
        defaultCostPrice: 2200,
        defaultSellingPrice: 3400,
        description: 'Proton pump inhibitor for reflux esophagitis and duodenal ulcers.',
      },
      {
        brandName: 'Voltaren',
        genericName: 'Diclofenac Sodium',
        dosageForm: 'Tablet',
        strength: '50mg',
        barcode: '622000000013',
        categoryName: 'Analgesics & Pain Relief',
        atcCode: 'M01AB05',
        prescriptionSchedule: 'OTC',
        defaultCostPrice: 900,
        defaultSellingPrice: 1500,
        description: 'Potent non-steroidal anti-inflammatory for acute muscular and joint pain.',
      },
      {
        brandName: 'Neurobion',
        genericName: 'Vitamin B1 + B6 + B12',
        dosageForm: 'Coated Tablet',
        strength: '100mg / 200mg / 200mcg',
        barcode: '622000000014',
        categoryName: 'Vitamins & Supplements',
        atcCode: 'A11DB',
        prescriptionSchedule: 'OTC',
        defaultCostPrice: 850,
        defaultSellingPrice: 1400,
        description: 'Neurotropic vitamin complex for peripheral neuropathy and nerve health.',
      },
      {
        brandName: 'Cozaar',
        genericName: 'Losartan Potassium',
        dosageForm: 'Film-Coated Tablet',
        strength: '50mg',
        barcode: '622000000015',
        categoryName: 'Cardiovascular',
        atcCode: 'C09CA01',
        prescriptionSchedule: 'Rx',
        defaultCostPrice: 2100,
        defaultSellingPrice: 3200,
        description: 'Angiotensin II receptor antagonist (ARB) for blood pressure control.',
      },
    ]

    for (const med of masterMedicines) {
      await MasterMedicine.firstOrCreate(
        { barcode: med.barcode },
        med
      )
    }
    console.log(`✅ Seeded ${masterMedicines.length} items into Central Master Drug Catalog (public.master_medicines)`)

    // 6. Seed Admin User ONLY into Tenant Schema
    const adminHash = await bcrypt.hash('admin123', 10)

    const tenantUsers = [
      { username: 'admin', password: adminHash, role: 'pharmacy_admin' },
    ]

    for (const u of tenantUsers) {
      await db.rawQuery(
        `INSERT INTO "${schemaName}".users (username, password, role, is_active)
         VALUES (?, ?, ?, true)
         ON CONFLICT (username) 
         DO UPDATE SET password = EXCLUDED.password, role = EXCLUDED.role, is_active = true;`,
        [u.username, u.password, u.role]
      )
    }
    console.log('✅ Sole Admin user seeded (admin)')

    // 7. Sync PostgreSQL serial sequences
    await db.rawQuery(
      `SELECT setval(pg_get_serial_sequence('"${schemaName}".users', 'id'), coalesce(max(id), 1)) FROM "${schemaName}".users;`
    )

    // 8. Seed Settings into Tenant Schema
    const settings = [
      { key: 'store_name', value: 'MePharma Pharmacy' },
      { key: 'currency', value: 'SDG' },
      { key: 'currency_symbol', value: 'ج.س' },
      { key: 'tax_rate', value: '0' },
      { key: 'profit_margin', value: '0' },
      { key: 'profitMargin', value: '0' },
      { key: 'receipt_footer', value: 'شكراً لاختياركم صيدليتنا!' },
    ]

    for (const s of settings) {
      await db.rawQuery(
        `INSERT INTO "${schemaName}".settings (key, value)
         VALUES (?, ?)
         ON CONFLICT (key) DO NOTHING;`,
        [s.key, s.value]
      )
    }

    console.log('✅ Sample products, categories, and settings seeded successfully.')
  }
}
