<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { apiRequest, addToast, subscribeToSSE } from '../api';
  import { icons } from '../utils/icons';
  import { t, currentLocale } from '../i18n/store';

  let sales: any[] = [];
  let searchQuery = '';
  let filterPayment = '';
  let loading = true;
  let unsubSSE: Array<() => void> = [];

  // Modal
  let showModal = false;
  let viewingSale: any = null;
  let viewingItems: any[] = [];
  let modalLoading = false;

  async function loadSales() {
    loading = true;
    try {
      const res = await apiRequest('/sales');
      sales = Array.isArray(res) ? res : (Array.isArray(res?.data) ? res.data : []);
    } catch (err: any) {
      addToast(err.message || $t('toast.error'), 'error');
    } finally {
      loading = false;
    }
  }

  onMount(() => {
    loadSales();
    const unsub = subscribeToSSE((event) => {
      if (event.event === 'sale_created') {
        loadSales();
      }
    });
    unsubSSE.push(unsub);
  });

  onDestroy(() => {
    unsubSSE.forEach(u => u());
  });

  $: filteredSales = (Array.isArray(sales) ? sales : []).filter(s => {
    const matchesSearch = !searchQuery ||
      s.invoice_number?.toLowerCase().includes(searchQuery.toLowerCase()) ||
      s.customer_name?.toLowerCase().includes(searchQuery.toLowerCase());
    const matchesPayment = !filterPayment || s.payment_method === filterPayment;
    return matchesSearch && matchesPayment;
  });

  async function openSaleModal(id: number) {
    modalLoading = true;
    showModal = true;
    try {
      const res = await apiRequest(`/sales/${id}`);
      viewingSale = res.sale;
      viewingItems = res.items || [];
    } catch (err: any) {
      addToast(err.message || $t('toast.error'), 'error');
      showModal = false;
    } finally {
      modalLoading = false;
    }
  }

  function formatCurrency(val: number) {
    return Math.round(Number(val || 0)).toLocaleString('en-US') + ' SDG';
  }
</script>

<div class="sales-tab-container animate-fade-in">
  <div class="tab-header">
    <div>
      <h2>{$t('sales.title')}</h2>
      <p class="subtitle">{$t('overview.desc')}</p>
    </div>
    <button class="btn btn-secondary" on:click={loadSales} title={$t('btn.refresh')}>
      {@html icons.refresh} {$t('btn.refresh')}
    </button>
  </div>

  <div class="vuexy-card content-panel">
    <!-- Filters -->
    <div class="filters-bar">
      <div class="search-wrapper">
        <span class="search-icon">{@html icons.search}</span>
        <input 
          type="text" 
          class="form-input search-input" 
          placeholder={$t('sales.search')}
          bind:value={searchQuery}
        />
      </div>
      <select class="form-select payment-select" bind:value={filterPayment}>
        <option value="">{$t('sales.th.payment')} ({$currentLocale === 'ar' ? 'الكل' : 'All'})</option>
        <option value="cash">{$currentLocale === 'ar' ? 'نقدي (Cash)' : 'Cash'}</option>
        <option value="credit">{$currentLocale === 'ar' ? 'آجل / حساب (Credit)' : 'Credit / Account'}</option>
        <option value="card">{$currentLocale === 'ar' ? 'بطاقة بنكية (Card)' : 'Credit/Debit Card'}</option>
      </select>
    </div>

    <!-- Table -->
    {#if loading}
      <div class="loading-state">
        <div class="spinner"></div>
        <p>{$t('table.loading')}</p>
      </div>
    {:else}
      <div class="table-container">
        <table class="data-table">
          <thead>
            <tr>
              <th>{$t('sales.th.invoice')}</th>
              <th>{$t('sales.th.customer')}</th>
              <th>{$t('sales.th.date')}</th>
              <th>{$t('sales.th.payment')}</th>
              <th>{$t('sales.th.total')}</th>
              <th>{$t('purch.th.status')}</th>
              <th>{$t('prod.th.actions')}</th>
            </tr>
          </thead>
          <tbody>
            {#if filteredSales.length === 0}
              <tr>
                <td colspan="7" class="text-center py-6 text-muted">
                  {$t('table.noData')}
                </td>
              </tr>
            {:else}
              {#each filteredSales as s}
                <tr>
                  <td><strong>{s.invoice_number}</strong></td>
                  <td>{s.customer_name || $t('sales.walkIn')}</td>
                  <td>{new Date(s.created_at).toLocaleString($currentLocale === 'ar' ? 'ar-EG' : 'en-US')}</td>
                  <td><span class="badge badge-role">{s.payment_method}</span></td>
                  <td><strong>{formatCurrency(s.total_amount)}</strong></td>
                  <td>
                    {#if s.status === 'completed'}
                      <span class="badge badge-approved">Completed</span>
                    {:else if s.status === 'returned'}
                      <span class="badge badge-danger">Returned</span>
                    {:else}
                      <span class="badge badge-pending">{s.status}</span>
                    {/if}
                  </td>
                  <td>
                    <button class="btn btn-secondary btn-sm" on:click={() => openSaleModal(s.id)}>
                      {$t('sales.viewReceipt')}
                    </button>
                  </td>
                </tr>
              {/each}
            {/if}
          </tbody>
        </table>
      </div>
    {/if}
  </div>

  <!-- Sale Receipt Modal -->
  {#if showModal}
    <div class="modal-backdrop animate-fade-in" on:click|self={() => showModal = false} role="dialog" aria-modal="true">
      <div class="modal-card vuexy-card animate-scale-up">
        <div class="modal-header">
          <div>
            <h3>{$t('sales.viewReceipt')} #{viewingSale?.invoice_number}</h3>
            <span class="sub-text">{new Date(viewingSale?.created_at || '').toLocaleString()} | {$t('sales.th.customer')}: {viewingSale?.customer_name || $t('sales.walkIn')}</span>
          </div>
          <button class="close-btn" on:click={() => showModal = false}>{@html icons.x}</button>
        </div>

        {#if modalLoading}
          <div class="loading-state">
            <div class="spinner"></div>
            <p>{$t('table.loading')}</p>
          </div>
        {:else}
          <div class="modal-body">
            <div class="table-container">
              <table class="data-table">
                <thead>
                  <tr>
                    <th>{$t('prod.th.product')}</th>
                    <th>{$t('prod.th.stock')}</th>
                    <th>Price</th>
                    <th>Total</th>
                  </tr>
                </thead>
                <tbody>
                  {#each viewingItems as item}
                    <tr>
                      <td><strong>{item.product_name}</strong></td>
                      <td>{item.quantity} units</td>
                      <td>{formatCurrency(item.unit_price)}</td>
                      <td><strong>{formatCurrency(item.total_price)}</strong></td>
                    </tr>
                  {/each}
                </tbody>
              </table>
            </div>

            <div class="invoice-summary-card">
              <div class="summary-line">
                <span>{$t('sales.th.subtotal')}:</span>
                <span>{formatCurrency(viewingSale?.subtotal || viewingSale?.total_amount)}</span>
              </div>
              {#if viewingSale?.tax_amount}
                <div class="summary-line">
                  <span>{$t('sales.th.tax')}:</span>
                  <span>{formatCurrency(viewingSale?.tax_amount)}</span>
                </div>
              {/if}
              <div class="summary-line total-highlight">
                <strong>{$t('sales.th.total')}:</strong>
                <strong class="text-success">{formatCurrency(viewingSale?.total_amount)}</strong>
              </div>
            </div>
          </div>

          <div class="modal-actions">
            <button class="btn btn-secondary" on:click={() => showModal = false}>
              {$t('btn.close')}
            </button>
          </div>
        {/if}
      </div>
    </div>
  {/if}
</div>

<style>
  .sales-tab-container {
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

  .content-panel {
    padding: 1.5rem;
    display: flex;
    flex-direction: column;
    gap: 1.25rem;
  }
  .filters-bar {
    display: flex;
    gap: 12px;
  }
  .search-wrapper {
    flex: 1;
    position: relative;
    display: flex;
    align-items: center;
  }
  .search-icon {
    position: absolute;
    left: 12px;
    color: var(--text-muted);
    pointer-events: none;
    display: flex;
    align-items: center;
  }
  body.rtl-mode .search-icon, html[dir="rtl"] .search-icon {
    left: auto;
    right: 12px;
  }
  .search-input {
    padding-left: 36px;
  }
  body.rtl-mode .search-input, html[dir="rtl"] .search-input {
    padding-left: 14px;
    padding-right: 36px;
  }
  .payment-select {
    width: 200px;
  }

  .modal-body {
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }
  .invoice-summary-card {
    background: rgba(22, 29, 49, 0.4);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-sm);
    padding: 12px 16px;
    display: flex;
    flex-direction: column;
    gap: 6px;
    font-size: 0.875rem;
  }
  .summary-line {
    display: flex;
    justify-content: space-between;
    color: var(--text-muted);
  }
  .summary-line.total-highlight {
    font-size: 1rem;
    padding-top: 6px;
    border-top: 1px solid var(--border-color);
  }
  .text-success {
    color: var(--color-success);
  }

  .modal-actions {
    display: flex;
    justify-content: flex-end;
    margin-top: 0.5rem;
  }
  .sub-text {
    font-size: 0.8125rem;
    color: var(--text-muted);
  }

  .loading-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 3rem;
    gap: 1rem;
    color: var(--text-muted);
  }
  .spinner {
    width: 28px;
    height: 28px;
    border: 3px solid var(--border-color);
    border-top-color: var(--color-primary);
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
  }
  @keyframes spin {
    to { transform: rotate(360deg); }
  }
  .text-center { text-align: center; }
  .py-6 { padding-top: 1.5rem; padding-bottom: 1.5rem; }
</style>
