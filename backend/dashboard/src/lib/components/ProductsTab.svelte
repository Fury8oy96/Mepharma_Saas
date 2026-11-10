<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { apiRequest, addToast, subscribeToSSE } from '../api';
  import PrintLabelsModal from './PrintLabelsModal.svelte';
  import MasterCatalogModal from './MasterCatalogModal.svelte';
  import { generateInternalBarcode, generateBarcodeSVG, detectBarcodeSymbology, BARCODE_SYMBOLOGIES, type BarcodeSymbology } from '../utils/barcode';
  import { generatePharmaceuticalSku } from '../utils/sku';
  import { icons } from '../utils/icons';
  import { t, currentLocale } from '../i18n/store';

  let activeTab: 'approved' | 'pending' = 'approved';
  let products: any[] = [];
  let purchases: any[] = [];
  let categories: any[] = [];
  let suppliers: any[] = [];
  let searchQuery = '';
  let selectedCategory = '';
  let loading = true;
  let unsubSSE: Array<() => void> = [];

  // Print Labels Modal State
  let showPrintModal = false;
  let showMasterModal = false;
  let selectedForPrint: any[] = [];

  function openPrintLabelsModal(singleProduct?: any) {
    if (singleProduct) {
      selectedForPrint = [singleProduct];
    } else {
      selectedForPrint = products.length > 0 ? [...products] : [];
    }
    if (selectedForPrint.length === 0) {
      addToast($currentLocale === 'ar' ? 'لا توجد أدوية متاحة للطباعة.' : 'No products available for barcode printing.', 'warning');
      return;
    }
    showPrintModal = true;
  }

  // Symbology State for Product Form
  let selectedSymbology: BarcodeSymbology = 'EAN13';

  function handleGenerateBarcode() {
    productForm.barcode = generateInternalBarcode(selectedSymbology);
    addToast($currentLocale === 'ar' ? 'تم توليد باركود فريد بنجاح!' : 'Generated unique in-store barcode!', 'success');
  }

  function handleAutoSku() {
    if (isEditing) return;
    const catName = categories.find(c => String(c.id) === String(productForm.category_id))?.name;
    productForm.sku = generatePharmaceuticalSku({
      brandName: productForm.name,
      genericName: productForm.generic_name,
      dosage: productForm.dosage,
      category: catName
    });
  }

  // Modal State
  let showModal = false;
  let isEditing = false;
  let editingId: number | null = null;
  let productForm = {
    name: '',
    generic_name: '',
    dosage: '',
    sku: '',
    barcode: '',
    category_id: '',
    supplier_id: '',
    cost_price: 0,
    selling_price: 0,
    stock_quantity: 0,
    low_stock_threshold: 10,
    expiry_date: '',
    description: ''
  };

  // Merge Products State
  let showMergeModal = false;
  let targetProductId: any = '';
  let sourceProductId: any = '';
  let mergeLoading = false;

  function openMergeModal(initialTargetId?: number) {
    targetProductId = initialTargetId ? String(initialTargetId) : (products[0]?.id ? String(products[0].id) : '');
    sourceProductId = '';
    showMergeModal = true;
  }

  async function handleExecuteMerge() {
    if (!targetProductId || !sourceProductId) {
      addToast($currentLocale === 'ar' ? 'يرجى اختيار الصنف الأساسي والصنف المراد دمجه.' : 'Please select both primary and duplicate items.', 'warning');
      return;
    }
    if (targetProductId === sourceProductId) {
      addToast($currentLocale === 'ar' ? 'لا يمكن دمج الصنف في نفسه.' : 'Cannot merge a product into itself.', 'warning');
      return;
    }

    mergeLoading = true;
    try {
      await apiRequest('/products/merge', {
        method: 'POST',
        body: JSON.stringify({
          target_product_id: parseInt(targetProductId),
          source_product_id: parseInt(sourceProductId)
        })
      });
      addToast($t('toast.success'), 'success');
      showMergeModal = false;
      await loadData();
    } catch (err: any) {
      addToast(err.message || $t('toast.error'), 'error');
    } finally {
      mergeLoading = false;
    }
  }

  // Pending items from unapproved purchases
  $: pendingPurchasesItems = purchases
    .filter(p => p.status === 'pending')
    .flatMap(p => (p.items || []).map((item: any) => ({
      ...item,
      purchase_id: p.id,
      purchase_number: p.invoice_number || `PO-${p.id}`,
      supplier_name: p.supplier?.name || ($currentLocale === 'ar' ? 'مورد عام' : 'General Supplier'),
      created_at: p.created_at
    })));

  $: filteredProducts = products.filter(p => {
    const q = searchQuery.toLowerCase().trim();
    const matchesSearch = !q || 
      p.name?.toLowerCase().includes(q) || 
      p.sku?.toLowerCase().includes(q) || 
      p.barcode?.toLowerCase().includes(q);
    const matchesCategory = !selectedCategory || String(p.category_id) === String(selectedCategory);
    return matchesSearch && matchesCategory;
  });

  async function loadData() {
    loading = true;
    try {
      const [prodRes, purRes, catRes, supRes] = await Promise.allSettled([
        apiRequest('/products?limit=500'),
        apiRequest('/purchases?limit=100'),
        apiRequest('/categories'),
        apiRequest('/suppliers')
      ]);

      if (prodRes.status === 'fulfilled') {
        products = Array.isArray(prodRes.value) ? prodRes.value : (Array.isArray(prodRes.value?.data) ? prodRes.value.data : []);
      }
      if (purRes.status === 'fulfilled') {
        purchases = purRes.value.data || purRes.value || [];
      }
      if (catRes.status === 'fulfilled') {
        categories = catRes.value.data || catRes.value || [];
      }
      if (supRes.status === 'fulfilled') {
        suppliers = supRes.value.data || supRes.value || [];
      }
    } catch (err: any) {
      addToast(err.message || $t('toast.error'), 'error');
    } finally {
      loading = false;
    }
  }

  function openCreateModal() {
    isEditing = false;
    editingId = null;
    productForm = {
      name: '',
      generic_name: '',
      dosage: '',
      sku: '',
      barcode: generateInternalBarcode(selectedSymbology),
      category_id: categories[0]?.id ? String(categories[0].id) : '',
      supplier_id: suppliers[0]?.id ? String(suppliers[0].id) : '',
      cost_price: 0,
      selling_price: 0,
      stock_quantity: 0,
      low_stock_threshold: 10,
      expiry_date: '',
      description: ''
    };
    showModal = true;
  }

  function openEditModal(prod: any) {
    isEditing = true;
    editingId = prod.id;
    
    let brand = prod.name || '';
    let dose = prod.dosage || '';
    if (!dose && brand) {
      const lastSpaceIndex = brand.lastIndexOf(' ');
      if (lastSpaceIndex !== -1) {
        const lastPart = brand.substring(lastSpaceIndex + 1);
        if (/^\d+/.test(lastPart)) {
          brand = brand.substring(0, lastSpaceIndex);
          dose = lastPart;
        }
      }
    }

    const genName = prod.description || prod.generic_name || '';
    selectedSymbology = detectBarcodeSymbology(prod.barcode || prod.sku);

    productForm = {
      name: brand,
      generic_name: genName,
      dosage: dose,
      sku: prod.sku || '',
      barcode: prod.barcode || '',
      category_id: prod.category_id ? String(prod.category_id) : '',
      supplier_id: prod.supplier_id ? String(prod.supplier_id) : '',
      cost_price: prod.cost_price || 0,
      selling_price: prod.selling_price || 0,
      stock_quantity: prod.stock_quantity || 0,
      low_stock_threshold: prod.low_stock_threshold || 10,
      expiry_date: prod.expiry_date ? prod.expiry_date.split('T')[0] : '',
      description: genName
    };
    showModal = true;
  }

  async function handleSaveProduct() {
    if (!productForm.name.trim()) {
      addToast($currentLocale === 'ar' ? 'يرجى إدخال اسم الدواء.' : 'Product name is required.', 'warning');
      return;
    }

    try {
      const fullName = productForm.dosage.trim()
        ? `${productForm.name.trim()} ${productForm.dosage.trim()}`.trim()
        : productForm.name.trim();
      const genericName = productForm.generic_name.trim();

      const payload: any = {
        name: fullName,
        sku: productForm.sku.trim(),
        barcode: productForm.barcode.trim() || null,
        category_id: productForm.category_id ? parseInt(productForm.category_id) : null,
        supplier_id: productForm.supplier_id ? parseInt(productForm.supplier_id) : null,
        cost_price: Number(productForm.cost_price) || 0,
        selling_price: Number(productForm.selling_price) || 0,
        stock_quantity: Number(productForm.stock_quantity) || 0,
        low_stock_threshold: Number(productForm.low_stock_threshold) || 10,
        expiry_date: productForm.expiry_date || null,
        description: genericName || null
      };

      if (isEditing && editingId) {
        await apiRequest(`/products/${editingId}`, {
          method: 'PUT',
          body: JSON.stringify(payload)
        });
        addToast($t('toast.success'), 'success');
      } else {
        await apiRequest('/products', {
          method: 'POST',
          body: JSON.stringify(payload)
        });
        addToast($t('toast.success'), 'success');
      }

      showModal = false;
      await loadData();
    } catch (err: any) {
      addToast(err.message || $t('toast.error'), 'error');
    }
  }

  async function handleDeleteProduct(id: number) {
    const confirmMsg = $currentLocale === 'ar' ? 'هل أنت متأكد من حذف هذا الصنف نهائياً؟' : 'Are you sure you want to permanently delete this product?';
    if (!confirm(confirmMsg)) return;

    try {
      await apiRequest(`/products/${id}`, { method: 'DELETE' });
      addToast($t('toast.success'), 'success');
      await loadData();
    } catch (err: any) {
      addToast(err.message || $t('toast.error'), 'error');
    }
  }

  onMount(() => {
    loadData();
    const unsub = subscribeToSSE((event) => {
      if (['product_created', 'product_updated', 'stock_adjusted', 'purchase_approved'].includes(event.event)) {
        loadData();
      }
    });
    unsubSSE.push(unsub);
  });

  onDestroy(() => {
    unsubSSE.forEach(u => u());
  });

  function formatCurrency(val: number) {
    return Number(val || 0).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  }
</script>

<div class="products-tab-container animate-fade-in">
  <!-- Top Bar -->
  <div class="tab-header">
    <div>
      <h2>{$t('prod.title')}</h2>
      <p class="subtitle">{$t('overview.desc')}</p>
    </div>
    <div class="actions-group">
      <button class="btn btn-secondary" on:click={loadData} title={$t('btn.refresh')}>
        {@html icons.refresh} {$t('btn.refresh')}
      </button>
      <button class="btn btn-secondary" on:click={() => showMasterModal = true} title={$currentLocale === 'ar' ? 'استيراد من الدليل الدوائي المركزي' : 'Import from Central Formulary'}>
        <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="margin-right: 4px;">
          <path d="M4 19.5v-15A2.5 2.5 0 0 1 6.5 2H20v20H6.5a2.5 2.5 0 0 1-2.5-2.5Z"/>
          <path d="M6 6h10"/>
          <path d="M6 10h10"/>
        </svg>
        {$currentLocale === 'ar' ? 'الدليل المركزي' : 'Global Formulary'}
      </button>
      <button class="btn btn-secondary" on:click={() => openPrintLabelsModal()} title={$t('prod.btn.printLabels')}>
        {@html icons.barcode} {$t('prod.btn.printLabels')}
      </button>
      <button class="btn btn-secondary" on:click={() => openMergeModal()} title={$t('prod.btn.merge')}>
        {@html icons.sparkle} {$t('prod.btn.merge')}
      </button>
      <button class="btn btn-primary" on:click={openCreateModal}>
        {@html icons.plus} {$t('prod.btn.addProduct')}
      </button>
    </div>
  </div>

  <!-- Dual Listing Tabs (Vuexy Segmented Buttons) -->
  <div class="dual-tab-selector vuexy-card">
    <button 
      class="tab-btn {activeTab === 'approved' ? 'active' : ''}"
      on:click={() => activeTab = 'approved'}
    >
      <span class="tab-icon">{@html icons.check}</span>
      <span>{$t('prod.tab.approved')}</span>
      <span class="count-pill">{products.length}</span>
    </button>

    <button 
      class="tab-btn {activeTab === 'pending' ? 'active' : ''}"
      on:click={() => activeTab = 'pending'}
    >
      <span class="tab-icon">{@html icons.bell}</span>
      <span>{$t('prod.tab.pending')}</span>
      <span class="count-pill pill-amber">{pendingPurchasesItems.length}</span>
    </button>
  </div>

  {#if activeTab === 'approved'}
    <!-- Approved Products View -->
    <div class="vuexy-card content-panel">
      <!-- Search & Filters -->
      <div class="filters-bar">
        <div class="search-wrapper">
          <span class="search-icon">{@html icons.search}</span>
          <input 
            type="text" 
            class="form-input search-input" 
            placeholder={$t('prod.search')}
            bind:value={searchQuery}
          />
        </div>

        <select class="form-select cat-select" bind:value={selectedCategory}>
          <option value="">{$t('prod.filter.allCategories')} ({categories.length})</option>
          {#each categories as cat}
            <option value={cat.id}>{cat.name}</option>
          {/each}
        </select>
      </div>

      <!-- Products Data Table -->
      <div class="table-container">
        <table class="data-table">
          <thead>
            <tr>
              <th>{$t('prod.th.barcode')}</th>
              <th>{$t('prod.th.product')}</th>
              <th>{$t('prod.th.category')}</th>
              <th>{$t('prod.th.pricing')}</th>
              <th>{$t('prod.th.stock')}</th>
              <th>{$t('purch.th.status')}</th>
              <th>{$t('prod.th.actions')}</th>
            </tr>
          </thead>
          <tbody>
            {#if filteredProducts.length === 0}
              <tr>
                <td colspan="7" class="text-center py-6 text-muted">
                  {$t('table.noData')}
                </td>
              </tr>
            {:else}
              {#each filteredProducts as prod}
                <tr>
                  <td>
                    <div class="sku-cell">
                      <strong>{prod.sku}</strong>
                      {#if prod.barcode}
                        <span class="sub-text">#{prod.barcode}</span>
                      {/if}
                    </div>
                  </td>
                  <td>
                    <span class="prod-name">{prod.name}</span>
                  </td>
                  <td>{categories.find(c => c.id === prod.category_id)?.name || ($currentLocale === 'ar' ? 'عام' : 'General')}</td>
                  <td>
                    <div class="price-cell">
                      <span class="cost-text">{formatCurrency(prod.cost_price)}</span>
                      <strong class="sell-text">{formatCurrency(prod.selling_price)} SDG</strong>
                    </div>
                  </td>
                  <td>
                    <span class="stock-qty {prod.stock_quantity <= prod.low_stock_threshold ? 'low-stock' : ''}">
                      {prod.stock_quantity} {$t('prod.stockUnit')}
                    </span>
                  </td>
                  <td>
                    {#if prod.stock_quantity <= 0}
                      <span class="badge badge-danger">{$t('prod.outOfStockBadge')}</span>
                    {:else if prod.stock_quantity <= prod.low_stock_threshold}
                      <span class="badge badge-pending">{$t('prod.lowStockBadge')}</span>
                    {:else}
                      <span class="badge badge-approved">{$t('prod.inStock')}</span>
                    {/if}
                  </td>
                  <td>
                    <div class="row-actions">
                      <button class="btn-icon" on:click={() => openPrintLabelsModal(prod)} title={$t('prod.btn.printLabels')}>
                        {@html icons.barcode}
                      </button>
                      <button class="btn-icon" on:click={() => openMergeModal(prod.id)} title={$t('prod.btn.merge')}>
                        {@html icons.sparkle}
                      </button>
                      <button class="btn-icon" on:click={() => openEditModal(prod)} title={$t('btn.edit')}>
                        {@html icons.edit}
                      </button>
                      <button class="btn-icon btn-icon-danger" on:click={() => handleDeleteProduct(prod.id)} title={$t('btn.delete')}>
                        {@html icons.trash}
                      </button>
                    </div>
                  </td>
                </tr>
              {/each}
            {/if}
          </tbody>
        </table>
      </div>
    </div>
  {:else}
    <!-- Pending Staged Products from unapproved POs -->
    <div class="vuexy-card content-panel">
      <div class="table-container">
        <table class="data-table">
          <thead>
            <tr>
              <th>{$t('purch.th.poNumber')}</th>
              <th>{$t('prod.th.product')}</th>
              <th>{$t('purch.th.supplier')}</th>
              <th>{$t('prod.th.stock')}</th>
              <th>{$t('purch.th.total')}</th>
              <th>{$t('purch.th.status')}</th>
            </tr>
          </thead>
          <tbody>
            {#if pendingPurchasesItems.length === 0}
              <tr>
                <td colspan="6" class="text-center py-6 text-muted">
                  {$t('table.noData')}
                </td>
              </tr>
            {:else}
              {#each pendingPurchasesItems as item}
                <tr>
                  <td><strong>{item.purchase_number}</strong></td>
                  <td><span class="prod-name">{item.product_name || item.product?.name}</span></td>
                  <td>{item.supplier_name}</td>
                  <td>{item.quantity} {$t('prod.stockUnit')}</td>
                  <td><strong>{formatCurrency((item.unit_cost || 0) * (item.quantity || 1))} SDG</strong></td>
                  <td><span class="badge badge-pending">{$t('purch.status.pending')}</span></td>
                </tr>
              {/each}
            {/if}
          </tbody>
        </table>
      </div>
    </div>
  {/if}
</div>

<!-- Product Add / Edit Modal -->
{#if showModal}
  <div class="modal-backdrop animate-fade-in" on:click|self={() => showModal = false}>
    <div class="modal-card vuexy-card modal-lg animate-scale-up">
      <div class="modal-header">
        <h3>{isEditing ? $t('btn.edit') : $t('prod.btn.addProduct')}</h3>
        <button class="close-btn" on:click={() => showModal = false}>&times;</button>
      </div>

      <form on:submit|preventDefault={handleSaveProduct} class="modal-form">
        <div class="form-row">
          <div class="form-group">
            <label for="p-name">{$t('prod.brandName')} *</label>
            <input id="p-name" class="form-input" type="text" required bind:value={productForm.name} on:input={handleAutoSku} placeholder="Panadol Extra" />
          </div>
          <div class="form-group">
            <label for="p-gen">{$t('prod.genericName')}</label>
            <input id="p-gen" class="form-input" type="text" bind:value={productForm.generic_name} on:input={handleAutoSku} placeholder="Paracetamol" />
          </div>
        </div>

        <div class="form-row">
          <div class="form-group">
            <label for="p-dose">{$t('prod.dosage')}</label>
            <input id="p-dose" class="form-input" type="text" bind:value={productForm.dosage} on:input={handleAutoSku} placeholder="500mg, 1g, 250mg/5ml" />
          </div>
          <div class="form-group">
            <label for="p-sku">{$t('prod.skuFormula')} *</label>
            <div class="barcode-input-group">
              <input id="p-sku" class="form-input" type="text" required bind:value={productForm.sku} />
              <button type="button" class="btn btn-secondary btn-sm" on:click={handleAutoSku} title={$t('prod.regenerateSku')}>
                {@html icons.sync}
              </button>
            </div>
          </div>
        </div>

        <div class="form-row">
          <div class="form-group">
            <label for="p-symbology">{$t('prod.selectSymbology')}</label>
            <select id="p-symbology" class="form-select" bind:value={selectedSymbology} on:change={handleGenerateBarcode}>
              {#each BARCODE_SYMBOLOGIES as sym}
                <option value={sym.id}>{sym.name} ({sym.category})</option>
              {/each}
            </select>
          </div>
          <div class="form-group">
            <label for="p-barcode">{$t('prod.th.barcode')}</label>
            <div class="barcode-input-group">
              <input id="p-barcode" class="form-input" type="text" bind:value={productForm.barcode} placeholder="6291100..." />
              <button type="button" class="btn btn-secondary btn-sm" on:click={handleGenerateBarcode}>
                {$t('prod.genBarcode')}
              </button>
            </div>
          </div>
        </div>

        <!-- Live Vector Barcode Preview -->
        {#if productForm.barcode || productForm.sku}
          <div class="barcode-preview-container">
            <span class="preview-label">{$t('prod.liveBarcodePreview')} ({selectedSymbology}):</span>
            <div class="barcode-svg-wrapper">
              {@html generateBarcodeSVG(productForm.barcode || productForm.sku, { symbology: selectedSymbology, height: 35, barWidth: 1.1, fontSize: 9 })}
            </div>
          </div>
        {/if}

        <div class="form-row">
          <div class="form-group">
            <label for="p-cat">{$t('prod.th.category')}</label>
            <select id="p-cat" class="form-select" bind:value={productForm.category_id} on:change={handleAutoSku}>
              <option value="">{$t('prod.selectCategory')}</option>
              {#each categories as cat}
                <option value={cat.id}>{cat.name}</option>
              {/each}
            </select>
          </div>
          <div class="form-group">
            <label for="p-sup">{$t('purch.th.supplier')}</label>
            <select id="p-sup" class="form-select" bind:value={productForm.supplier_id}>
              <option value="">{$t('prod.selectSupplier')}</option>
              {#each suppliers as sup}
                <option value={sup.id}>{sup.name}</option>
              {/each}
            </select>
          </div>
        </div>

        <div class="form-row">
          <div class="form-group">
            <label for="p-cost">{$t('prod.costPrice')}</label>
            <input id="p-cost" class="form-input" type="number" step="0.01" bind:value={productForm.cost_price} />
          </div>
          <div class="form-group">
            <label for="p-sell">{$t('prod.sellingPrice')} *</label>
            <input id="p-sell" class="form-input" type="number" step="0.01" required bind:value={productForm.selling_price} />
          </div>
        </div>

        <div class="form-row">
          <div class="form-group">
            <label for="p-qty">{$t('prod.stockQuantity')}</label>
            <input id="p-qty" class="form-input" type="number" bind:value={productForm.stock_quantity} />
          </div>
          <div class="form-group">
            <label for="p-low">{$t('prod.stockThreshold')}</label>
            <input id="p-low" class="form-input" type="number" bind:value={productForm.low_stock_threshold} />
          </div>
        </div>

        <div class="modal-footer">
          <button type="button" class="btn btn-secondary" on:click={() => showModal = false}>
            {$t('btn.cancel')}
          </button>
          <button type="submit" class="btn btn-primary">
            {$t('btn.save')}
          </button>
        </div>
      </form>
    </div>
  </div>
{/if}

<!-- Merge Duplicates Modal -->
{#if showMergeModal}
  <div class="modal-backdrop animate-fade-in" on:click|self={() => showMergeModal = false}>
    <div class="modal-card vuexy-card animate-scale-up">
      <div class="modal-header">
        <h3>{$t('prod.btn.merge')}</h3>
        <button class="close-btn" on:click={() => showMergeModal = false}>&times;</button>
      </div>

      <div class="merge-body">
        <p class="merge-hint">
          {$currentLocale === 'ar' ? 'اختر الصنف الأساسي (المعتمد) والصنف المكرر لنقل المخزون والمبيعات إليه تلقائياً.' : 'Select the primary product to retain and the duplicate to absorb. Stock and sales ledger will be consolidated.'}
        </p>

        <div class="form-group">
          <label for="m-target">Primary Item (Keep)</label>
          <select id="m-target" class="form-select" bind:value={targetProductId}>
            {#each products as p}
              <option value={p.id}>{p.name} ({p.sku}) - Stock: {p.stock_quantity}</option>
            {/each}
          </select>
        </div>

        <div class="form-group">
          <label for="m-source">Duplicate Item (Absorb & Delete)</label>
          <select id="m-source" class="form-select" bind:value={sourceProductId}>
            <option value="">-- {$currentLocale === 'ar' ? 'اختر الصنف المكرر' : 'Select Duplicate'} --</option>
            {#each products.filter(p => String(p.id) !== String(targetProductId)) as p}
              <option value={p.id}>{p.name} ({p.sku}) - Stock: {p.stock_quantity}</option>
            {/each}
          </select>
        </div>
      </div>

      <div class="modal-footer">
        <button type="button" class="btn btn-secondary" on:click={() => showMergeModal = false}>
          {$t('btn.cancel')}
        </button>
        <button type="button" class="btn btn-primary" disabled={mergeLoading} on:click={handleExecuteMerge}>
          {mergeLoading ? $t('app.syncing') : $t('prod.btn.merge')}
        </button>
      </div>
    </div>
  </div>
{/if}

<!-- Barcode Print Labels Studio Modal -->
<PrintLabelsModal 
  show={showPrintModal} 
  selectedProducts={selectedForPrint}
  onClose={() => showPrintModal = false}
/>

<MasterCatalogModal
  show={showMasterModal}
  onClose={() => showMasterModal = false}
  onImportSuccess={loadData}
/>

<style>
  .products-tab-container {
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
  .actions-group {
    display: flex;
    align-items: center;
    gap: 10px;
  }

  .dual-tab-selector {
    display: flex;
    padding: 6px;
    gap: 8px;
  }
  .tab-btn {
    flex: 1;
    padding: 10px 16px;
    background: transparent;
    border: none;
    border-radius: var(--radius-sm);
    color: var(--text-primary);
    font-family: inherit;
    font-size: 0.875rem;
    font-weight: 500;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
    transition: all var(--transition);
  }
  .tab-btn:hover {
    background: var(--color-primary-light);
    color: var(--color-primary);
  }
  .tab-btn.active {
    background: var(--color-primary-gradient);
    color: #ffffff;
    box-shadow: var(--shadow-primary);
  }
  .tab-icon {
    display: flex;
    align-items: center;
  }
  .count-pill {
    padding: 2px 8px;
    border-radius: var(--radius-pill);
    background: rgba(255, 255, 255, 0.2);
    font-size: 0.75rem;
    font-weight: 600;
  }
  .pill-amber {
    background: rgba(255, 159, 67, 0.2);
    color: #ff9f43;
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
  .cat-select {
    width: 220px;
  }

  .sku-cell {
    display: flex;
    flex-direction: column;
  }
  .sub-text {
    font-size: 0.75rem;
    color: var(--text-muted);
    font-family: var(--font-mono);
  }
  .prod-name {
    font-weight: 600;
    color: var(--text-heading);
  }
  .price-cell {
    display: flex;
    flex-direction: column;
  }
  .cost-text {
    font-size: 0.75rem;
    color: var(--text-muted);
    text-decoration: line-through;
  }
  .sell-text {
    color: var(--color-success);
  }
  .stock-qty {
    font-weight: 600;
  }
  .stock-qty.low-stock {
    color: var(--color-danger);
  }
  .row-actions {
    display: flex;
    align-items: center;
    gap: 6px;
  }

  /* Form & Modals */
  .modal-form {
    display: flex;
    flex-direction: column;
    gap: 1.25rem;
  }
  .form-row {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 1rem;
  }
  .form-group {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }
  .form-group label {
    font-size: 0.8125rem;
    font-weight: 500;
    color: var(--text-primary);
  }
  .barcode-input-group {
    display: flex;
    gap: 8px;
  }
  .barcode-preview-container {
    background: var(--bg-card);
    border: 1px solid var(--border-color);
    border-radius: 8px;
    padding: 10px 14px;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 6px;
  }
  .preview-label {
    font-size: 0.75rem;
    font-weight: 500;
    color: var(--text-muted);
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }
  .barcode-svg-wrapper {
    background: #ffffff;
    padding: 6px 16px;
    border-radius: 6px;
    box-shadow: 0 1px 3px rgba(0,0,0,0.08);
  }
  .modal-footer {
    display: flex;
    justify-content: flex-end;
    gap: 10px;
    padding-top: 1rem;
    border-top: 1px solid var(--border-color);
  }
  .merge-body {
    display: flex;
    flex-direction: column;
    gap: 1.25rem;
  }
  .merge-hint {
    font-size: 0.875rem;
    color: var(--text-muted);
    line-height: 1.4;
  }
  .text-center { text-align: center; }
  .py-6 { padding-top: 1.5rem; padding-bottom: 1.5rem; }
</style>
