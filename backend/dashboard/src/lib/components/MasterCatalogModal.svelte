<script lang="ts">
  import { onMount } from 'svelte';
  import { apiRequest, addToast } from '../api';
  import { t, currentLocale } from '../i18n/store';
  import { icons } from '../utils/icons';

  export let show = false;
  export let onClose: () => void = () => {};
  export let onImportSuccess: () => void = () => {};

  interface MasterItem {
    id: number;
    brandName: string;
    genericName: string;
    dosageForm: string;
    strength: string;
    barcode: string | null;
    categoryName: string | null;
    atcCode: string | null;
    prescriptionSchedule: string;
    defaultCostPrice: number;
    defaultSellingPrice: number;
    description: string | null;
  }

  let searchQuery = '';
  let loading = false;
  let importing = false;
  let items: MasterItem[] = [];
  let selectedIds = new Set<number>();
  let initialStock = 20;

  $: if (show) {
    loadMasterCatalog();
  }

  async function loadMasterCatalog() {
    loading = true;
    try {
      const q = encodeURIComponent(searchQuery.trim());
      const res = await apiRequest(`/admin/api/master-catalog?search=${q}&limit=50`);
      // AdonisJS pagination returns data in `res.data`
      items = res.data || res || [];
    } catch (err: any) {
      addToast(err.message || 'Failed to fetch master catalog', 'error');
    } finally {
      loading = false;
    }
  }

  function handleSearchKey(e: KeyboardEvent) {
    if (e.key === 'Enter') {
      loadMasterCatalog();
    }
  }

  function toggleSelect(id: number) {
    if (selectedIds.has(id)) {
      selectedIds.delete(id);
    } else {
      selectedIds.add(id);
    }
    selectedIds = new Set(selectedIds);
  }

  function toggleSelectAll() {
    if (selectedIds.size === items.length) {
      selectedIds.clear();
    } else {
      selectedIds = new Set(items.map((i) => i.id));
    }
    selectedIds = new Set(selectedIds);
  }

  async function handleImport() {
    if (selectedIds.size === 0) {
      addToast($currentLocale === 'ar' ? 'يرجى اختيار دواء واحد على الأقل.' : 'Please select at least one medicine.', 'warning');
      return;
    }

    importing = true;
    try {
      const res = await apiRequest('/admin/api/master-catalog/import', {
        method: 'POST',
        body: JSON.stringify({
          medicineIds: Array.from(selectedIds),
          initialStock: Number(initialStock) || 0,
        }),
      });

      addToast(res.message || 'Medicines imported successfully!', 'success');
      selectedIds.clear();
      selectedIds = new Set();
      onImportSuccess();
      onClose();
    } catch (err: any) {
      addToast(err.message || 'Failed to import medicines', 'error');
    } finally {
      importing = false;
    }
  }

  function formatPrice(cents: number): string {
    return (cents / 100).toFixed(2);
  }
</script>

{#if show}
  <div class="modal-backdrop" on:click|self={onClose}>
    <div class="modal-card master-catalog-modal">
      <div class="modal-header">
        <div class="header-title">
          <div class="icon-wrap">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <path d="M4 19.5v-15A2.5 2.5 0 0 1 6.5 2H20v20H6.5a2.5 2.5 0 0 1-2.5-2.5Z"/>
              <path d="M6 6h10"/>
              <path d="M6 10h10"/>
            </svg>
          </div>
          <div>
            <h3>{$currentLocale === 'ar' ? 'الدليل الدوائي المركزي الموحد' : 'Global Master Drug Formulary'}</h3>
            <p class="subtitle">
              {$currentLocale === 'ar' 
                ? 'استيراد الأدوية المعتمدة رسمياً ببياناتها القياسية وأسعارها إلى صيدليتك' 
                : 'Import standardized master drugs and commercial formulations directly into this branch.'}
            </p>
          </div>
        </div>
        <button class="close-btn" on:click={onClose} aria-label="Close">✕</button>
      </div>

      <!-- Search & Controls Bar -->
      <div class="search-bar">
        <div class="search-input-wrap">
          <span class="search-icon">{@html icons.search}</span>
          <input
            type="text"
            class="form-input"
            placeholder={$currentLocale === 'ar' ? 'بحث بالاسم التجاري أو العلمي أو الباركود...' : 'Search by brand, generic, strength or barcode...'}
            bind:value={searchQuery}
            on:keydown={handleSearchKey}
          />
          {#if searchQuery}
            <button class="clear-search" on:click={() => { searchQuery = ''; loadMasterCatalog(); }}>✕</button>
          {/if}
        </div>
        <button class="btn btn-secondary" on:click={loadMasterCatalog} disabled={loading}>
          {loading ? ($currentLocale === 'ar' ? 'جاري البحث...' : 'Searching...') : ($currentLocale === 'ar' ? 'بحث' : 'Search')}
        </button>
      </div>

      <!-- Master Drug List Table -->
      <div class="formulary-table-container">
        {#if loading}
          <div class="loading-state">
            <div class="spinner"></div>
            <p>{$currentLocale === 'ar' ? 'جاري تحميل الدليل المركزي...' : 'Loading formulary catalog...'}</p>
          </div>
        {:else if items.length === 0}
          <div class="empty-state">
            <p>{$currentLocale === 'ar' ? 'لم يتم العثور على أدوية مطابقة لبحثك.' : 'No formulary medicines found matching your search.'}</p>
          </div>
        {:else}
          <table class="data-table">
            <thead>
              <tr>
                <th style="width: 44px; text-align: center;">
                  <input
                    type="checkbox"
                    checked={selectedIds.size === items.length && items.length > 0}
                    on:change={toggleSelectAll}
                  />
                </th>
                <th>{$currentLocale === 'ar' ? 'الدواء التجاري والعلمي' : 'Brand & Generic'}</th>
                <th>{$currentLocale === 'ar' ? 'الشكل والتركيز' : 'Form & Strength'}</th>
                <th>{$currentLocale === 'ar' ? 'التصنيف' : 'Category'}</th>
                <th>{$currentLocale === 'ar' ? 'التصريح' : 'Schedule'}</th>
                <th>{$currentLocale === 'ar' ? 'السعر المقترح' : 'Ref Price'}</th>
              </tr>
            </thead>
            <tbody>
              {#each items as med}
                <tr class={selectedIds.has(med.id) ? 'selected-row' : ''} on:click={() => toggleSelect(med.id)}>
                  <td style="text-align: center;" on:click|stopPropagation>
                    <input
                      type="checkbox"
                      checked={selectedIds.has(med.id)}
                      on:change={() => toggleSelect(med.id)}
                    />
                  </td>
                  <td>
                    <div class="med-info">
                      <strong class="brand-name">{med.brandName}</strong>
                      <span class="generic-name">{med.genericName}</span>
                      {#if med.barcode}
                        <span class="barcode-tag">#{med.barcode}</span>
                      {/if}
                    </div>
                  </td>
                  <td>
                    <span class="badge badge-subtle">{med.dosageForm}</span>
                    <span class="strength-text">{med.strength}</span>
                  </td>
                  <td>{med.categoryName || '-'}</td>
                  <td>
                    <span class="schedule-pill {med.prescriptionSchedule === 'Rx' ? 'pill-rx' : 'pill-otc'}">
                      {med.prescriptionSchedule}
                    </span>
                  </td>
                  <td>
                    <div class="pricing-info">
                      <strong class="sell-val">${formatPrice(med.defaultSellingPrice)}</strong>
                      <small class="cost-val">Cost: ${formatPrice(med.defaultCostPrice)}</small>
                    </div>
                  </td>
                </tr>
              {/each}
            </tbody>
          </table>
        {/if}
      </div>

      <!-- Modal Footer -->
      <div class="modal-footer">
        <div class="footer-left">
          <label class="stock-label">
            <span>{$currentLocale === 'ar' ? 'الرصيد الافتتاحي للكمية:' : 'Initial Stock Quantity:'}</span>
            <input type="number" min="0" max="9999" class="form-input stock-input" bind:value={initialStock} />
          </label>
          <span class="selected-counter">
            {selectedIds.size} {$currentLocale === 'ar' ? 'أدوية محددة' : 'item(s) selected'}
          </span>
        </div>
        <div class="footer-actions">
          <button class="btn btn-secondary" on:click={onClose} disabled={importing}>
            {$t('btn.cancel')}
          </button>
          <button class="btn btn-primary" on:click={handleImport} disabled={importing || selectedIds.size === 0}>
            {importing ? ($currentLocale === 'ar' ? 'جاري الاستيراد...' : 'Importing...') : ($currentLocale === 'ar' ? `استيراد إلى صيدليتي (${selectedIds.size})` : `Import Selected (${selectedIds.size})`)}
          </button>
        </div>
      </div>
    </div>
  </div>
{/if}

<style>
  .modal-backdrop {
    position: fixed;
    inset: 0;
    background: rgba(15, 23, 42, 0.65);
    backdrop-filter: blur(4px);
    z-index: 9999;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 1.5rem;
  }

  .master-catalog-modal {
    width: 100%;
    max-width: 900px;
    max-height: 85vh;
    background: var(--bg-card, #ffffff);
    border-radius: 12px;
    box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.2);
    display: flex;
    flex-direction: column;
    overflow: hidden;
  }

  .modal-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 1.25rem 1.5rem;
    border-bottom: 1px solid var(--border-color, #e2e8f0);
  }

  .header-title {
    display: flex;
    align-items: center;
    gap: 12px;
  }

  .icon-wrap {
    width: 44px;
    height: 44px;
    border-radius: 10px;
    background: rgba(14, 165, 233, 0.12);
    color: #0284c7;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .header-title h3 {
    margin: 0;
    font-size: 1.2rem;
    font-weight: 700;
  }

  .subtitle {
    margin: 2px 0 0 0;
    font-size: 0.85rem;
    color: var(--text-muted, #64748b);
  }

  .close-btn {
    background: transparent;
    border: none;
    font-size: 1.2rem;
    color: var(--text-muted, #64748b);
    cursor: pointer;
    padding: 6px 10px;
    border-radius: 6px;
  }

  .search-bar {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 1rem 1.5rem;
    background: var(--bg-subtle, #f8fafc);
    border-bottom: 1px solid var(--border-color, #e2e8f0);
  }

  .search-input-wrap {
    flex: 1;
    position: relative;
    display: flex;
    align-items: center;
  }

  .search-icon {
    position: absolute;
    left: 12px;
    color: #94a3b8;
    pointer-events: none;
  }

  .search-input-wrap input {
    width: 100%;
    padding-left: 36px;
    padding-right: 32px;
    height: 40px;
    border: 1px solid var(--border-color, #cbd5e1);
    border-radius: 8px;
    font-size: 0.95rem;
  }

  .clear-search {
    position: absolute;
    right: 10px;
    background: none;
    border: none;
    cursor: pointer;
    color: #94a3b8;
  }

  .formulary-table-container {
    flex: 1;
    overflow-y: auto;
    min-height: 280px;
    max-height: 420px;
  }

  .data-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 0.9rem;
  }

  .data-table th {
    position: sticky;
    top: 0;
    background: var(--bg-card, #ffffff);
    padding: 10px 14px;
    text-align: left;
    font-weight: 600;
    color: #475569;
    border-bottom: 2px solid var(--border-color, #e2e8f0);
    z-index: 10;
  }

  .data-table td {
    padding: 10px 14px;
    border-bottom: 1px solid var(--border-color, #f1f5f9);
    cursor: pointer;
  }

  .data-table tr:hover {
    background: rgba(241, 245, 249, 0.8);
  }

  .selected-row {
    background: rgba(14, 165, 233, 0.08) !important;
  }

  .med-info {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  .brand-name {
    font-weight: 600;
    color: var(--text-color, #0f172a);
  }

  .generic-name {
    font-size: 0.8rem;
    color: #64748b;
  }

  .barcode-tag {
    font-size: 0.75rem;
    font-family: monospace;
    color: #0284c7;
  }

  .badge-subtle {
    padding: 2px 6px;
    border-radius: 4px;
    background: #e2e8f0;
    font-size: 0.75rem;
    font-weight: 500;
  }

  .strength-text {
    margin-left: 6px;
    font-size: 0.82rem;
    color: #334155;
  }

  .schedule-pill {
    display: inline-block;
    padding: 3px 8px;
    border-radius: 9999px;
    font-size: 0.75rem;
    font-weight: 700;
  }

  .pill-rx {
    background: #fee2e2;
    color: #dc2626;
  }

  .pill-otc {
    background: #dcfce7;
    color: #16a34a;
  }

  .pricing-info {
    display: flex;
    flex-direction: column;
  }

  .sell-val {
    color: #047857;
    font-weight: 700;
  }

  .cost-val {
    font-size: 0.75rem;
    color: #94a3b8;
  }

  .loading-state, .empty-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 3rem;
    color: #64748b;
  }

  .spinner {
    width: 32px;
    height: 32px;
    border: 3px solid #e2e8f0;
    border-top-color: #0284c7;
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
    margin-bottom: 12px;
  }

  @keyframes spin {
    to { transform: rotate(360deg); }
  }

  .modal-footer {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 1rem 1.5rem;
    border-top: 1px solid var(--border-color, #e2e8f0);
    background: var(--bg-card, #ffffff);
  }

  .footer-left {
    display: flex;
    align-items: center;
    gap: 16px;
  }

  .stock-label {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 0.88rem;
    font-weight: 500;
  }

  .stock-input {
    width: 75px;
    height: 34px;
    padding: 4px 8px;
    border: 1px solid #cbd5e1;
    border-radius: 6px;
  }

  .selected-counter {
    font-size: 0.85rem;
    font-weight: 600;
    color: #0284c7;
  }

  .footer-actions {
    display: flex;
    gap: 10px;
  }
</style>
