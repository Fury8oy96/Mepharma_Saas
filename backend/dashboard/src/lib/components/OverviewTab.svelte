<script lang="ts">
  import { onMount } from 'svelte';
  import { apiRequest, subscribeToSSE, addToast } from '../api';
  import { icons } from '../utils/icons';
  import { t, currentLocale } from '../i18n/store';

  type DatePreset = 'today' | '7d' | '30d';
  let activePreset: DatePreset = 'today';
  let stats: any = null;
  let loading = true;

  let liveSales = 0;
  let liveSyncQueue = 0;

  function formatCurrency(val: any): string {
    const num = Number(val ?? 0);
    return Math.round(num).toLocaleString('en-US', {
      minimumFractionDigits: 0,
      maximumFractionDigits: 2,
    }) + ' SDG';
  }

  function getDatePresetLabel(preset: DatePreset, locale: string): string {
    if (locale === 'ar') {
      return preset === 'today' ? 'اليوم' : preset === '7d' ? 'آخر 7 أيام' : 'آخر 30 يوماً';
    }
    return preset === 'today' ? 'Today' : preset === '7d' ? 'Last 7 Days' : 'Last 30 Days';
  }

  function getServerDate(serverTime: any, locale: string): string {
    if (!serverTime) return '--';
    return new Date(serverTime).toLocaleString(locale === 'ar' ? 'ar-EG' : 'en-US');
  }

  async function loadOverview() {
    loading = true;
    try {
      const params = new URLSearchParams();
      if (activePreset === '7d') {
        const d = new Date();
        d.setDate(d.getDate() - 7);
        params.set('from', d.toISOString().slice(0, 10));
        params.set('to', new Date().toISOString().slice(0, 10));
      } else if (activePreset === '30d') {
        const d = new Date();
        d.setDate(d.getDate() - 30);
        params.set('from', d.toISOString().slice(0, 10));
        params.set('to', new Date().toISOString().slice(0, 10));
      }

      const res = await apiRequest(`/reports/overview?${params.toString()}`);
      stats = res;
    } catch (err: any) {
      addToast(err.message || ($currentLocale === 'ar' ? 'فشل تحميل لوحة التحكم' : 'Failed to load dashboard'), 'error');
      stats = null;
    } finally {
      loading = false;
    }
  }

  function startSSEListeners() {
    subscribeToSSE('sale_created', () => { liveSales++; });
    subscribeToSSE('sync_event', (data: any) => {
      if (data?.event?.startsWith('sync_')) {
        liveSyncQueue++;
        setTimeout(() => { liveSyncQueue = Math.max(0, liveSyncQueue - 1); }, 3000);
      }
    });
  }

  function getPaymentColor(method: string): string {
    const m = (method || '').toLowerCase();
    if (m.includes('cash')) return 'var(--color-success)';
    if (m.includes('card')) return 'var(--color-primary)';
    if (m.includes('credit')) return 'var(--color-warning)';
    if (m.includes('mobile') || m.includes('bank')) return 'var(--color-info)';
    return 'var(--color-secondary)';
  }

  onMount(() => {
    loadOverview();
    startSSEListeners();
    const interval = setInterval(loadOverview, 60_000);
    return () => clearInterval(interval);
  });
</script>

<div class="overview-dashboard animate-fade-in">
  <!-- Executive Welcome & Telemetry Bar -->
  <div class="vuexy-card hero-banner">
    <div class="hero-content">
      <div class="hero-badge-row">
        <span class="hero-badge">
          <span class="pulse-dot"></span>
          {$t('app.liveTelemetry')}
        </span>
        {#if liveSyncQueue > 0}
          <span class="sync-badge">
            <span class="spinner-mini"></span>
            {$t('app.syncing')}
          </span>
        {/if}
      </div>
      <h2>{$t('overview.title')}</h2>
      <p>{$t('overview.desc')}</p>
    </div>

    <!-- Date Range Switcher & Refresh -->
    <div class="hero-controls">
      <div class="segmented-control">
        {#each [['today', 'overview.filterToday'], ['7d', 'overview.filter7Days'], ['30d', 'overview.filter30Days']] as [val, key]}
          <button
            class="segmented-btn {activePreset === val ? 'active' : ''}"
            on:click={() => { activePreset = val; loadOverview(); }}
          >
            {$t(key)}
          </button>
        {/each}
      </div>

      <button class="btn btn-primary btn-sm refresh-btn" on:click={loadOverview} title={$t('btn.refresh')}>
        {@html icons.refresh}
        <span class="refresh-label">{$t('btn.refresh')}</span>
      </button>
    </div>
  </div>

  {#if loading && !stats}
    <div class="loading-state vuexy-card">
      <div class="spinner"></div>
      <p>{$t('table.loading')}</p>
    </div>
  {:else if !stats}
    <div class="alert alert-danger vuexy-card">
      <span>{@html icons.alertTriangle}</span>
      <span>{$currentLocale === 'ar' ? 'لا توجد بيانات متاحة حالياً' : 'No telemetry data available'}</span>
    </div>
  {:else}
    <!-- SECTION 1: PRIMARY FINANCIAL PILLARS -->
    <div class="financial-pillars-grid">
      <!-- Pillar 1: Sales Revenue -->
      <div class="vuexy-card pillar-card border-primary">
        <div class="pillar-header">
          <div class="pillar-icon-wrap bg-primary-light text-primary">
            {@html icons.dollar}
          </div>
          <span class="badge badge-primary">{stats.sales?.total || 0} {$t('overview.totalSales')}</span>
        </div>
        <div class="pillar-body">
          <span class="pillar-label">{$t('rep.netRevenue')}</span>
          <h3 class="pillar-value text-primary">{formatCurrency(stats.sales?.revenue)}</h3>
          <div class="pillar-footer">
            <span>Gross: {formatCurrency(stats.sales?.grossRevenue)}</span>
            {#if (stats.sales?.refunds || 0) > 0}
              <span class="text-danger">(-{formatCurrency(stats.sales.refunds)} {$t('rep.refunds')})</span>
            {/if}
          </div>
        </div>
      </div>

      <!-- Pillar 2: Net Gross Profit -->
      <div class="vuexy-card pillar-card border-success">
        <div class="pillar-header">
          <div class="pillar-icon-wrap bg-success-light text-success">
            {@html icons.trendingUp}
          </div>
          <span class="badge badge-success">{stats.sales?.profitMarginPct || 0}% {$t('rep.profitMargin')}</span>
        </div>
        <div class="pillar-body">
          <span class="pillar-label">{$t('rep.grossProfit')}</span>
          <h3 class="pillar-value text-success">{formatCurrency(stats.sales?.grossProfit)}</h3>
          <div class="pillar-footer">
            <span>{$t('rep.netProfit')} / Return Margin</span>
          </div>
        </div>
      </div>

      <!-- Pillar 3: Cost of Goods Sold (COGS) -->
      <div class="vuexy-card pillar-card border-warning">
        <div class="pillar-header">
          <div class="pillar-icon-wrap bg-warning-light text-warning">
            {@html icons.shoppingCart}
          </div>
          <span class="badge badge-warning">AOV: {formatCurrency(stats.sales?.aov)}</span>
        </div>
        <div class="pillar-body">
          <span class="pillar-label">{$t('rep.costOfGoods')}</span>
          <h3 class="pillar-value text-warning">{formatCurrency(stats.sales?.costOfGoods)}</h3>
          <div class="pillar-footer">
            <span>Wholesale Inventory Basis</span>
          </div>
        </div>
      </div>

      <!-- Pillar 4: Stock Retail Valuation -->
      <div class="vuexy-card pillar-card border-info">
        <div class="pillar-header">
          <div class="pillar-icon-wrap bg-info-light text-info">
            {@html icons.warehouse}
          </div>
          <span class="badge badge-info">+{formatCurrency(stats.stock?.potentialMargin)} {$t('rep.netProfit')}</span>
        </div>
        <div class="pillar-body">
          <span class="pillar-label">{$t('overview.kpi.stockValuation')}</span>
          <h3 class="pillar-value text-info">{formatCurrency(stats.stock?.retailValue)}</h3>
          <div class="pillar-footer">
            <span>Cost Basis: {formatCurrency(stats.stock?.costValue)}</span>
          </div>
        </div>
      </div>
    </div>

    <!-- SECTION 2: OPERATIONAL METRICS & INVENTORY ALERTS RIBBON -->
    <div class="operations-ribbon-grid">
      <!-- Active Catalog -->
      <div class="vuexy-card op-card">
        <div class="op-icon bg-primary-light text-primary">{@html icons.products}</div>
        <div class="op-data">
          <span class="op-label">{$t('overview.kpi.totalProducts')}</span>
          <div class="op-val">{stats.products?.total || 0} <small class="text-muted">({stats.products?.totalUnits || 0} {$t('prod.stockUnit')})</small></div>
        </div>
      </div>

      <!-- Low Stock Warning -->
      <div class="vuexy-card op-card">
        <div class="op-icon bg-warning-light text-warning">{@html icons.alertTriangle}</div>
        <div class="op-data">
          <span class="op-label">{$t('overview.kpi.lowStock')}</span>
          <div class="op-val text-warning">{stats.products?.lowStock || 0} <small class="text-muted">{$t('overview.kpi.lowStockSub')}</small></div>
        </div>
      </div>

      <!-- Expiring Batches -->
      <div class="vuexy-card op-card">
        <div class="op-icon bg-danger-light text-danger">{@html icons.bell}</div>
        <div class="op-data">
          <span class="op-label">{$t('overview.kpi.expiring')}</span>
          <div class="op-val text-danger">{stats.products?.expiring || 0} <small class="text-muted">({stats.products?.expired || 0} {$t('overview.expiredLabel')})</small></div>
        </div>
      </div>

      <!-- Sourcing & Purchases -->
      <div class="vuexy-card op-card">
        <div class="op-icon bg-info-light text-info">{@html icons.purchases}</div>
        <div class="op-data">
          <span class="op-label">{$t('purch.title')}</span>
          <div class="op-val">{formatCurrency(stats.purchases?.totalCost)} <small class="text-muted">({stats.purchases?.total || 0} {$t('purch.th.poNumber')})</small></div>
        </div>
      </div>
    </div>

    <!-- SECTION 3: REVENUE TRENDS & PAYMENT DISTRIBUTION -->
    <div class="analytics-split-grid">
      <!-- Left Column: Revenue Trend Chart -->
      <div class="vuexy-card analytics-card">
        <div class="card-header-line">
          <div class="header-title-wrap">
            <h4>{@html icons.trendingUp} {$t('overview.revenueTrend')}</h4>
            <span class="badge badge-neutral">{stats.trends?.length || 0} {$t('overview.dateRange')}</span>
          </div>
          <span class="mono-tag text-success font-bold">{formatCurrency(stats.sales?.revenue)} Total</span>
        </div>

        {#if !stats.trends || stats.trends.length === 0}
          <div class="empty-state-box">{$t('table.noData')}</div>
        {:else}
          {@const maxRev = Math.max(...stats.trends.map((t) => t.revenue || 0), 1)}
          <div class="trend-visual-container">
            <div class="trend-bars-wrapper">
              {#each stats.trends as day}
                {@const heightPct = Math.max(8, Math.round((day.revenue / maxRev) * 100))}
                <div class="bar-column" title="{day.date}: {formatCurrency(day.revenue)} ({day.count} sales)">
                  <div class="bar-tooltip">
                    <strong>{formatCurrency(day.revenue)}</strong>
                    <span>{day.count} sales</span>
                  </div>
                  <div class="bar-track">
                    <div class="bar-fill" style="height: {heightPct}%;"></div>
                  </div>
                  <span class="bar-label">{day.date.slice(5)}</span>
                </div>
              {/each}
            </div>
          </div>
        {/if}
      </div>

      <!-- Right Column: Payment Channels Breakdown -->
      <div class="vuexy-card analytics-card">
        <div class="card-header-line">
          <div class="header-title-wrap">
            <h4>{@html icons.creditCard} {$t('rep.paymentBreakdown')}</h4>
          </div>
          <span class="badge badge-neutral">{(stats.todayPaymentBreakdown || []).length} Channels</span>
        </div>

        <div class="payment-channels-list">
          {#if !stats.todayPaymentBreakdown || stats.todayPaymentBreakdown.length === 0}
            <div class="empty-state-box">{$t('table.noData')}</div>
          {:else}
            {#each stats.todayPaymentBreakdown as channel}
              {@const pct = (stats.sales?.revenue || 0) > 0 ? (channel.total / stats.sales.revenue) * 100 : 0}
              {@const channelColor = getPaymentColor(channel.method)}
              <div class="payment-item">
                <div class="payment-meta">
                  <div class="payment-identity">
                    <span class="channel-dot" style="background: {channelColor}"></span>
                    <span class="channel-name">{channel.method.toUpperCase()}</span>
                    <span class="channel-count">({channel.count} sales)</span>
                  </div>
                  <div class="payment-values">
                    <span class="channel-total">{formatCurrency(channel.total)}</span>
                    <span class="channel-pct mono-tag">{pct.toFixed(1)}%</span>
                  </div>
                </div>
                <div class="progress-track">
                  <div class="progress-fill" style="width: {pct}%; background: {channelColor};"></div>
                </div>
              </div>
            {/each}
          {/if}
        </div>
      </div>
    </div>

    <!-- SECTION 4: TOP PERFORMING DRUGS & RECENT SALES FEED -->
    <div class="tables-split-grid">
      <!-- Top Revenue Generating Products -->
      <div class="vuexy-card table-section-card">
        <div class="card-header-line">
          <div class="header-title-wrap">
            <h4>{@html icons.award} {$t('rep.topEarners')}</h4>
          </div>
          <span class="badge badge-success">{(stats.topProducts || []).length} Top SKUs</span>
        </div>

        <div class="table-responsive">
          <table class="data-table">
            <thead>
              <tr>
                <th>#</th>
                <th>Drug Name</th>
                <th>Units</th>
                <th>Revenue</th>
                <th>Profit</th>
                <th>Margin</th>
              </tr>
            </thead>
            <tbody>
              {#if !stats.topProducts || stats.topProducts.length === 0}
                <tr><td colspan="6" class="text-center py-6 text-muted">{$t('table.noData')}</td></tr>
              {:else}
                {#each stats.topProducts as p, idx}
                  <tr>
                    <td>
                      <span class="rank-badge rank-{idx + 1}">{idx + 1}</span>
                    </td>
                    <td><strong class="drug-name">{p.name}</strong></td>
                    <td><span class="badge badge-secondary">{p.unitsSold}</span></td>
                    <td><strong>{formatCurrency(p.revenue)}</strong></td>
                    <td class="text-success font-medium">+{formatCurrency(p.profit)}</td>
                    <td>
                      <span class="badge {p.margin_pct >= 25 ? 'badge-success' : 'badge-warning'}">
                        {p.margin_pct}%
                      </span>
                    </td>
                  </tr>
                {/each}
              {/if}
            </tbody>
          </table>
        </div>
      </div>

      <!-- Recent Completed Invoices -->
      <div class="vuexy-card table-section-card">
        <div class="card-header-line">
          <div class="header-title-wrap">
            <h4>{@html icons.receipt} {$t('overview.recentSales')}</h4>
          </div>
          <span class="badge badge-neutral">10 Latest</span>
        </div>

        <div class="invoices-feed">
          {#if !stats.recentSales || stats.recentSales.length === 0}
            <div class="empty-state-box">{$t('table.noData')}</div>
          {:else}
            {#each stats.recentSales as sale}
              <div class="invoice-item-row">
                <div class="invoice-left">
                  <div class="invoice-num-row">
                    <span class="invoice-num mono-tag">#{sale.invoice_number}</span>
                    <span class="customer-tag">{sale.customer_name}</span>
                  </div>
                  <div class="invoice-meta-sub">
                    <span>Cashier: <strong>{sale.cashier || 'System'}</strong></span>
                    <span>•</span>
                    <span>{getServerDate(sale.created_at, $currentLocale)}</span>
                  </div>
                </div>
                <div class="invoice-right">
                  <span class="invoice-total">{formatCurrency(sale.total_amount)}</span>
                  <span class="badge badge-sm badge-success">{sale.payment_method}</span>
                </div>
              </div>
            {/each}
          {/if}
        </div>
      </div>
    </div>

    <!-- SECTION 5: COMMAND ACTIONS & SYSTEM HEALTH MATRIX -->
    <div class="system-bottom-grid">
      <!-- Quick Action Shortcuts -->
      <div class="vuexy-card action-hub-card">
        <div class="card-header-line">
          <h4>{@html icons.sparkle} {$t('overview.quickActions')}</h4>
        </div>
        <div class="quick-action-buttons">
          <a class="action-tile" href="#/purchases/new">
            <div class="action-tile-icon text-primary">{@html icons.purchases}</div>
            <span class="action-tile-title">{$t('overview.act.newPO')}</span>
          </a>
          <a class="action-tile" href="#/products/new">
            <div class="action-tile-icon text-success">{@html icons.plus}</div>
            <span class="action-tile-title">{$t('overview.act.newDrug')}</span>
          </a>
          <a class="action-tile" href="#/products">
            <div class="action-tile-icon text-warning">{@html icons.barcode}</div>
            <span class="action-tile-title">{$t('overview.act.printLabels')}</span>
          </a>
          <a class="action-tile" href="#/reports">
            <div class="action-tile-icon text-info">{@html icons.reports}</div>
            <span class="action-tile-title">{$t('overview.act.viewReports')}</span>
          </a>
          <a class="action-tile" href="#/users">
            <div class="action-tile-icon text-secondary">{@html icons.users}</div>
            <span class="action-tile-title">{$t('overview.act.manageUsers')}</span>
          </a>
          <a class="action-tile" href="#/settings">
            <div class="action-tile-icon text-primary">{@html icons.settings}</div>
            <span class="action-tile-title">{$t('overview.act.settings')}</span>
          </a>
        </div>
      </div>

      <!-- Server Engine & RBAC Matrix -->
      <div class="vuexy-card system-status-card">
        <div class="card-header-line">
          <h4>{@html icons.activity} {$t('overview.serverEngine')}</h4>
          <span class="badge badge-success">{$t('overview.healthy')}</span>
        </div>
        <div class="system-matrix-list">
          <div class="matrix-item">
            <span class="matrix-label">{$t('overview.uptime')}</span>
            <span class="matrix-value text-success font-mono">{stats.uptime || 'Active'}</span>
          </div>
          <div class="matrix-item">
            <span class="matrix-label">{$t('overview.databaseStatus')}</span>
            <span class="matrix-value text-primary font-medium">PostgreSQL 15 Connected</span>
          </div>
          <div class="matrix-item">
            <span class="matrix-label">{$t('overview.activeSessions')}</span>
            <span class="matrix-value font-mono">{stats.users?.active || 0} active / {stats.users?.total || 0} total</span>
          </div>
          <div class="matrix-item">
            <span class="matrix-label">Team Distribution</span>
            <span class="matrix-value">
              <span class="badge badge-sm badge-primary">{stats.users?.admin || 0} Admin</span>
              <span class="badge badge-sm badge-info">{stats.users?.pharmacist || 0} Pharmacist</span>
              <span class="badge badge-sm badge-secondary">{stats.users?.staff || 0} Cashier</span>
            </span>
          </div>
          <div class="matrix-item">
            <span class="matrix-label">{$t('overview.serverTime')}</span>
            <span class="matrix-value text-muted font-mono">{getServerDate(stats.serverTime, $currentLocale)}</span>
          </div>
        </div>
      </div>
    </div>
  {/if}
</div>

<style>
  .overview-dashboard {
    display: flex;
    flex-direction: column;
    gap: 1.5rem;
  }

  /* Hero Banner */
  .hero-banner {
    display: flex;
    justify-content: space-between;
    align-items: center;
    flex-wrap: wrap;
    gap: 1.5rem;
    padding: 1.75rem 2rem;
    background: linear-gradient(135deg, var(--bg-card) 0%, rgba(115, 103, 240, 0.08) 100%);
    border: 1px solid var(--border-color);
  }
  .hero-badge-row {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    margin-bottom: 0.5rem;
  }
  .hero-badge {
    display: inline-flex;
    align-items: center;
    gap: 0.5rem;
    padding: 4px 10px;
    font-size: 0.75rem;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    border-radius: var(--radius-pill);
    background: var(--color-success-light);
    color: var(--color-success);
  }
  .pulse-dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    background: var(--color-success);
    box-shadow: 0 0 0 0 rgba(40, 199, 111, 0.7);
    animation: pulse 1.8s infinite;
  }
  @keyframes pulse {
    0% { transform: scale(0.95); box-shadow: 0 0 0 0 rgba(40, 199, 111, 0.7); }
    70% { transform: scale(1); box-shadow: 0 0 0 6px rgba(40, 199, 111, 0); }
    100% { transform: scale(0.95); box-shadow: 0 0 0 0 rgba(40, 199, 111, 0); }
  }

  .sync-badge {
    display: inline-flex;
    align-items: center;
    gap: 0.4rem;
    padding: 4px 10px;
    font-size: 0.75rem;
    border-radius: var(--radius-pill);
    background: var(--color-primary-light);
    color: var(--color-primary);
  }
  .spinner-mini {
    width: 12px;
    height: 12px;
    border: 2px solid currentColor;
    border-top-color: transparent;
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
  }

  .hero-content h2 {
    font-size: 1.5rem;
    font-weight: 700;
    margin-bottom: 0.25rem;
    color: var(--text-heading);
  }
  .hero-content p {
    font-size: 0.875rem;
    color: var(--text-muted);
    margin: 0;
  }
  .hero-controls {
    display: flex;
    align-items: center;
    gap: 0.75rem;
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
    padding: 6px 14px;
    border: none;
    background: transparent;
    border-radius: var(--radius-sm);
    color: var(--text-subtle);
    cursor: pointer;
    font-size: 0.85rem;
    font-weight: 600;
    transition: all var(--transition);
  }
  .segmented-btn.active {
    background: var(--color-primary);
    color: #ffffff;
    box-shadow: var(--shadow-primary);
  }
  .refresh-btn {
    display: inline-flex;
    align-items: center;
    gap: 0.4rem;
    padding: 8px 14px;
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
    position: relative;
    overflow: hidden;
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
  .pillar-icon-wrap {
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
  .bg-danger-light { background: var(--color-danger-light); color: var(--color-danger); }

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

  /* Section 2: Operations Ribbon */
  .operations-ribbon-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
    gap: 1rem;
  }
  .op-card {
    display: flex;
    align-items: center;
    gap: 1rem;
    padding: 1rem 1.25rem;
  }
  .op-icon {
    width: 40px;
    height: 40px;
    border-radius: var(--radius-md);
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
  }
  .op-label {
    font-size: 0.75rem;
    font-weight: 600;
    color: var(--text-muted);
    text-transform: uppercase;
  }
  .op-val {
    font-size: 1.15rem;
    font-weight: 700;
    color: var(--text-heading);
  }

  /* Section 3: Analytics Split */
  .analytics-split-grid {
    display: grid;
    grid-template-columns: 3fr 2fr;
    gap: 1.5rem;
  }
  @media (max-width: 992px) {
    .analytics-split-grid { grid-template-columns: 1fr; }
  }

  .analytics-card {
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
  .header-title-wrap {
    display: flex;
    align-items: center;
    gap: 0.6rem;
  }
  .header-title-wrap h4 {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-size: 1.05rem;
    margin: 0;
  }

  /* Trend Visual Bars */
  .trend-visual-container {
    height: 220px;
    display: flex;
    align-items: flex-end;
    padding-top: 1.5rem;
  }
  .trend-bars-wrapper {
    display: flex;
    align-items: flex-end;
    justify-content: space-between;
    width: 100%;
    height: 100%;
    gap: 8px;
  }
  .bar-column {
    display: flex;
    flex-direction: column;
    align-items: center;
    height: 100%;
    flex: 1;
    position: relative;
    cursor: pointer;
  }
  .bar-track {
    width: 100%;
    max-width: 28px;
    height: 100%;
    background: rgba(115, 103, 240, 0.08);
    border-radius: var(--radius-sm);
    display: flex;
    align-items: flex-end;
    overflow: hidden;
  }
  .bar-fill {
    width: 100%;
    background: var(--color-primary-gradient);
    border-radius: var(--radius-sm);
    transition: height 0.4s ease;
  }
  .bar-column:hover .bar-fill {
    filter: brightness(1.2);
  }
  .bar-label {
    font-size: 0.7rem;
    font-family: var(--font-mono);
    color: var(--text-muted);
    margin-top: 6px;
  }
  .bar-tooltip {
    position: absolute;
    top: -36px;
    background: var(--bg-card);
    border: 1px solid var(--border-color);
    box-shadow: var(--card-shadow);
    padding: 3px 8px;
    border-radius: var(--radius-xs);
    font-size: 0.75rem;
    display: none;
    white-space: nowrap;
    z-index: 10;
  }
  .bar-column:hover .bar-tooltip {
    display: flex;
    flex-direction: column;
    align-items: center;
  }

  /* Payment Channels */
  .payment-channels-list {
    display: flex;
    flex-direction: column;
    gap: 1.1rem;
    justify-content: center;
    height: 100%;
  }
  .payment-item {
    display: flex;
    flex-direction: column;
    gap: 0.4rem;
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

  /* Section 4: Tables Split */
  .tables-split-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 1.5rem;
  }
  @media (max-width: 992px) {
    .tables-split-grid { grid-template-columns: 1fr; }
  }
  .table-section-card {
    padding: 1.5rem;
    display: flex;
    flex-direction: column;
  }
  .rank-badge {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 24px;
    height: 24px;
    border-radius: 50%;
    font-size: 0.75rem;
    font-weight: 700;
    background: var(--bg-body);
    border: 1px solid var(--border-color);
  }
  .rank-1 { background: #ffd700; color: #000; border-color: #ffd700; }
  .rank-2 { background: #c0c0c0; color: #000; border-color: #c0c0c0; }
  .rank-3 { background: #cd7f32; color: #fff; border-color: #cd7f32; }

  .drug-name {
    color: var(--text-heading);
    font-size: 0.9rem;
  }

  /* Invoices Feed */
  .invoices-feed {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }
  .invoice-item-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 0.75rem 1rem;
    background: var(--bg-body);
    border: 1px solid var(--border-subtle);
    border-radius: var(--radius-md);
    transition: transform var(--transition), border-color var(--transition);
  }
  .invoice-item-row:hover {
    border-color: var(--color-primary);
    transform: translateX(3px);
  }
  body.rtl-mode .invoice-item-row:hover {
    transform: translateX(-3px);
  }
  .invoice-left {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
  }
  .invoice-num-row {
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }
  .customer-tag {
    font-weight: 600;
    font-size: 0.85rem;
    color: var(--text-heading);
  }
  .invoice-meta-sub {
    font-size: 0.75rem;
    color: var(--text-muted);
    display: flex;
    gap: 0.4rem;
  }
  .invoice-right {
    display: flex;
    flex-direction: column;
    align-items: flex-end;
    gap: 0.25rem;
  }
  .invoice-total {
    font-weight: 700;
    font-size: 0.95rem;
    color: var(--text-heading);
  }

  /* Section 5: Command Actions & System Health */
  .system-bottom-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 1.5rem;
  }
  @media (max-width: 992px) {
    .system-bottom-grid { grid-template-columns: 1fr; }
  }

  .action-hub-card, .system-status-card {
    padding: 1.5rem;
  }
  .quick-action-buttons {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 0.75rem;
  }
  @media (max-width: 600px) {
    .quick-action-buttons { grid-template-columns: repeat(2, 1fr); }
  }

  .action-tile {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 0.5rem;
    padding: 1rem;
    border-radius: var(--radius-md);
    background: var(--bg-body);
    border: 1px solid var(--border-subtle);
    color: var(--text-primary);
    text-decoration: none;
    font-size: 0.8rem;
    font-weight: 600;
    text-align: center;
    transition: all var(--transition);
  }
  .action-tile:hover {
    border-color: var(--color-primary);
    transform: translateY(-2px);
    box-shadow: var(--card-shadow);
  }
  .action-tile-icon {
    width: 32px;
    height: 32px;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .system-matrix-list {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }
  .matrix-item {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 0.6rem 0.8rem;
    background: var(--bg-body);
    border-radius: var(--radius-sm);
    border: 1px solid var(--border-subtle);
    font-size: 0.85rem;
  }
  .matrix-label {
    color: var(--text-muted);
    font-weight: 500;
  }

  .font-mono { font-family: var(--font-mono); }
  .font-bold { font-weight: 700; }
  .font-medium { font-weight: 600; }
  .empty-state-box {
    text-align: center;
    padding: 2.5rem 1rem;
    color: var(--text-muted);
    font-size: 0.875rem;
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
</style>
