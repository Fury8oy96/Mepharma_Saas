<script lang="ts">
  import { onMount } from 'svelte';
  import { apiRequest, addToast } from '../api';
  import { icons } from '../utils/icons';
  import { t, currentLocale } from '../i18n/store';

  let suppliers: any[] = [];
  let loading = true;

  let showModal = false;
  let isEditing = false;
  let editingId: number | null = null;
  let form = { name: '', contact_person: '', phone: '', email: '', address: '' };

  async function loadSuppliers() {
    loading = true;
    try {
      const res = await apiRequest('/suppliers');
      suppliers = Array.isArray(res) ? res : (Array.isArray(res?.data) ? res.data : []);
    } catch (err: any) {
      addToast(err.message || $t('toast.error'), 'error');
    } finally {
      loading = false;
    }
  }

  onMount(loadSuppliers);

  function openCreate() {
    isEditing = false;
    editingId = null;
    form = { name: '', contact_person: '', phone: '', email: '', address: '' };
    showModal = true;
  }

  function openEdit(sup: any) {
    isEditing = true;
    editingId = sup.id;
    form = {
      name: sup.name,
      contact_person: sup.contact_person || sup.contactPerson || '',
      phone: sup.phone || '',
      email: sup.email || '',
      address: sup.address || ''
    };
    showModal = true;
  }

  async function handleSave() {
    if (!form.name.trim()) {
      addToast($currentLocale === 'ar' ? 'اسم المورد مطلوب' : 'Supplier name is required', 'warning');
      return;
    }
    try {
      if (isEditing && editingId) {
        await apiRequest(`/suppliers/${editingId}`, { method: 'PUT', body: JSON.stringify(form) });
        addToast($t('toast.success'), 'success');
      } else {
        await apiRequest('/suppliers', { method: 'POST', body: JSON.stringify(form) });
        addToast($t('toast.success'), 'success');
      }
      showModal = false;
      await loadSuppliers();
    } catch (err: any) {
      addToast(err.message || $t('toast.error'), 'error');
    }
  }

  async function handleDelete(id: number) {
    const confirmMsg = $currentLocale === 'ar' ? 'هل أنت متأكد من حذف هذا المورد؟' : 'Are you sure you want to delete this supplier?';
    if (!confirm(confirmMsg)) return;
    try {
      await apiRequest(`/suppliers/${id}`, { method: 'DELETE' });
      addToast($t('toast.success'), 'success');
      await loadSuppliers();
    } catch (err: any) {
      addToast(err.message || $t('toast.error'), 'error');
    }
  }
</script>

<div class="suppliers-tab-container animate-fade-in">
  <div class="tab-header">
    <div>
      <h2>{$t('sup.title')}</h2>
      <p class="subtitle">{$t('overview.desc')}</p>
    </div>
    <div class="actions-group">
      <button class="btn btn-secondary" on:click={loadSuppliers} title={$t('btn.refresh')}>
        {@html icons.refresh} {$t('btn.refresh')}
      </button>
      <button class="btn btn-primary" on:click={openCreate}>
        {@html icons.plus} {$t('sup.btnAdd')}
      </button>
    </div>
  </div>

  <div class="vuexy-card content-panel">
    {#if loading}
      <div class="loading-state">
        <div class="spinner"></div>
        <p>{$t('table.loading')}</p>
      </div>
    {:else if suppliers.length === 0}
      <div class="empty-state">
        <p>{$t('table.noData')}</p>
      </div>
    {:else}
      <div class="table-container">
        <table class="data-table">
          <thead>
            <tr>
              <th>{$t('sup.th.company')}</th>
              <th>{$t('sup.th.contact')}</th>
              <th>{$t('sup.th.phone')}</th>
              <th>{$t('set.address')}</th>
              <th>{$t('prod.th.actions')}</th>
            </tr>
          </thead>
          <tbody>
            {#each suppliers as sup}
              <tr>
                <td><strong>{sup.name}</strong></td>
                <td>{sup.contact_person || sup.contactPerson || '—'}</td>
                <td>{sup.phone || '—'}</td>
                <td>{sup.address || '—'}</td>
                <td>
                  <div class="row-actions">
                    <button class="btn-icon" on:click={() => openEdit(sup)} title={$t('btn.edit')}>
                      {@html icons.edit}
                    </button>
                    <button class="btn-icon btn-icon-danger" on:click={() => handleDelete(sup.id)} title={$t('btn.delete')}>
                      {@html icons.trash}
                    </button>
                  </div>
                </td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
    {/if}
  </div>

  <!-- Add/Edit Modal -->
  {#if showModal}
    <div class="modal-backdrop animate-fade-in" on:click|self={() => showModal = false} role="dialog" aria-modal="true">
      <div class="modal-card vuexy-card animate-scale-up">
        <div class="modal-header">
          <h3>{isEditing ? $t('btn.edit') : $t('sup.btnAdd')}</h3>
          <button class="close-btn" on:click={() => showModal = false}>{@html icons.x}</button>
        </div>

        <form on:submit|preventDefault={handleSave} class="modal-form">
          <div class="form-group">
            <label for="s-name">{$t('sup.th.company')} *</label>
            <input id="s-name" class="form-input" type="text" required bind:value={form.name} placeholder="e.g. Hikma Pharmaceuticals" />
          </div>

          <div class="form-row">
            <div class="form-group">
              <label for="s-contact">{$t('sup.th.contact')}</label>
              <input id="s-contact" class="form-input" type="text" bind:value={form.contact_person} />
            </div>
            <div class="form-group">
              <label for="s-phone">{$t('sup.th.phone')}</label>
              <input id="s-phone" class="form-input" type="text" bind:value={form.phone} />
            </div>
          </div>

          <div class="form-group">
            <label for="s-email">Email</label>
            <input id="s-email" class="form-input" type="email" bind:value={form.email} />
          </div>

          <div class="form-group">
            <label for="s-addr">{$t('set.address')}</label>
            <input id="s-addr" class="form-input" type="text" bind:value={form.address} />
          </div>

          <div class="modal-actions">
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
</div>

<style>
  .suppliers-tab-container {
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

  .content-panel {
    padding: 1.5rem;
  }
  .row-actions {
    display: flex;
    align-items: center;
    gap: 6px;
  }

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
    color: var(--text-primary);
    font-weight: 500;
  }

  .modal-actions {
    display: flex;
    justify-content: flex-end;
    gap: 10px;
    margin-top: 0.5rem;
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
