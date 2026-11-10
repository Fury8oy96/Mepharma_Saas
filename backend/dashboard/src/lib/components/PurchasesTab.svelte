<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { apiRequest, addToast, subscribeToSSE } from '../api';
  import { icons } from '../utils/icons';
  import { t, currentLocale } from '../i18n/store';

  let purchases: any[] = [];
  let suppliers: any[] = [];
  let categories: any[] = [];
  let products: any[] = [];
  let filterStatus = 'all';
  let loading = true;
  let unsubSSE: Array<() => void> = [];

  // View / Audit Modal
  let showViewModal = false;
  let viewingPurchase: any = null;
  let viewingItems: any[] = [];
  let modalLoading = false;

  // Approval & Product Configuration Modal
  let showApproveModal = false;
  let approvingPurchase: any = null;
  let approvingItems: any[] = [];
  let selectedSupplierId: number | null = null;
  let isSavingApproval = false;

  // Edit Purchase Order Modal
  let showEditModal = false;
  let editingPurchase: any = null;
  let editingItems: any[] = [];
  let editingSupplierId: number | null = null;
  let editingNotes: string = '';
  let isSavingEdit = false;

  // Create Purchase Modal
  let showCreateModal = false;
  let isCreatingPurchase = false;
  let createForm = {
    supplier_id: '',
    status: 'approved',
    items: [
      { product_id: '', product_name: '', quantity: 10, cost_price: 1000 }
    ]
  };

  function openCreateModal() {
    createForm = {
      supplier_id: suppliers[0]?.id || '',
      status: 'approved',
      items: [
        { product_id: '', product_name: '', quantity: 10, cost_price: 1000 }
      ]
    };
    showCreateModal = true;
  }

  function addCreateItemRow() {
    createForm.items = [
      ...createForm.items,
      { product_id: '', product_name: '', quantity: 1, cost_price: 0 }
    ];
  }

  function removeCreateItemRow(index: number) {
    if (createForm.items.length <= 1) return;
    createForm.items = createForm.items.filter((_, i) => i !== index);
  }

  function handleProductSelect(item: any, productId: any) {
    item.product_id = productId;
    const existing = products.find(p => String(p.id) === String(productId));
    if (existing) {
      item.product_name = existing.name;
      item.cost_price = existing.cost_price || 0;
    }
  }

  async function handleCreatePurchase() {
    if (!createForm.items || createForm.items.length === 0) {
      addToast($currentLocale === 'ar' ? 'يرجى إضافة صنف واحد على الأقل.' : 'Please add at least one line item.', 'warning');
      return;
    }

    const invalid = createForm.items.some(it => !it.product_name && !it.product_id);
    if (invalid) {
      addToast($currentLocale === 'ar' ? 'يرجى تحديد اسم أو صنف لجميع البنود.' : 'Please select or name all items.', 'warning');
      return;
    }

    isCreatingPurchase = true;
    try {
      const payload = {
        supplier_id: createForm.supplier_id ? parseInt(createForm.supplier_id) : null,
        status: createForm.status || 'approved',
        items: createForm.items.map(it => ({
          product_id: it.product_id ? parseInt(it.product_id) : null,
          product_name: it.product_name || null,
          quantity: Math.max(1, Number(it.quantity) || 1),
          unit_cost: Math.round(Number(it.cost_price) || 0)
        }))
      };

      await apiRequest('/purchases', {
        method: 'POST',
        body: JSON.stringify(payload)
      });

      addToast($t('toast.success'), 'success');
      showCreateModal = false;
      await loadData();
    } catch (err: any) {
      addToast(err.message || $t('toast.error'), 'error');
    } finally {
      isCreatingPurchase = false;
    }
  }

  $: filteredPurchases = purchases.filter(p => {
    if (filterStatus === 'all') return true;
    return p.status === filterStatus;
  });

  async function loadData() {
    loading = true;
    try {
      const [purchRes, supRes, catRes, prodRes] = await Promise.allSettled([
        apiRequest('/purchases'),
        apiRequest('/suppliers'),
        apiRequest('/categories'),
        apiRequest('/products?limit=500')
      ]);

      if (purchRes.status === 'fulfilled') {
        purchases = Array.isArray(purchRes.value) ? purchRes.value : (Array.isArray(purchRes.value?.data) ? purchRes.value.data : []);
      }
      if (supRes.status === 'fulfilled') {
        suppliers = Array.isArray(supRes.value) ? supRes.value : (Array.isArray(supRes.value?.data) ? supRes.value.data : []);
      }
      if (catRes.status === 'fulfilled') {
        categories = Array.isArray(catRes.value) ? catRes.value : (Array.isArray(catRes.value?.data) ? catRes.value.data : []);
      }
      if (prodRes.status === 'fulfilled') {
        products = Array.isArray(prodRes.value) ? prodRes.value : (Array.isArray(prodRes.value?.data) ? prodRes.value.data : []);
      }
    } catch (err: any) {
      addToast(err.message || $t('toast.error'), 'error');
    } finally {
      loading = false;
    }
  }

  onMount(() => {
    loadData();
    const unsub = subscribeToSSE((event) => {
      if (['purchase_created', 'purchase_approved', 'product_created', 'product_updated'].includes(event.event)) {
        loadData();
      }
    });
    unsubSSE.push(unsub);
  });

  onDestroy(() => {
    unsubSSE.forEach(u => u());
  });

  async function openViewModal(purchaseId: number) {
    showViewModal = true;
    modalLoading = true;
    try {
      const p = await apiRequest(`/purchases/${purchaseId}`);
      viewingPurchase = p;
      viewingItems = p.items || [];
    } catch (err: any) {
      addToast(err.message || $t('toast.error'), 'error');
      showViewModal = false;
    } finally {
      modalLoading = false;
    }
  }

  async function openApproveModal(purchase: any) {
    modalLoading = true;
    showApproveModal = true;
    try {
      const full = await apiRequest(`/purchases/${purchase.id}`);
      approvingPurchase = full;
      selectedSupplierId = full.supplier_id || (suppliers.length > 0 ? suppliers[0].id : null);

      approvingItems = (full.items || []).map((item: any) => {
        const cost = item.unit_cost || 0;
        const defaultMargin = 25;
        const sell = Math.round(cost * (1 + defaultMargin / 100));
        return {
          id: item.id,
          product_id: item.product_id,
          product_name: item.product_name || (item.product ? item.product.name : 'Unknown Product'),
          quantity: item.quantity,
          cost_price: cost,
          margin_percent: defaultMargin,
          selling_price: sell,
          category_id: categories.length > 0 ? categories[0].id : null,
          category_name: categories.length > 0 ? categories[0].name : 'General',
          sku: `SKU-${Math.floor(100000 + Math.random() * 900000)}`,
          barcode: '',
        };
      });
    } catch (err: any) {
      addToast(err.message || $t('toast.error'), 'error');
      showApproveModal = false;
    } finally {
      modalLoading = false;
    }
  }

  function handleCostOrMarginChange(item: any) {
    const cost = Number(item.cost_price || 0);
    const margin = Number(item.margin_percent || 0);
    if (cost > 0 && margin >= 0) {
      item.selling_price = Math.round(cost * (1 + margin / 100));
    }
  }

  async function submitApproval() {
    if (!approvingPurchase) return;
    isSavingApproval = true;

    try {
      const resolve_items = approvingItems.map(it => ({
        item_id: it.id,
        product_id: it.product_id,
        product_name: it.product_name,
        category_id: it.category_id,
        category_name: it.category_name,
        cost_price: Math.round(Number(it.cost_price || 0)),
        margin_percent: Number(it.margin_percent || 0),
        selling_price: Math.round(Number(it.selling_price || 0)),
        sku: it.sku,
        barcode: it.barcode || null,
      }));

      await apiRequest(`/purchases/${approvingPurchase.id}/approve`, {
        method: 'PUT',
        body: JSON.stringify({
          supplier_id: selectedSupplierId,
          resolve_items
        })
      });

      addToast($t('toast.success'), 'success');
      showApproveModal = false;
      if (showViewModal) showViewModal = false;
      await loadData();
    } catch (err: any) {
      addToast(err.message || $t('toast.error'), 'error');
    } finally {
      isSavingApproval = false;
    }
  }

  async function openEditModal(purchase: any) {
    editingPurchase = purchase;
    editingSupplierId = purchase.supplier_id || null;
    editingNotes = purchase.notes || '';

    if (!purchase.items || purchase.items.length === 0) {
      modalLoading = true;
      try {
        const full = await apiRequest('/purchases/' + purchase.id);
        editingPurchase = full;
        editingSupplierId = full.supplier_id || null;
        editingNotes = full.notes || '';
        editingItems = (full.items || []).map((it: any) => ({
          id: it.id,
          product_id: it.product_id || (it.productId ?? null),
          product_name: it.product_name || (it.productName ?? ''),
          quantity: it.quantity || 1,
          unit_cost: it.unit_cost ?? (it.cost_price ?? (it.unitCost ?? 0))
        }));
      } catch (err: any) {
        addToast(err.message || $t('toast.error'), 'error');
      } finally {
        modalLoading = false;
      }
    } else {
      editingItems = purchase.items.map((it: any) => ({
        id: it.id,
        product_id: it.product_id || (it.productId ?? null),
        product_name: it.product_name || (it.productName ?? ''),
        quantity: it.quantity || 1,
        unit_cost: it.unit_cost ?? (it.cost_price ?? (it.unitCost ?? 0))
      }));
    }

    if (editingItems.length === 0) {
      editingItems = [{ id: Date.now(), product_id: null, product_name: '', quantity: 1, unit_cost: 0 }];
    }
    showEditModal = true;
  }

  function addEditingItem() {
    editingItems = [
      ...editingItems,
      { id: Date.now(), product_id: null, product_name: '', quantity: 10, unit_cost: 1000 }
    ];
  }

  function removeEditingItem(index: number) {
    if (editingItems.length <= 1) {
      addToast($currentLocale === 'ar' ? 'يجب أن يحتوي أمر الشراء على بند واحد على الأقل' : 'Purchase order must have at least one line item', 'warning');
      return;
    }
    editingItems = editingItems.filter((_, i) => i !== index);
  }

  function onEditingProductSelect(index: number, pId: any) {
    const prod = products.find(p => String(p.id) === String(pId));
    if (prod) {
      editingItems[index].product_id = prod.id;
      editingItems[index].product_name = prod.name;
      if (!editingItems[index].unit_cost || editingItems[index].unit_cost === 0) {
        editingItems[index].unit_cost = prod.cost_price || 0;
      }
      editingItems = [...editingItems];
    }
  }

  $: editingGrandTotal = editingItems.reduce((acc, it) => acc + (Number(it.unit_cost || 0) * Math.max(1, Number(it.quantity || 1))), 0);

  async function handleSaveEdit() {
    if (!editingPurchase) return;

    for (const it of editingItems) {
      if (!it.product_name || it.product_name.trim().length === 0) {
        addToast($currentLocale === 'ar' ? 'يرجى إدخال اسم الصنف لجميع البنود' : 'Please provide a valid product name for all items', 'error');
        return;
      }
      if (!it.quantity || it.quantity < 1) {
        addToast($currentLocale === 'ar' ? 'الكمية يجب أن تكون 1 أو أكثر' : 'Quantity must be at least 1', 'error');
        return;
      }
    }

    isSavingEdit = true;
    try {
      const payload = {
        supplier_id: editingSupplierId ? parseInt(String(editingSupplierId)) : null,
        notes: editingNotes,
        items: editingItems.map(it => ({
          product_id: it.product_id ? parseInt(String(it.product_id)) : null,
          product_name: it.product_name,
          quantity: Math.max(1, Number(it.quantity) || 1),
          cost_price: Math.round(Number(it.unit_cost) || 0)
        }))
      };

      await apiRequest('/purchases/' + editingPurchase.id, {
        method: 'PUT',
        body: JSON.stringify(payload)
      });

      addToast($currentLocale === 'ar' ? 'تم تحديث أمر الشراء بنجاح' : 'Purchase order updated successfully', 'success');
      showEditModal = false;
      await loadData();
    } catch (err: any) {
      addToast(err.message || $t('toast.error'), 'error');
    } finally {
      isSavingEdit = false;
    }
  }

  function formatCurrency(val: number) {
    return Math.round(Number(val || 0)).toLocaleString('en-US') + ' SDG';
  }
</script>

<div class="purchases-container animate-fade-in">
  <div class="tab-header">
    <div>
      <h2>{$t('purch.title')}</h2>
      <p class="subtitle">{$t('overview.desc')}</p>
    </div>
    <div class="actions-group">
      <button class="btn btn-secondary" on:click={loadData} title={$t('btn.refresh')}>
        {@html icons.refresh} {$t('btn.refresh')}
      </button>
      <button class="btn btn-primary" on:click={openCreateModal}>
        {@html icons.plus} {$t('purch.btn.newPO')}
      </button>
    </div>
  </div>

  <!-- Filters and Stats Bar (Vuexy Segmented Buttons) -->
  <div class="vuexy-card filters-panel">
    <div class="status-filters">
      <button 
        class="filter-pill {filterStatus === 'all' ? 'active' : ''}" 
        on:click={() => filterStatus = 'all'}
      >
        {$t('purch.filter.all')} ({purchases.length})
      </button>
      <button 
        class="filter-pill pill-amber {filterStatus === 'pending' ? 'active' : ''}" 
        on:click={() => filterStatus = 'pending'}
      >
        {$t('purch.filter.pending')} ({purchases.filter(p => p.status === 'pending').length})
      </button>
      <button 
        class="filter-pill pill-emerald {filterStatus === 'approved' ? 'active' : ''}" 
        on:click={() => filterStatus = 'approved'}
      >
        {$t('purch.filter.approved')} ({purchases.filter(p => p.status === 'approved').length})
      </button>
    </div>
  </div>

  <!-- Orders Table -->
  <div class="vuexy-card content-panel">
    {#if loading}
      <div class="loading-state">
        <div class="spinner"></div>
        <p>{$t('table.loading')}</p>
      </div>
    {:else if filteredPurchases.length === 0}
      <div class="empty-state">
        <p>{$t('table.noData')}</p>
      </div>
    {:else}
      <div class="table-container">
        <table class="data-table">
          <thead>
            <tr>
              <th>{$t('purch.th.poNumber')}</th>
              <th>{$t('purch.th.date')}</th>
              <th>{$t('purch.th.supplier')}</th>
              <th>{$t('purch.th.total')}</th>
              <th>{$t('purch.th.status')}</th>
              <th class="text-right">{$t('prod.th.actions')}</th>
            </tr>
          </thead>
          <tbody>
            {#each filteredPurchases as p}
              <tr>
                <td>
                  <strong>{p.invoice_number}</strong>
                </td>
                <td>{new Date(p.purchase_date).toLocaleDateString($currentLocale === 'ar' ? 'ar-EG' : 'en-US')}</td>
                <td>
                  {#if p.supplier_name}
                    <span>{p.supplier_name}</span>
                  {:else}
                    <span class="badge badge-pending">{$currentLocale === 'ar' ? 'مورد غير محدد' : 'Unassigned Supplier'}</span>
                  {/if}
                </td>
                <td><strong>{formatCurrency(p.total_amount)}</strong></td>
                <td>
                  {#if p.status === 'approved'}
                    <span class="badge badge-approved">{$t('purch.status.approved')}</span>
                  {:else}
                    <span class="badge badge-pending">{$t('purch.status.pending')}</span>
                  {/if}
                </td>
                <td class="text-right">
                  <div class="row-actions">
                    <button class="btn btn-secondary btn-sm" on:click={() => openViewModal(p.id)}>
                      {$t('purch.viewPO')}
                    </button>
                    {#if p.status === 'pending'}
                      <button class="btn btn-outline-warning btn-sm" on:click={() => openEditModal(p)} title="Edit items and quantities">
                        {$currentLocale === 'ar' ? 'تعديل البنود' : 'Edit Items'}
                      </button>
                      <button class="btn btn-primary btn-sm" on:click={() => openApproveModal(p)}>
                        {$t('purch.approvePO')}
                      </button>
                    {/if}
                  </div>
                </td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
    {/if}
  </div>
</div>

<!-- View Purchase Order Modal -->
{#if showViewModal}
  <div class="modal-backdrop animate-fade-in" on:click|self={() => showViewModal = false} role="dialog" aria-modal="true">
    <div class="modal-card vuexy-card modal-lg animate-scale-up">
      <div class="modal-header">
        <div>
          <h3>{$t('purch.viewPO')}</h3>
          <p class="sub-text">PO #{viewingPurchase?.invoice_number || ''}</p>
        </div>
        <button class="close-btn" on:click={() => showViewModal = false}>&times;</button>
      </div>

      {#if modalLoading}
        <div class="loading-state">
          <div class="spinner"></div>
          <p>{$t('table.loading')}</p>
        </div>
      {:else if viewingPurchase}
        <div class="table-container">
          <table class="data-table">
            <thead>
              <tr>
                <th>{$t('prod.th.product')}</th>
                <th>{$t('prod.th.stock')}</th>
                <th>Cost Price</th>
                <th>Line Total</th>
              </tr>
            </thead>
            <tbody>
              {#each viewingItems as item}
                <tr>
                  <td><strong>{item.product_name || (item.product ? item.product.name : 'Unknown')}</strong></td>
                  <td>{item.quantity} units</td>
                  <td>{formatCurrency(item.unit_cost)}</td>
                  <td><strong>{formatCurrency((item.unit_cost || 0) * (item.quantity || 1))}</strong></td>
                </tr>
              {/each}
            </tbody>
          </table>
        </div>

        <div class="modal-actions">
          <button class="btn btn-secondary" on:click={() => showViewModal = false}>
            {$t('btn.close')}
          </button>
          {#if viewingPurchase.status === 'pending'}
            <button class="btn btn-warning" on:click={() => { const p = viewingPurchase; showViewModal = false; openEditModal(p); }}>
              {$currentLocale === 'ar' ? 'تعديل بنود الأمر' : 'Edit Order Items'}
            </button>
            <button class="btn btn-primary" on:click={() => { showViewModal = false; openApproveModal(viewingPurchase); }}>
              {$t('purch.approvePO')}
            </button>
          {/if}
        </div>
      {/if}
    </div>
  </div>
{/if}

<!-- Configure & Approve Product Modal -->
{#if showApproveModal}
  <div class="modal-backdrop animate-fade-in" on:click|self={() => showApproveModal = false} role="dialog" aria-modal="true">
    <div class="modal-card vuexy-card modal-lg animate-scale-up">
      <div class="modal-header">
        <div>
          <h3>{$t('purch.approvePO')}</h3>
          <p class="sub-text">Invoice #{approvingPurchase?.invoice_number}</p>
        </div>
        <button class="close-btn" on:click={() => showApproveModal = false}>&times;</button>
      </div>

      <div class="approval-form">
        <div class="form-group">
          <label for="approve-sup">Assigned Supplier:</label>
          <select id="approve-sup" class="form-select" bind:value={selectedSupplierId}>
            {#each suppliers as s}
              <option value={s.id}>{s.name}</option>
            {/each}
          </select>
        </div>

        <div class="table-container">
          <table class="data-table">
            <thead>
              <tr>
                <th>Product Name</th>
                <th>Category</th>
                <th>Cost</th>
                <th>Margin %</th>
                <th>Sell Price</th>
              </tr>
            </thead>
            <tbody>
              {#each approvingItems as item}
                <tr>
                  <td><input class="form-input table-input" type="text" bind:value={item.product_name} /></td>
                  <td>
                    <select class="form-select table-select" bind:value={item.category_id}>
                      {#each categories as c}
                        <option value={c.id}>{c.name}</option>
                      {/each}
                    </select>
                  </td>
                  <td><input class="form-input table-input" type="number" bind:value={item.cost_price} on:input={() => handleCostOrMarginChange(item)} /></td>
                  <td><input class="form-input table-input" type="number" bind:value={item.margin_percent} on:input={() => handleCostOrMarginChange(item)} /></td>
                  <td><strong class="price-highlight">{formatCurrency(item.selling_price)}</strong></td>
                </tr>
              {/each}
            </tbody>
          </table>
        </div>

        <div class="modal-actions">
          <button class="btn btn-secondary" on:click={() => showApproveModal = false}>
            {$t('btn.cancel')}
          </button>
          <button class="btn btn-primary" disabled={isSavingApproval} on:click={submitApproval}>
            {isSavingApproval ? $t('app.syncing') : $t('purch.approvePO')}
          </button>
        </div>
      </div>
    </div>
  </div>
{/if}

<!-- Create Purchase Order Modal -->
{#if showCreateModal}
  <div class="modal-backdrop animate-fade-in" on:click|self={() => showCreateModal = false} role="dialog" aria-modal="true">
    <div class="modal-card vuexy-card modal-lg animate-scale-up">
      <div class="modal-header">
        <div>
          <h3>{$t('purch.btn.newPO')}</h3>
          <p class="sub-text">Directly intake inventory and update wholesale balance</p>
        </div>
        <button class="close-btn" on:click={() => showCreateModal = false}>&times;</button>
      </div>

      <form on:submit|preventDefault={handleCreatePurchase} class="modal-form">
        <div class="form-row">
          <div class="form-group">
            <label for="create-po-sup">Assigned Supplier:</label>
            <select id="create-po-sup" class="form-select" bind:value={createForm.supplier_id}>
              <option value="">-- Open Market / Unassigned --</option>
              {#each suppliers as s}
                <option value={s.id}>{s.name}</option>
              {/each}
            </select>
          </div>
          <div class="form-group">
            <label for="create-po-status">Initial Status:</label>
            <select id="create-po-status" class="form-select" bind:value={createForm.status}>
              <option value="approved">Approved (Immediately Restock Inventory)</option>
              <option value="pending">Pending Staging (Requires Verification)</option>
            </select>
          </div>
        </div>

        <div class="items-table-section">
          <div class="section-sub-header">
            <h4>Line Items ({createForm.items.length})</h4>
            <button type="button" class="btn btn-secondary btn-sm" on:click={addCreateItemRow}>
              {@html icons.plus} Add Item Row
            </button>
          </div>

          <div class="table-container">
            <table class="data-table">
              <thead>
                <tr>
                  <th>Product Selection / Custom Name</th>
                  <th>Quantity</th>
                  <th>Unit Cost (SDG)</th>
                  <th>Total</th>
                  <th>Action</th>
                </tr>
              </thead>
              <tbody>
                {#each createForm.items as item, index}
                  <tr>
                    <td>
                      <input 
                        type="text" 
                        class="form-input table-input" 
                        placeholder="Drug name or select below"
                        bind:value={item.product_name}
                      />
                    </td>
                    <td>
                      <input 
                        type="number" 
                        class="form-input table-input" 
                        min="1" 
                        bind:value={item.quantity} 
                      />
                    </td>
                    <td>
                      <input 
                        type="number" 
                        class="form-input table-input" 
                        min="0" 
                        bind:value={item.cost_price} 
                      />
                    </td>
                    <td>
                      <strong>{formatCurrency((item.quantity || 1) * (item.cost_price || 0))}</strong>
                    </td>
                    <td>
                      <button 
                        type="button" 
                        class="btn-icon btn-icon-danger" 
                        disabled={createForm.items.length <= 1}
                        on:click={() => removeCreateItemRow(index)}
                      >
                        {@html icons.trash}
                      </button>
                    </td>
                  </tr>
                {/each}
              </tbody>
            </table>
          </div>
        </div>

        <div class="modal-actions">
          <button type="button" class="btn btn-secondary" on:click={() => showCreateModal = false}>
            {$t('btn.cancel')}
          </button>
          <button type="submit" class="btn btn-primary" disabled={isCreatingPurchase}>
            {isCreatingPurchase ? $t('app.syncing') : $t('purch.btn.newPO')}
          </button>
        </div>
      </form>
    </div>
  </div>
{/if}

<!-- Edit Purchase Order Modal -->
{#if showEditModal}
  <div class="modal-backdrop animate-fade-in" on:click|self={() => showEditModal = false} role="dialog" aria-modal="true">
    <div class="modal-card vuexy-card modal-lg animate-scale-up">
      <div class="modal-header">
        <div>
          <h3>{$currentLocale === 'ar' ? 'تعديل بنود أمر الشراء' : 'Edit Purchase Order Items'}</h3>
          <p class="sub-text">PO #{editingPurchase?.invoice_number || ''}</p>
        </div>
        <button class="close-btn" on:click={() => showEditModal = false}>&times;</button>
      </div>

      <form on:submit|preventDefault={handleSaveEdit} class="modal-form">
        <div class="form-row">
          <div class="form-group flex-1">
            <label for="edit-po-sup">{$t('purch.th.supplier')}:</label>
            <select id="edit-po-sup" class="form-select" bind:value={editingSupplierId}>
              <option value={null}>{$currentLocale === 'ar' ? 'مورد غير محدد' : 'Unassigned Supplier'}</option>
              {#each suppliers as s}
                <option value={s.id}>{s.name}</option>
              {/each}
            </select>
          </div>
          <div class="form-group flex-1">
            <label for="edit-po-notes">{$currentLocale === 'ar' ? 'ملاحظات أمر الشراء' : 'Order Notes'}:</label>
            <input id="edit-po-notes" class="form-input" type="text" bind:value={editingNotes} placeholder={$currentLocale === 'ar' ? 'أدخل ملاحظات أمر الشراء...' : 'Restock notes...'} />
          </div>
        </div>

        <div class="items-header-bar">
          <h4>{$currentLocale === 'ar' ? 'قائمة أصناف الشراء' : 'Medicine Line Items'} ({editingItems.length})</h4>
          <button type="button" class="btn btn-secondary btn-sm" on:click={addEditingItem}>
            {@html icons.plus} {$currentLocale === 'ar' ? 'إضافة بند جديد' : 'Add Line Item'}
          </button>
        </div>

        <div class="table-container edit-items-table">
          <table class="data-table">
            <thead>
              <tr>
                <th style="width: 38%;">{$t('prod.th.product')}</th>
                <th style="width: 18%;">{$t('prod.th.stock')} (Qty)</th>
                <th style="width: 20%;">Cost Price (SDG)</th>
                <th style="width: 16%;">Subtotal</th>
                <th style="width: 8%; text-align: center;"></th>
              </tr>
            </thead>
            <tbody>
              {#each editingItems as item, idx}
                <tr>
                  <td>
                    <div class="product-input-wrapper">
                      <select 
                        class="form-select select-sm mb-1" 
                        value={item.product_id || ''} 
                        on:change={(e) => onEditingProductSelect(idx, e.currentTarget.value)}
                      >
                        <option value="">{$currentLocale === 'ar' ? '-- اختر صنف مسجل أو اكتب أدناه --' : '-- Catalog Drug (or custom below) --'}</option>
                        {#each products as p}
                          <option value={p.id}>{p.name}</option>
                        {/each}
                      </select>
                      <input 
                        type="text" 
                        class="form-input input-sm" 
                        bind:value={item.product_name} 
                        placeholder={$currentLocale === 'ar' ? 'اسم الدواء / المستلزم' : 'Medicine name...'} 
                        required 
                      />
                    </div>
                  </td>
                  <td>
                    <input 
                      type="number" 
                      class="form-input input-sm" 
                      min="1" 
                      bind:value={item.quantity} 
                      required 
                    />
                  </td>
                  <td>
                    <input 
                      type="number" 
                      class="form-input input-sm" 
                      min="0" 
                      bind:value={item.unit_cost} 
                      required 
                    />
                  </td>
                  <td>
                    <strong>{formatCurrency((item.unit_cost || 0) * (item.quantity || 1))}</strong>
                  </td>
                  <td class="text-center">
                    <button 
                      type="button" 
                      class="btn-icon-danger" 
                      on:click={() => removeEditingItem(idx)}
                      title={$currentLocale === 'ar' ? 'حذف البند' : 'Remove item'}
                    >
                      &times;
                    </button>
                  </td>
                </tr>
              {/each}
            </tbody>
          </table>
        </div>

        <div class="edit-footer-bar">
          <div class="grand-total-box">
            <span>{$currentLocale === 'ar' ? 'إجمالي الطلب المحدث:' : 'Updated Total Amount:'}</span>
            <strong class="total-val">{formatCurrency(editingGrandTotal)}</strong>
          </div>
          <div class="modal-actions">
            <button type="button" class="btn btn-secondary" on:click={() => showEditModal = false}>
              {$t('btn.cancel')}
            </button>
            <button type="submit" class="btn btn-primary" disabled={isSavingEdit}>
              {isSavingEdit ? ($currentLocale === 'ar' ? 'جاري الحفظ...' : 'Saving...') : ($currentLocale === 'ar' ? 'حفظ التعديلات' : 'Save Changes')}
            </button>
          </div>
        </div>
      </form>
    </div>
  </div>
{/if}

<style>
  .purchases-container {
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

  .filters-panel {
    padding: 10px 14px;
    display: flex;
    align-items: center;
  }
  .status-filters {
    display: flex;
    gap: 8px;
  }
  .filter-pill {
    padding: 6px 14px;
    border-radius: var(--radius-pill);
    border: 1px solid var(--border-color);
    background: transparent;
    color: var(--text-primary);
    font-family: inherit;
    font-size: 0.8125rem;
    font-weight: 500;
    cursor: pointer;
    transition: all var(--transition);
  }
  .filter-pill:hover {
    border-color: var(--color-primary);
    color: var(--color-primary);
  }
  .filter-pill.active {
    background: var(--color-primary-gradient);
    color: #ffffff;
    border-color: transparent;
    box-shadow: var(--shadow-primary);
  }

  .content-panel {
    padding: 1.5rem;
  }
  .row-actions {
    display: flex;
    align-items: center;
    gap: 8px;
  }
  .text-right {
    text-align: right;
  }
  body.rtl-mode .text-right, html[dir="rtl"] .text-right {
    text-align: left;
  }

  .modal-lg {
    max-width: 840px;
    width: 90%;
  }
  .sub-text {
    font-size: 0.8125rem;
    color: var(--text-muted);
    margin-top: 2px;
  }

  .table-input {
    padding: 4px 8px;
    font-size: 0.8125rem;
    min-width: 100px;
  }
  .table-select {
    padding: 4px 8px;
    font-size: 0.8125rem;
  }
  .price-highlight {
    color: var(--color-success);
    font-weight: 600;
  }

  .modal-form, .approval-form {
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
    color: var(--text-primary);
    font-weight: 500;
  }

  .items-table-section {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }
  .section-sub-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }
  .section-sub-header h4 {
    font-size: 0.95rem;
  }

  .btn-outline-warning {
    background: transparent;
    color: var(--color-warning);
    border: 1px solid var(--color-warning);
  }
  .btn-outline-warning:hover {
    background: var(--color-warning-light);
  }
  .btn-warning {
    background: var(--color-warning);
    color: #fff;
  }
  .btn-warning:hover {
    background: #e68d37;
  }
  .items-header-bar {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-top: 0.5rem;
    padding-bottom: 6px;
    border-bottom: 1px solid var(--border-color);
  }
  .items-header-bar h4 {
    font-size: 0.95rem;
    font-weight: 600;
  }
  .product-input-wrapper {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }
  .btn-icon-danger {
    background: transparent;
    border: none;
    color: var(--color-danger);
    font-size: 1.25rem;
    font-weight: 700;
    cursor: pointer;
    padding: 2px 6px;
    border-radius: var(--radius-sm);
  }
  .btn-icon-danger:hover {
    background: var(--color-danger-light);
  }
  .edit-footer-bar {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding-top: 1rem;
    border-top: 1px solid var(--border-color);
    margin-top: 0.5rem;
  }
  .grand-total-box {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 0.95rem;
  }
  .grand-total-box .total-val {
    font-size: 1.15rem;
    color: var(--color-primary);
  }
  .text-center {
    text-align: center;
  }
  .mb-1 {
    margin-bottom: 4px;
  }

  .modal-actions {
    display: flex;
    justify-content: flex-end;
    gap: 10px;
    padding-top: 0.75rem;
    border-top: 1px solid var(--border-color);
  }

  .loading-state, .empty-state {
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
</style>
