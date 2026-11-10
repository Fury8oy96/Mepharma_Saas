<script lang="ts">
  import { onMount } from 'svelte';
  import { apiRequest, addToast } from '../api';
  import { icons } from '../utils/icons';
  import { t, currentLocale } from '../i18n/store';

  let form = {
    name: 'MePharma Pharmacy',
    phone: '',
    email: '',
    address: '',
    taxNumber: '',
    taxRate: '0',
    currency: 'SDG',
    lowStockThreshold: 10,
    profitMargin: '0.3',
    receiptFooter: 'شكراً لزيارتكم - نتمنى لكم عاجل الشفاء',
    receiptHeader: '',
    receiptStyle: 'modern',
    receiptFormat: '80mm',
    receiptFont: 'Tajawal',
    showTaxId: 'true',
    showCashier: 'true',
    showBarcode: 'true',
  };
  let loading = true;
  let isSaving = false;
  let isRecalculating = false;

  async function loadSettings() {
    loading = true;
    try {
      const res = await apiRequest('/settings/store');
      form = {
        name: res.name || res['store.name'] || 'MePharma Pharmacy',
        phone: res.phone || res['store.phone'] || '',
        email: res.email || res['store.email'] || '',
        address: res.address || res['store.address'] || '',
        taxNumber: res.taxNumber || res.tax_number || res['store.tax_id'] || '',
        taxRate: String(res.taxRate || res.tax_rate || res['store.tax_rate'] || '0'),
        currency: res.currency || res.currencySymbol || res['store.currency_symbol'] || 'SDG',
        lowStockThreshold: Number(res.lowStockThreshold || res.low_stock_threshold || res['store.low_stock_threshold'] || 10),
        profitMargin: String(res.profitMargin || res.profit_margin || res['store.profit_margin'] || '0.3'),
        receiptFooter: res.receiptFooter || res.receipt_footer || res['store.receipt_footer'] || 'شكراً لزيارتكم - نتمنى لكم عاجل الشفاء',
        receiptHeader: res.receiptHeader || res.receipt_header || res['store.receipt_header'] || '',
        receiptStyle: res.receiptStyle || res.receipt_style || res['store.receipt_style'] || 'modern',
        receiptFormat: res.receiptFormat || res.receipt_format || res['store.receipt_format'] || '80mm',
        receiptFont: res.receiptFont || res.receipt_font || res['store.receipt_font'] || 'Tajawal',
        showTaxId: String(res.showTaxId ?? res.show_tax_id ?? 'true'),
        showCashier: String(res.showCashier ?? res.show_cashier ?? 'true'),
        showBarcode: String(res.showBarcode ?? res.show_barcode ?? 'true'),
      };
    } catch (err: any) {
      addToast(err.message || $t('toast.error'), 'error');
    } finally {
      loading = false;
    }
  }

  onMount(loadSettings);

  async function handleSave() {
    isSaving = true;
    try {
      await apiRequest('/settings/store', {
        method: 'POST',
        body: JSON.stringify(form)
      });
      addToast($t('toast.success'), 'success');
    } catch (err: any) {
      addToast(err.message || $t('toast.error'), 'error');
    } finally {
      isSaving = false;
    }
  }

  async function handleApplyMarginToAll() {
    const marginPct = (parseFloat(form.profitMargin) * 100).toFixed(0);
    const confirmMsg = $currentLocale === 'ar' 
      ? `هل أنت متأكد من إعادة حساب أسعار البيع لجميع الأدوية في المخزون بنسبة ربح ${marginPct}%؟`
      : `Are you sure you want to recalculate the selling price for ALL active products using the ${marginPct}% margin markup?`;

    if (!confirm(confirmMsg)) {
      return;
    }

    isRecalculating = true;
    try {
      const res = await apiRequest('/settings/apply-margin', {
        method: 'POST',
        body: JSON.stringify({ margin: parseFloat(form.profitMargin) || 0.3 })
      });
      addToast(res.message || $t('toast.success'), 'success');
    } catch (err: any) {
      addToast(err.message || $t('toast.error'), 'error');
    } finally {
      isRecalculating = false;
    }
  }
</script>

<div class="settings-container animate-fade-in">
  <div class="tab-header">
    <div>
      <h2>{$t('set.title')}</h2>
      <p class="subtitle">{$t('overview.desc')}</p>
    </div>
    <button class="btn btn-primary" disabled={isSaving} on:click={handleSave}>
      {@html icons.check} {isSaving ? $t('app.syncing') : $t('set.btnSave')}
    </button>
  </div>

  <div class="settings-cards-grid">
    <!-- Card 1: Enterprise Pharmacy Profile -->
    <div class="vuexy-card settings-card">
      <div class="card-header">
        <div class="header-icon-title">
          <div class="avatar-icon bg-light-primary text-primary">
            {@html icons.settings}
          </div>
          <div>
            <h3>{$t('set.pharmacyProfile')}</h3>
            <p class="card-desc">Public-facing brand information on invoices</p>
          </div>
        </div>
      </div>

      <div class="form-body">
        <div class="form-group">
          <label for="set-name">{$t('set.pharmacyName')}</label>
          <input id="set-name" class="form-input" type="text" bind:value={form.name} />
        </div>

        <div class="form-row">
          <div class="form-group">
            <label for="set-phone">{$t('set.phone')}</label>
            <input id="set-phone" class="form-input" type="text" bind:value={form.phone} placeholder="+249-183-000000" />
          </div>
          <div class="form-group">
            <label for="set-tax">{$t('set.taxNumber')}</label>
            <input id="set-tax" class="form-input" type="text" bind:value={form.taxNumber} placeholder="TAX-000-000" />
          </div>
        </div>

        <div class="form-group">
          <label for="set-addr">{$t('set.address')}</label>
          <input id="set-addr" class="form-input" type="text" bind:value={form.address} />
        </div>
      </div>
    </div>

    <!-- Card 2: Pricing Engine -->
    <div class="vuexy-card settings-card">
      <div class="card-header">
        <div class="header-icon-title">
          <div class="avatar-icon bg-light-success text-success">
            {@html icons.dollar}
          </div>
          <div>
            <h3>{$t('set.pricingEngine')}</h3>
            <p class="card-desc">Automatic markup algorithm and sales taxes</p>
          </div>
        </div>
      </div>

      <div class="form-body">
        <div class="form-group">
          <label for="set-margin">{$t('set.defaultMargin')}</label>
          <div class="input-with-action">
            <input id="set-margin" class="form-input" type="number" step="0.05" min="0" max="2" bind:value={form.profitMargin} />
            <button class="btn btn-secondary btn-sm" disabled={isRecalculating} on:click={handleApplyMarginToAll}>
              {isRecalculating ? $t('app.syncing') : 'Recalculate All Drugs'}
            </button>
          </div>
          <span class="field-hint">{$t('set.defaultMarginHint')}</span>
        </div>

        <div class="form-row">
          <div class="form-group">
            <label for="set-vat">{$t('set.vatRate')}</label>
            <input id="set-vat" class="form-input" type="number" step="0.5" bind:value={form.taxRate} />
          </div>
          <div class="form-group">
            <label for="set-curr">{$t('set.currency')}</label>
            <input id="set-curr" class="form-input" type="text" bind:value={form.currency} />
          </div>
        </div>
      </div>
    </div>

    <!-- Card 3: POS Thermal Receipt Format & Interactive Preview Studio -->
    <div class="vuexy-card settings-card full-width">
      <div class="card-header">
        <div class="header-icon-title">
          <div class="avatar-icon bg-light-warning text-warning">
            {@html icons.printer}
          </div>
          <div>
            <h3>{$t('set.receiptConfig')}</h3>
            <p class="card-desc">Interactive thermal receipt styling, typography, paper format, and real-time live preview</p>
          </div>
        </div>
        <div class="receipt-badges">
          <span class="badge badge-warning">{form.receiptFormat}</span>
          <span class="badge badge-info">{form.receiptFont}</span>
          <span class="badge badge-primary">{form.receiptStyle.toUpperCase()}</span>
        </div>
      </div>

      <div class="receipt-studio-grid">
        <!-- Left: Configuration Form -->
        <div class="receipt-controls-panel">
          <!-- Visual Style Selector -->
          <div class="form-group">
            <label>{$t('set.receiptStyle')}</label>
            <div class="style-selector-grid">
              <button
                type="button"
                class="style-card-btn {form.receiptStyle === 'modern' ? 'active' : ''}"
                on:click={() => form.receiptStyle = 'modern'}
              >
                <div class="style-badge-dot"></div>
                <div class="style-info">
                  <strong>{$t('set.styleModern')}</strong>
                  <small>Dashed lines, clean spacing</small>
                </div>
              </button>

              <button
                type="button"
                class="style-card-btn {form.receiptStyle === 'classic' ? 'active' : ''}"
                on:click={() => form.receiptStyle = 'classic'}
              >
                <div class="style-badge-dot"></div>
                <div class="style-info">
                  <strong>{$t('set.styleClassic')}</strong>
                  <small>Double border ===, centered</small>
                </div>
              </button>

              <button
                type="button"
                class="style-card-btn {form.receiptStyle === 'minimal' ? 'active' : ''}"
                on:click={() => form.receiptStyle = 'minimal'}
              >
                <div class="style-badge-dot"></div>
                <div class="style-info">
                  <strong>{$t('set.styleMinimal')}</strong>
                  <small>Subtle dividers, sleek</small>
                </div>
              </button>

              <button
                type="button"
                class="style-card-btn {form.receiptStyle === 'compact' ? 'active' : ''}"
                on:click={() => form.receiptStyle = 'compact'}
              >
                <div class="style-badge-dot"></div>
                <div class="style-info">
                  <strong>{$t('set.styleCompact')}</strong>
                  <small>Paper saver, dense lines</small>
                </div>
              </button>
            </div>
          </div>

          <!-- Format & Font row -->
          <div class="form-row">
            <div class="form-group">
              <label for="set-rcpt-format">{$t('set.receiptFormat')}</label>
              <select id="set-rcpt-format" class="form-input" bind:value={form.receiptFormat}>
                <option value="80mm">{$t('set.paper80mm')}</option>
                <option value="58mm">{$t('set.paper58mm')}</option>
                <option value="a4">{$t('set.paperA4')}</option>
              </select>
            </div>

            <div class="form-group">
              <label for="set-rcpt-font">{$t('set.receiptFont')}</label>
              <select id="set-rcpt-font" class="form-input" bind:value={form.receiptFont}>
                <option value="Tajawal">Tajawal (Unified Font)</option>
                <option value="Cairo">Cairo (Arabic Display)</option>
                <option value="Public Sans">Public Sans (Clean Latin)</option>
                <option value="JetBrains Mono">JetBrains Mono (Monospace)</option>
                <option value="Courier New">Courier New (Vintage POS)</option>
              </select>
            </div>
          </div>

          <!-- Custom Header Banner -->
          <div class="form-group">
            <label for="set-rcpt-head">{$t('set.receiptHeader')}</label>
            <input
              id="set-rcpt-head"
              class="form-input"
              type="text"
              bind:value={form.receiptHeader}
              placeholder="e.g. Welcome to {form.name || 'MePharma'} - Official Sales Slip"
            />
          </div>

          <!-- Footer Message -->
          <div class="form-group">
            <label for="set-foot">{$t('set.receiptFooter')}</label>
            <textarea
              id="set-foot"
              class="form-input"
              rows="2"
              bind:value={form.receiptFooter}
              placeholder="e.g. Thank you for your visit! Wishing you good health."
            ></textarea>
          </div>

          <!-- Toggles -->
          <div class="toggles-row">
            <label class="toggle-control">
              <input type="checkbox" checked={form.showTaxId === 'true'} on:change={(e) => form.showTaxId = e.currentTarget.checked ? 'true' : 'false'} />
              <span>{$t('set.showTaxId')}</span>
            </label>

            <label class="toggle-control">
              <input type="checkbox" checked={form.showCashier === 'true'} on:change={(e) => form.showCashier = e.currentTarget.checked ? 'true' : 'false'} />
              <span>{$t('set.showCashier')}</span>
            </label>

            <label class="toggle-control">
              <input type="checkbox" checked={form.showBarcode === 'true'} on:change={(e) => form.showBarcode = e.currentTarget.checked ? 'true' : 'false'} />
              <span>{$t('set.showBarcode')}</span>
            </label>
          </div>
        </div>

        <!-- Right: Interactive Live Thermal Slip Preview -->
        <div class="receipt-preview-panel">
          <div class="preview-panel-title">
            <span>{$t('set.livePreview')}</span>
            <span class="live-pill">● LIVE</span>
          </div>

          <div class="slip-stage">
            <div
              class="thermal-slip format-{form.receiptFormat} style-{form.receiptStyle}"
              style="font-family: '{form.receiptFont}', 'Tajawal', sans-serif;"
            >
              <!-- Serrated Top Edge -->
              <div class="sawtooth-edge top"></div>

              <!-- Header Information -->
              <div class="slip-header">
                <div class="slip-brand">{form.name || 'MePharma Central Pharmacy'}</div>
                {#if form.address}
                  <div class="slip-sub">{form.address}</div>
                {/if}
                {#if form.phone}
                  <div class="slip-sub">Tel: {form.phone}</div>
                {/if}
                {#if form.showTaxId === 'true' && form.taxNumber}
                  <div class="slip-sub slip-vat">VAT / TAX: {form.taxNumber}</div>
                {/if}
                {#if form.receiptHeader}
                  <div class="slip-custom-banner">{form.receiptHeader}</div>
                {/if}
              </div>

              <!-- Divider -->
              <div class="slip-divider"></div>

              <!-- Metadata -->
              <div class="slip-meta">
                <div class="meta-row">
                  <span>Invoice: <strong>#REC-2026-0042</strong></span>
                  <span>11/04/2026 14:30</span>
                </div>
                {#if form.showCashier === 'true'}
                  <div class="meta-row">
                    <span>Cashier: Sarah A.</span>
                    <span class="seat-badge">Counter #1 (Seat 1)</span>
                  </div>
                {/if}
              </div>

              <!-- Divider -->
              <div class="slip-divider"></div>

              <!-- Items Table -->
              <table class="slip-table">
                <thead>
                  <tr>
                    <th class="th-item">ITEM</th>
                    <th class="th-qty">QTY</th>
                    <th class="th-price">PRICE</th>
                    <th class="th-total">TOTAL</th>
                  </tr>
                </thead>
                <tbody>
                  <tr>
                    <td>Amoxicillin 500mg</td>
                    <td class="td-num">1</td>
                    <td class="td-num">1,300</td>
                    <td class="td-num">1,300</td>
                  </tr>
                  <tr>
                    <td>Paracetamol 500mg</td>
                    <td class="td-num">2</td>
                    <td class="td-num">1,000</td>
                    <td class="td-num">2,000</td>
                  </tr>
                  <tr>
                    <td>Vitamin C 1000mg Eff.</td>
                    <td class="td-num">1</td>
                    <td class="td-num">1,800</td>
                    <td class="td-num">1,800</td>
                  </tr>
                </tbody>
              </table>

              <!-- Divider -->
              <div class="slip-divider"></div>

              <!-- Financial Totals -->
              <div class="slip-totals">
                <div class="tot-row">
                  <span>Subtotal</span>
                  <span>5,100 {form.currency}</span>
                </div>
                <div class="tot-row">
                  <span>VAT ({form.taxRate}%)</span>
                  <span>{(5100 * (parseFloat(form.taxRate) || 0) / 100).toFixed(0)} {form.currency}</span>
                </div>
                <div class="tot-row grand-total">
                  <span>TOTAL DUE</span>
                  <span>{(5100 * (1 + (parseFloat(form.taxRate) || 0) / 100)).toFixed(0)} {form.currency}</span>
                </div>
                <div class="tot-row payment-info">
                  <span>Cash Paid</span>
                  <span>6,000 {form.currency}</span>
                </div>
                <div class="tot-row payment-info">
                  <span>Change</span>
                  <span>{(6000 - 5100 * (1 + (parseFloat(form.taxRate) || 0) / 100)).toFixed(0)} {form.currency}</span>
                </div>
              </div>

              <!-- Barcode Section -->
              {#if form.showBarcode === 'true'}
                <div class="slip-barcode-area">
                  <div class="simulated-barcode">
                    <span class="bar b1"></span><span class="bar b2"></span><span class="bar b1"></span><span class="bar b3"></span>
                    <span class="bar b2"></span><span class="bar b1"></span><span class="bar b4"></span><span class="bar b2"></span>
                    <span class="bar b1"></span><span class="bar b3"></span><span class="bar b1"></span><span class="bar b2"></span>
                    <span class="bar b4"></span><span class="bar b1"></span><span class="bar b2"></span><span class="bar b3"></span>
                    <span class="bar b1"></span><span class="bar b4"></span><span class="bar b2"></span><span class="bar b1"></span>
                    <span class="bar b3"></span><span class="bar b1"></span><span class="bar b2"></span><span class="bar b4"></span>
                  </div>
                  <div class="barcode-number">*REC-2026-0042*</div>
                </div>
              {/if}

              <!-- Footer Note -->
              {#if form.receiptFooter}
                <div class="slip-footer">
                  {form.receiptFooter}
                </div>
              {/if}

              <!-- Serrated Bottom Edge -->
              <div class="sawtooth-edge bottom"></div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</div>

<style>
  .settings-container {
    display: flex;
    flex-direction: column;
    gap: 1.5rem;
  }
  .tab-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }
  .tab-header h2 {
    font-size: 1.35rem;
    font-weight: 700;
  }
  .subtitle {
    font-size: 0.8125rem;
    color: var(--text-muted);
    margin-top: 2px;
  }

  .settings-cards-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 1.5rem;
  }
  .settings-card {
    padding: 1.5rem;
    display: flex;
    flex-direction: column;
    gap: 1.25rem;
  }
  .settings-card.full-width {
    grid-column: 1 / -1;
  }

  .card-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding-bottom: 1rem;
    border-bottom: 1px solid var(--border-color);
  }
  .header-icon-title {
    display: flex;
    align-items: center;
    gap: 12px;
  }
  .avatar-icon {
    width: 38px;
    height: 38px;
    border-radius: var(--radius-sm);
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .bg-light-primary { background: var(--color-primary-light); }
  .text-primary { color: var(--color-primary); }
  .bg-light-success { background: var(--color-success-light); }
  .text-success { color: var(--color-success); }
  .bg-light-warning { background: var(--color-warning-light); }
  .text-warning { color: var(--color-warning); }

  .header-icon-title h3 {
    font-size: 1.1rem;
    color: var(--text-heading);
  }
  .card-desc {
    font-size: 0.8rem;
    color: var(--text-muted);
  }

  .receipt-badges {
    display: flex;
    gap: 8px;
    align-items: center;
  }

  .form-body {
    display: flex;
    flex-direction: column;
    gap: 1.25rem;
  }
  .form-row {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 1.25rem;
  }
  .form-group {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }
  .form-group label {
    font-size: 0.8125rem;
    color: var(--text-primary);
    font-weight: 500;
  }
  .input-with-action {
    display: flex;
    gap: 8px;
  }
  .field-hint {
    font-size: 0.75rem;
    color: var(--text-muted);
    line-height: 1.3;
  }

  /* Receipt Studio Grid */
  .receipt-studio-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 1.75rem;
    align-items: start;
  }

  @media (max-width: 1024px) {
    .receipt-studio-grid {
      grid-template-columns: 1fr;
    }
  }

  .receipt-controls-panel {
    display: flex;
    flex-direction: column;
    gap: 1.25rem;
  }

  .style-selector-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 10px;
  }

  .style-card-btn {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 12px 14px;
    background: var(--bg-body);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-sm);
    cursor: pointer;
    text-align: left;
    transition: all var(--transition);
    color: var(--text-primary);
  }
  :global(html[dir="rtl"]) .style-card-btn {
    text-align: right;
  }
  .style-card-btn:hover {
    border-color: var(--color-primary);
    background: var(--color-primary-light);
  }
  .style-card-btn.active {
    border-color: var(--color-primary);
    background: var(--color-primary-light);
    box-shadow: 0 0 0 1px var(--color-primary);
  }
  .style-badge-dot {
    width: 10px;
    height: 10px;
    border-radius: 50%;
    border: 2px solid var(--text-muted);
    flex-shrink: 0;
  }
  .style-card-btn.active .style-badge-dot {
    border-color: var(--color-primary);
    background: var(--color-primary);
  }
  .style-info strong {
    display: block;
    font-size: 0.85rem;
    color: var(--text-heading);
  }
  .style-info small {
    display: block;
    font-size: 0.72rem;
    color: var(--text-muted);
    margin-top: 1px;
  }

  .toggles-row {
    display: flex;
    flex-wrap: wrap;
    gap: 16px;
    padding-top: 6px;
  }
  .toggle-control {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 0.825rem;
    color: var(--text-primary);
    cursor: pointer;
    user-select: none;
  }
  .toggle-control input[type="checkbox"] {
    accent-color: var(--color-primary);
    width: 16px;
    height: 16px;
    cursor: pointer;
  }

  /* Receipt Preview Stage */
  .receipt-preview-panel {
    background: var(--bg-body);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-md);
    padding: 1.25rem;
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }
  .preview-panel-title {
    display: flex;
    justify-content: space-between;
    align-items: center;
    font-size: 0.85rem;
    font-weight: 600;
    color: var(--text-heading);
  }
  .live-pill {
    font-size: 0.7rem;
    font-weight: 700;
    color: var(--color-success);
    letter-spacing: 0.05em;
  }
  .slip-stage {
    display: flex;
    justify-content: center;
    padding: 1.5rem 0.5rem;
    background: rgba(15, 23, 42, 0.45);
    border-radius: var(--radius-sm);
    overflow-x: auto;
  }

  /* Thermal Slip Sheet */
  .thermal-slip {
    background: #ffffff;
    color: #111827;
    border-radius: 2px;
    box-shadow: 0 12px 36px rgba(0, 0, 0, 0.35);
    padding: 24px 20px;
    font-size: 0.82rem;
    line-height: 1.4;
    position: relative;
    transition: all var(--transition);
  }
  .thermal-slip.format-80mm {
    width: 320px;
  }
  .thermal-slip.format-58mm {
    width: 245px;
    font-size: 0.72rem;
    padding: 18px 14px;
  }
  .thermal-slip.format-a4 {
    width: 420px;
    font-size: 0.9rem;
    padding: 32px 28px;
  }

  .slip-header {
    text-align: center;
    display: flex;
    flex-direction: column;
    gap: 3px;
  }
  .slip-brand {
    font-size: 1.05rem;
    font-weight: 800;
    letter-spacing: -0.01em;
  }
  .slip-sub {
    font-size: 0.75rem;
    color: #4b5563;
  }
  .slip-vat {
    font-weight: 600;
    color: #1f2937;
  }
  .slip-custom-banner {
    margin-top: 6px;
    padding: 4px;
    background: #f3f4f6;
    font-size: 0.75rem;
    font-weight: 600;
    border-radius: 3px;
  }

  .slip-divider {
    margin: 10px 0;
  }
  .style-modern .slip-divider {
    border-top: 1px dashed #9ca3af;
  }
  .style-classic .slip-divider {
    border-top: 3px double #1f2937;
  }
  .style-minimal .slip-divider {
    border-top: 1px solid #e5e7eb;
  }
  .style-compact .slip-divider {
    border-top: 1px dotted #9ca3af;
    margin: 5px 0;
  }

  .slip-meta {
    display: flex;
    flex-direction: column;
    gap: 4px;
    font-size: 0.75rem;
    color: #374151;
  }
  .meta-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }
  .seat-badge {
    background: #e0e7ff;
    color: #3730a3;
    padding: 1px 6px;
    border-radius: 3px;
    font-weight: 600;
    font-size: 0.7rem;
  }

  .slip-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 0.78rem;
    margin: 4px 0;
  }
  .slip-table th {
    padding: 4px 0;
    font-size: 0.7rem;
    color: #4b5563;
    border-bottom: 1px solid #d1d5db;
    text-align: left;
  }
  :global(html[dir="rtl"]) .slip-table th {
    text-align: right;
  }
  .slip-table td {
    padding: 4px 0;
    color: #111827;
  }
  .td-num, .th-qty, .th-price, .th-total {
    text-align: right;
  }
  :global(html[dir="rtl"]) .td-num,
  :global(html[dir="rtl"]) .th-qty,
  :global(html[dir="rtl"]) .th-price,
  :global(html[dir="rtl"]) .th-total {
    text-align: left;
  }

  .slip-totals {
    display: flex;
    flex-direction: column;
    gap: 3px;
    font-size: 0.78rem;
  }
  .tot-row {
    display: flex;
    justify-content: space-between;
    color: #374151;
  }
  .tot-row.grand-total {
    font-size: 0.95rem;
    font-weight: 800;
    color: #111827;
    padding: 6px 0;
    border-top: 1px solid #111827;
    border-bottom: 1px solid #111827;
    margin: 4px 0;
  }
  .tot-row.payment-info {
    font-size: 0.72rem;
    color: #6b7280;
  }

  .slip-barcode-area {
    margin-top: 14px;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 4px;
  }
  .simulated-barcode {
    display: flex;
    height: 38px;
    gap: 2px;
    align-items: stretch;
  }
  .bar {
    background: #111827;
    border-radius: 1px;
  }
  .b1 { width: 1.5px; }
  .b2 { width: 2.5px; }
  .b3 { width: 4px; }
  .b4 { width: 5.5px; }
  .barcode-number {
    font-family: var(--font-mono);
    font-size: 0.7rem;
    letter-spacing: 0.1em;
    color: #374151;
  }

  .slip-footer {
    margin-top: 12px;
    text-align: center;
    font-size: 0.75rem;
    font-weight: 600;
    color: #374151;
    line-height: 1.35;
    padding-top: 8px;
    border-top: 1px dashed #d1d5db;
  }

  /* Serrated Jagged Edge (Simulated paper tear) */
  .sawtooth-edge {
    position: absolute;
    left: 0;
    right: 0;
    height: 6px;
    background-size: 10px 6px;
    background-repeat: repeat-x;
  }
  .sawtooth-edge.top {
    top: -6px;
    background-image: linear-gradient(135deg, #ffffff 50%, transparent 50%), linear-gradient(225deg, #ffffff 50%, transparent 50%);
  }
  .sawtooth-edge.bottom {
    bottom: -6px;
    background-image: linear-gradient(315deg, #ffffff 50%, transparent 50%), linear-gradient(45deg, #ffffff 50%, transparent 50%);
  }
</style>
