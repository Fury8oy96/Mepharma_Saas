<script lang="ts">
  import { onMount } from 'svelte';
  import { apiRequest, addToast } from '../api';
  import { icons } from '../utils/icons';
  import { t, currentLocale } from '../i18n/store';

  type DatePreset = 'today' | '7d' | '30d' | 'month' | 'custom';
  let activePreset: DatePreset = 'today';
  let customStartDate = '';
  let customEndDate = '';

  let summary: any = {};
  let monthly: any[] = [];
  let categoryReports: any[] = [];
  let stockValuation: any = {};
  let loading = true;

  function getDateRange(preset: DatePreset): { from?: string; to?: string } {
    const now = new Date();
    if (preset === 'today') {
      const start = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0);
      const end = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59);
      return { from: start.toISOString(), to: end.toISOString() };
    } else if (preset === '7d') {
      const start = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
      return { from: start.toISOString(), to: now.toISOString() };
    } else if (preset === '30d') {
      const start = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
      return { from: start.toISOString(), to: now.toISOString() };
    } else if (preset === 'month') {
      const start = new Date(now.getFullYear(), now.getMonth(), 1, 0, 0, 0);
      return { from: start.toISOString(), to: now.toISOString() };
    } else if (preset === 'custom' && customStartDate && customEndDate) {
      const start = new Date(customStartDate + 'T00:00:00');
      const end = new Date(customEndDate + 'T23:59:59');
      return { from: start.toISOString(), to: end.toISOString() };
    }
    return {};
  }

  async function loadReports() {
    loading = true;
    try {
      const { from, to } = getDateRange(activePreset);
      const queryParam = from && to ? `?from=${encodeURIComponent(from)}&to=${encodeURIComponent(to)}` : '';

      const [sumRes, monthRes, catRes, valRes] = await Promise.all([
        apiRequest(`/reports/summary${queryParam}`),
        apiRequest('/reports/monthly').catch(() => []),
        apiRequest(`/reports/categories${queryParam}`).catch(() => []),
        apiRequest('/reports/stock-valuation').catch(() => ({}))
      ]);
      summary = sumRes?.data || sumRes || {};
      monthly = Array.isArray(monthRes) ? monthRes : (Array.isArray(monthRes?.data) ? monthRes.data : []);
      categoryReports = Array.isArray(catRes) ? catRes : (Array.isArray(catRes?.data) ? catRes.data : []);
      stockValuation = valRes?.data || valRes || {};
    } catch (err: any) {
      addToast(err.message || $t('toast.error'), 'error');
    } finally {
      loading = false;
    }
  }

  function setPreset(preset: DatePreset) {
    activePreset = preset;
    if (preset !== 'custom') {
      loadReports();
    }
  }

  function handleCustomSearch() {
    if (customStartDate && customEndDate) {
      activePreset = 'custom';
      loadReports();
    }
  }

  function formatCurrency(val: any): string {
    const num = Number(val ?? 0);
    return Math.round(num).toLocaleString('en-US', {
      minimumFractionDigits: 0,
      maximumFractionDigits: 2,
    }) + ' SDG';
  }

  function getPaymentColor(method: string): string {
    const m = (method || '').toLowerCase();
    if (m.includes('cash')) return 'var(--color-success)';
    if (m.includes('card')) return 'var(--color-primary)';
    if (m.includes('credit')) return 'var(--color-warning)';
    if (m.includes('mobile') || m.includes('bank')) return 'var(--color-info)';
    return 'var(--color-secondary)';
  }

  function printReport() {
    window.print();
  }

  onMount(() => {
    const now = new Date();
    const todayStr = now.toISOString().split('T')[0];
    customStartDate = todayStr;
    customEndDate = todayStr;
    loadReports();
  });
</script>

<div class="reports-container animate-fade-in">
  <!-- Executive Financial Header & Advanced Date Filter Bar -->
  <div class="vuexy-card tab-header-card print-hide">
    <div class="tab-header-left">
      <div class="header-badge">
        {@html icons.reports}
        <span>{$t('rep.title')}</span>
      </div>
      <h2>{$t('rep.revenueAnalytics')}</h2>
      <p class="subtitle">Comprehensive income statements, COGS accounting, category profitability, and audit trail.</p>
    </div>

    <!-- Filter Controls Toolbar -->
    <div class="filter-controls">
      <div class="segmented-control">
        <button class="segmented-btn" class:active={activePreset === 'today'} on:click={() => setPreset('today')}>
          {$t('rep.filterToday')}
        </button>
        <button class="segmented-btn" class:active={activePreset === '7d'} on:click={() => setPreset('7d')}>
          {$t('rep.filter7Days')}
        </button>
        <button class="segmented-btn" class:active={activePreset === '30d'} on:click={() => setPreset('30d')}>
          {$t('rep.filter30Days')}
        </button>
        <button class="segmented-btn" class:active={activePreset === 'month'} on:click={() => setPreset('month')}>
          {$t('rep.filterMonth')}
        </button>
      </div>

      <!-- Custom Date Inputs -->
      <div class="custom-range-box">
        <input type="date" class="date-input" bind:value={customStartDate} />
        <span class="range-separator">→</span>
        <input type="date" class="date-input" bind:value={customEndDate} />
        <button class="btn btn-sm btn-primary" on:click={handleCustomSearch} title={$t('btn.search')}>
          {@html icons.search}
        </button>
      </div>

      <button class="btn btn-sm btn-secondary print-action-btn" on:click={printReport} title="Print Financial Report">
        {@html icons.printer}
        <span class="btn-text">Print Report</span>
      </button>

      <button class="btn btn-sm btn-secondary" on:click={loadReports} title={$t('btn.refresh')}>
        {@html icons.refresh}
      </button>
    </div>
  </div>

  {#if loading && !summary.revenue && summary.revenue !== 0}
    <div class="loading-state vuexy-card">
      <div class="spinner"></div>
      <p>{$t('table.loading')}</p>
    </div>
  {:else}
    <!-- SECTION 1: PRIMARY FINANCIAL PILLARS -->
    <div class="financial-pillars-grid">
      <!-- Net Sales Revenue -->
      <div class="vuexy-card pillar-card border-primary">
        <div class="pillar-header">
          <div class="pillar-icon bg-primary-light text-primary">
            {@html icons.dollar}
          </div>
          <span class="badge badge-primary">{summary.total_sales || 0} Invoices</span>
        </div>
        <div class="pillar-body">
          <span class="pillar-label">{$t('rep.netRevenue')}</span>
          <h3 class="pillar-value text-primary">{formatCurrency(summary.net_revenue ?? summary.revenue)}</h3>
          <div class="pillar-footer">
            <span>Gross: {formatCurrency(summary.gross_revenue ?? summary.revenue)}</span>
            {#if (summary.refunds || 0) > 0}
              <span class="text-danger">(-{formatCurrency(summary.refunds)} refunds)</span>
            {/if}
          </div>
        </div>
      </div>

      <!-- Gross Operating Profit -->
      <div class="vuexy-card pillar-card border-success">
        <div class="pillar-header">
          <div class="pillar-icon bg-success-light text-success">
            {@html icons.trendingUp}
          </div>
          <span class="badge badge-success">{summary.profit_margin_pct || 0}% {$t('rep.profitMargin')}</span>
        </div>
        <div class="pillar-body">
          <span class="pillar-label">{$t('rep.grossProfit')}</span>
          <h3 class="pillar-value text-success">{formatCurrency(summary.gross_profit ?? summary.total_profit)}</h3>
          <div class="pillar-footer">
            <span>Net Return on Goods Sold</span>
          </div>
        </div>
      </div>

      <!-- Cost of Goods Sold (COGS) -->
      <div class="vuexy-card pillar-card border-warning">
        <div class="pillar-header">
          <div class="pillar-icon bg-warning-light text-warning">
            {@html icons.shoppingCart}
          </div>
          <span class="badge badge-warning">AOV: {formatCurrency(summary.aov)}</span>
        </div>
        <div class="pillar-body">
          <span class="pillar-label">{$t('rep.costOfGoods')}</span>
          <h3 class="pillar-value text-warning">{formatCurrency(summary.cogs ?? summary.cost_of_goods)}</h3>
          <div class="pillar-footer">
            <span>Purchases Inflow: {formatCurrency(summary.purchases_cost)}</span>
          </div>
        </div>
      </div>

      <!-- Stock Retail Asset Valuation -->
      <div class="vuexy-card pillar-card border-info">
        <div class="pillar-header">
          <div class="pillar-icon bg-info-light text-info">
            {@html icons.warehouse}
          </div>
          <span class="badge badge-info">{stockValuation.total_items || 0} Catalog SKUs</span>
        </div>
        <div class="pillar-body">
          <span class="pillar-label">{$t('overview.kpi.stockValuation')}</span>
          <h3 class="pillar-value text-info">{formatCurrency(stockValuation.total_retail_value)}</h3>
          <div class="pillar-footer">
            <span>Cost Basis: {formatCurrency(stockValuation.total_cost_value)}</span>
          </div>
        </div>
      </div>
    </div>

    <!-- SECTION 2: DEDUCTIONS & SECONDARY METRICS STRIP -->
    <div class="vuexy-card deductions-strip">
      <div class="strip-item">
        <span class="strip-label">{$t('rep.discounts')}</span>
        <span class="strip-val text-warning">{formatCurrency(summary.total_discount)}</span>
      </div>
      <div class="strip-divider"></div>
      <div class="strip-item">
        <span class="strip-label">{$t('rep.taxCollected')}</span>
        <span class="strip-val text-info">{formatCurrency(summary.total_tax)}</span>
      </div>
      <div class="strip-divider"></div>
      <div class="strip-item">
        <span class="strip-label">{$t('rep.refunds')}</span>
        <span class="strip-val text-danger">{formatCurrency(summary.refunds)}</span>
      </div>
      <div class="strip-divider"></div>
      <div class="strip-item">
        <span class="strip-label">{$t('overview.kpi.potentialMargin')}</span>
        <span class="strip-val text-success font-bold">+{formatCurrency(stockValuation.potential_profit)}</span>
      </div>
    </div>

    <!-- SECTION 3: TWO COLUMN ANALYSIS (PAYMENT CHANNELS & TOP DRUG EARNERS) -->
    <div class="analysis-split-grid">
      <!-- Payment Channels Distribution -->
      <div class="vuexy-card section-card">
        <div class="card-header-line">
          <h4>{@html icons.creditCard} {$t('rep.paymentBreakdown')}</h4>
          <span class="badge badge-neutral">{(summary.sales_by_payment || []).length} Channels</span>
        </div>

        <div class="payment-channels-list">
          {#if !summary.sales_by_payment || summary.sales_by_payment.length === 0}
            <div class="empty-state-card">{$t('table.noData')}</div>
          {:else}
            {#each summary.sales_by_payment as p}
              {@const pColor = getPaymentColor(p.method)}
              <div class="payment-item">
                <div class="payment-meta">
                  <div class="payment-identity">
                    <span class="channel-dot" style="background: {pColor}"></span>
                    <strong class="channel-name">{p.method.toUpperCase()}</strong>
                    <span class="channel-count">({p.count} sales)</span>
                  </div>
                  <div class="payment-values">
                    <span class="channel-total">{formatCurrency(p.total)}</span>
                    <span class="mono-tag">{p.percentage || 0}%</span>
                  </div>
                </div>
                <div class="progress-track">
                  <div class="progress-fill" style="width: {p.percentage || 0}%; background: {pColor};"></div>
                </div>
              </div>
            {/each}
          {/if}
        </div>
      </div>

      <!-- Top Earning Products Ranking -->
      <div class="vuexy-card section-card">
        <div class="card-header-line">
          <h4>{@html icons.award} {$t('rep.topEarners')}</h4>
          <span class="badge badge-success">Top Performers</span>
        </div>

        <div class="table-responsive">
          <table class="data-table">
            <thead>
              <tr>
                <th>Drug Name</th>
                <th>Units</th>
                <th>Revenue</th>
                <th>Profit</th>
                <th>Margin</th>
              </tr>
            </thead>
            <tbody>
              {#if !summary.top_products || summary.top_products.length === 0}
                <tr><td colspan="5" class="text-center py-6 text-muted">{$t('table.noData')}</td></tr>
              {:else}
                {#each summary.top_products as tp, i}
                  <tr>
                    <td>
                      <div class="drug-name-cell">
                        <span class="rank-mini">#{i + 1}</span>
                        <strong>{tp.name}</strong>
                      </div>
                    </td>
                    <td><span class="badge badge-secondary">{tp.quantity}</span></td>
                    <td>{formatCurrency(tp.revenue)}</td>
                    <td><strong class="text-success">+{formatCurrency(tp.profit)}</strong></td>
                    <td>
                      <span class="badge {tp.margin_pct >= 25 ? 'badge-success' : 'badge-warning'}">
                        {tp.margin_pct || 0}%
                      </span>
                    </td>
                  </tr>
                {/each}
              {/if}
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <!-- SECTION 4: CATEGORY PROFITABILITY MATRIX -->
    <div class="vuexy-card section-card">
      <div class="card-header-line">
        <h4>{@html icons.categories} {$t('rep.categoryMatrix')}</h4>
        <span class="badge badge-neutral">{categoryReports.length} Categories Analyzed</span>
      </div>

      <div class="table-responsive">
        <table class="data-table">
          <thead>
            <tr>
              <th>{$t('cat.th.name')}</th>
              <th>Units Sold</th>
              <th>{$t('rep.grossRevenue')}</th>
              <th>{$t('rep.costOfGoods')}</th>
              <th>{$t('rep.grossProfit')}</th>
              <th>{$t('rep.marginPct')}</th>
            </tr>
          </thead>
          <tbody>
            {#if categoryReports.length === 0}
              <tr><td colspan="6" class="text-center py-6 text-muted">{$t('table.noData')}</td></tr>
            {:else}
              {#each categoryReports as c}
                <tr>
                  <td><strong class="category-name">{c.category_name || 'General / Uncategorized'}</strong></td>
                  <td><span class="badge badge-secondary">{c.items_sold || 0}</span></td>
                  <td><strong>{formatCurrency(c.revenue)}</strong></td>
                  <td class="text-warning">{formatCurrency(c.cost)}</td>
                  <td><strong class="text-success">+{formatCurrency(c.profit)}</strong></td>
                  <td>
                    <span class="badge {c.margin_pct >= 25 ? 'badge-success' : 'badge-warning'}">
                      {c.margin_pct || 0}%
                    </span>
                  </td>
                </tr>
              {/each}
            {/if}
          </tbody>
        </table>
      </div>
    </div>

    <!-- SECTION 5: 12-MONTH HISTORICAL FINANCIAL LEDGER -->
    <div class="vuexy-card section-card">
      <div class="card-header-line">
        <h4>{@html icons.sales} 12-Month Historical Financial Ledger</h4>
        <span class="badge badge-neutral">{monthly.length} Months Recorded</span>
      </div>

      <div class="table-responsive">
        <table class="data-table">
          <thead>
            <tr>
              <th>Month Period</th>
              <th>Invoices</th>
              <th>Gross Revenue</th>
              <th>Cost of Goods</th>
              <th>Net Profit</th>
              <th>Profit Margin</th>
              <th>Volume Bar</th>
            </tr>
          </thead>
          <tbody>
            {#if monthly.length === 0}
              <tr><td colspan="7" class="text-center py-6 text-muted">{$t('table.noData')}</td></tr>
            {:else}
              {@const maxMRev = Math.max(...monthly.map((m) => m.revenue || 0), 1)}
              {#each monthly as m}
                {@const revBarW = Math.max(5, Math.round((m.revenue / maxMRev) * 100))}
                <tr>
                  <td><strong class="font-mono">{m.month_str || `${m.year}-${m.month}`}</strong></td>
                  <td><span class="badge badge-secondary">{m.sales_count || 0}</span></td>
                  <td><strong>{formatCurrency(m.revenue)}</strong></td>
                  <td class="text-warning">{formatCurrency(m.cost)}</td>
                  <td><strong class="text-success">+{formatCurrency(m.profit)}</strong></td>
                  <td>
                    <span class="badge {m.margin_pct >= 25 ? 'badge-success' : 'badge-warning'}">
                      {m.margin_pct || 0}%
                    </span>
                  </td>
                  <td style="width: 140px;">
                    <div class="progress-track" style="height: 6px;">
                      <div class="progress-fill" style="width: {revBarW}%; background: var(--color-primary);"></div>
                    </div>
                  </td>
                </tr>
              {/each}
            {/if}
          </tbody>
        </table>
      </div>
    </div>
  {/if}
</div>

<style>
  .reports-container {
    display: flex;
    flex-direction: column;
    gap: 1.5rem;
  }

  /* Header Card */
  .tab-header-card {
    padding: 1.5rem 1.75rem;
    display: flex;
    justify-content: space-between;
    align-items: center;
    flex-wrap: wrap;
    gap: 1.25rem;
    background: linear-gradient(135deg, var(--bg-card) 0%, rgba(115, 103, 240, 0.08) 100%);
  }
  .header-badge {
    display: inline-flex;
    align-items: center;
    gap: 0.4rem;
    padding: 3px 8px;
    background: var(--color-primary-light);
    color: var(--color-primary);
    border-radius: var(--radius-xs);
    font-size: 0.75rem;
    font-weight: 700;
    text-transform: uppercase;
    margin-bottom: 0.35rem;
  }
  .tab-header-left h2 {
    font-size: 1.45rem;
    font-weight: 700;
    color: var(--text-heading);
    margin: 0.15rem 0;
  }
  .subtitle {
    font-size: 0.85rem;
    color: var(--text-muted);
    margin: 0;
  }

  .filter-controls {
    display: flex;
    align-items: center;
    gap: 8px;
    flex-wrap: wrap;
  }
  .segmented-control {
    display: flex;
    background: var(--bg-body);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-md);
    padding: 3px;
    gap: 3px;
  }
  .segmented-btn {
    padding: 6px 12px;
    border: none;
    background: transparent;
    border-radius: var(--radius-sm);
    color: var(--text-subtle);
    cursor: pointer;
    font-size: 0.82rem;
    font-weight: 600;
    transition: all var(--transition);
  }
  .segmented-btn.active {
    background: var(--color-primary);
    color: #ffffff;
    box-shadow: var(--shadow-primary);
  }

  .custom-range-box {
    display: flex;
    align-items: center;
    gap: 4px;
  }
  .date-input {
    padding: 6px 10px;
    font-size: 0.82rem;
    background: var(--bg-body);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-sm);
    color: var(--text-primary);
    font-family: var(--font-mono);
  }
  .range-separator {
    color: var(--text-muted);
    font-weight: bold;
    padding: 0 2px;
  }
  .print-action-btn {
    display: inline-flex;
    align-items: center;
    gap: 0.4rem;
  }

  /* Section 1: Financial Pillars */
  .financial-pillars-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
    gap: 1.25rem;
  }
  .pillar-card {
    padding: 1.5rem;
    display: flex;
    flex-direction: column;
    justify-content: space-between;
  }
  .pillar-card.border-primary { border-top: 4px solid var(--color-primary); }
  .pillar-card.border-success { border-top: 4px solid var(--color-success); }
  .pillar-card.border-warning { border-top: 4px solid var(--color-warning); }
  .pillar-card.border-info { border-top: 4px solid var(--color-info); }

  .pillar-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 1rem;
  }
  .pillar-icon {
    width: 44px;
    height: 44px;
    border-radius: var(--radius-md);
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .bg-primary-light { background: var(--color-primary-light); color: var(--color-primary); }
  .bg-success-light { background: var(--color-success-light); color: var(--color-success); }
  .bg-warning-light { background: var(--color-warning-light); color: var(--color-warning); }
  .bg-info-light { background: var(--color-info-light); color: var(--color-info); }

  .pillar-label {
    font-size: 0.8rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.04em;
    color: var(--text-muted);
  }
  .pillar-value {
    font-size: 1.65rem;
    font-weight: 700;
    margin: 0.25rem 0 0.5rem;
    letter-spacing: -0.02em;
  }
  .pillar-footer {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-size: 0.8rem;
    color: var(--text-subtle);
  }

  /* Section 2: Deductions Strip */
  .deductions-strip {
    display: flex;
    justify-content: space-around;
    align-items: center;
    flex-wrap: wrap;
    gap: 1rem;
    padding: 1.25rem 1.5rem;
  }
  .strip-item {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 0.25rem;
    flex: 1;
    min-width: 140px;
  }
  .strip-label {
    font-size: 0.75rem;
    font-weight: 600;
    text-transform: uppercase;
    color: var(--text-muted);
  }
  .strip-val {
    font-size: 1.15rem;
    font-weight: 700;
  }
  .strip-divider {
    width: 1px;
    height: 36px;
    background: var(--border-subtle);
  }
  @media (max-width: 768px) {
    .strip-divider { display: none; }
  }

  /* Section 3: Analysis Split */
  .analysis-split-grid {
    display: grid;
    grid-template-columns: 2fr 3fr;
    gap: 1.5rem;
  }
  @media (max-width: 992px) {
    .analysis-split-grid { grid-template-columns: 1fr; }
  }

  .section-card {
    padding: 1.5rem;
    display: flex;
    flex-direction: column;
  }
  .card-header-line {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 1.25rem;
    padding-bottom: 0.75rem;
    border-bottom: 1px solid var(--border-subtle);
  }
  .card-header-line h4 {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-size: 1.05rem;
    margin: 0;
  }

  /* Payment Channels */
  .payment-channels-list {
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }
  .payment-item {
    display: flex;
    flex-direction: column;
    gap: 0.35rem;
  }
  .payment-meta {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }
  .payment-identity {
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }
  .channel-dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
  }
  .channel-name {
    font-size: 0.85rem;
    font-weight: 600;
  }
  .channel-count {
    font-size: 0.75rem;
    color: var(--text-muted);
  }
  .payment-values {
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }
  .channel-total {
    font-weight: 700;
    font-size: 0.9rem;
  }
  .progress-track {
    width: 100%;
    height: 7px;
    background: var(--border-subtle);
    border-radius: var(--radius-pill);
    overflow: hidden;
  }
  .progress-fill {
    height: 100%;
    border-radius: var(--radius-pill);
    transition: width 0.4s ease;
  }

  .drug-name-cell {
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }
  .rank-mini {
    font-size: 0.75rem;
    font-family: var(--font-mono);
    color: var(--text-muted);
    font-weight: 700;
  }
  .category-name {
    color: var(--text-heading);
    font-size: 0.9rem;
  }

  .font-mono { font-family: var(--font-mono); }
  .font-bold { font-weight: 700; }
  .empty-state-card {
    text-align: center;
    padding: 2.5rem 1rem;
    color: var(--text-muted);
  }

  .loading-state {
    padding: 4rem;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 1rem;
  }
  .spinner {
    width: 36px;
    height: 36px;
    border: 3px solid var(--border-color);
    border-top-color: var(--color-primary);
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
  }
  @keyframes spin { to { transform: rotate(360deg); } }

  /* Print Stylesheet */
  @media print {
    .print-hide { display: none !important; }
    .reports-container { gap: 1rem; }
    .vuexy-card { box-shadow: none; border: 1px solid #ccc; }
    body { background: #fff !important; color: #000 !important; }
  }
</style>
