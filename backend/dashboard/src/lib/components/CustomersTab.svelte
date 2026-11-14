<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { apiRequest, addToast, subscribeToSSE } from '../api';
  import { currencyStore } from '../currency';
  import { icons } from '../utils/icons';
  import { t, currentLocale } from '../i18n/store';

  let subTab = 'customers'; // 'customers' | 'requests' | 'messaging'
  let customers: any[] = [];
  let requests: any[] = [];
  let communicationLogs: any[] = [];
  let templates: any[] = [];
  let loading = true;
  let unsubSSE: Array<() => void> = [];

  // Out-of-Stock Notification Modal
  let showNotifyModal = false;
  let activeRequest: any = null;
  let notifyChannel: 'whatsapp' | 'sms' = 'whatsapp';
  let notifyMessage = '';
  let isSending = false;

  // Campaign Composer
  let campaignTier = 'all';
  let campaignChannel: 'whatsapp' | 'sms' = 'whatsapp';
  let campaignContent = '';
  let isSendingCampaign = false;

  async function loadCustomers() {
    try {
      const res = await apiRequest('/customers');
      customers = Array.isArray(res) ? res : (Array.isArray(res?.data) ? res.data : []);
    } catch (err: any) {
      addToast(err.message || $t('toast.error'), 'error');
    }
  }

  async function loadRequests() {
    try {
      const res = await apiRequest('/customer-requests');
      requests = Array.isArray(res) ? res : (Array.isArray(res?.data) ? res.data : []);
    } catch (err: any) {
      addToast(err.message || $t('toast.error'), 'error');
    }
  }

  async function loadLogs() {
    try {
      const res = await apiRequest('/communications/logs');
      communicationLogs = Array.isArray(res) ? res : (Array.isArray(res?.data) ? res.data : []);
    } catch (err: any) {
      addToast(err.message || $t('toast.error'), 'error');
    }
  }

  async function loadTemplates() {
    try {
      const res = await apiRequest('/communications/templates');
      templates = Array.isArray(res) ? res : (Array.isArray(res?.data) ? res.data : []);
    } catch (_) {}
  }

  async function refreshAll() {
    loading = true;
    await Promise.allSettled([loadCustomers(), loadRequests(), loadLogs(), loadTemplates()]);
    loading = false;
  }

  onMount(() => {
    refreshAll();
    const unsub = subscribeToSSE((event) => {
      if (['sale_created', 'customer_created', 'customer_updated'].includes(event.event)) {
        loadCustomers();
      }
    });
    unsubSSE.push(unsub);
  });

  onDestroy(() => {
    unsubSSE.forEach(u => u());
  });

  function openNotifyModal(request: any) {
    activeRequest = request;
    notifyChannel = 'whatsapp';
    const medName = request.requested_product_name || request.medicine_name || '';
    notifyMessage = $currentLocale === 'ar'
      ? `مرحباً ${request.customer_name || 'عميلنا العزيز'}، الدواء المطلوب "${medName}" متوفر الآن في صيدلية مي فارما! تم حجز عبوتك، يرجى التفضل بزيارتنا أو التواصل معنا للاستلام.`
      : `Hello ${request.customer_name || 'Valued Customer'}, the requested medication "${medName}" is now available at MePharma! We have reserved your unit. Please visit or contact us to collect it.`;
    showNotifyModal = true;
  }

  async function sendStockNotification() {
    if (!activeRequest) return;
    isSending = true;
    try {
      await apiRequest(`/customer-requests/${activeRequest.id}/notify`, {
        method: 'POST',
        body: JSON.stringify({
          channel: notifyChannel,
          recipient: activeRequest.customer_phone,
          message: notifyMessage
        })
      });
      addToast($t('toast.success'), 'success');
      showNotifyModal = false;
      await loadRequests();
      await loadLogs();
    } catch (err: any) {
      addToast(err.message || $t('toast.error'), 'error');
    } finally {
      isSending = false;
    }
  }

  async function markRequestFulfilled(id: number) {
    try {
      await apiRequest(`/customer-requests/${id}/fulfill`, { method: 'POST' });
      addToast($t('toast.success'), 'success');
      await loadRequests();
    } catch (err: any) {
      addToast(err.message || $t('toast.error'), 'error');
    }
  }

  async function sendBroadcastCampaign() {
    if (!campaignContent.trim()) {
      addToast($currentLocale === 'ar' ? 'يرجى كتابة نص الرسالة' : 'Campaign message content is required', 'warning');
      return;
    }
    isSendingCampaign = true;
    try {
      const res = await apiRequest('/communications/broadcast', {
        method: 'POST',
        body: JSON.stringify({
          channel: campaignChannel,
          target_tier: campaignTier,
          message: campaignContent
        })
      });
      addToast(`Broadcast initiated: ${res.recipient_count || 0} messages queued.`, 'success');
      campaignContent = '';
      await loadLogs();
    } catch (err: any) {
      addToast(err.message || $t('toast.error'), 'error');
    } finally {
      isSendingCampaign = false;
    }
  }

  // Add / Edit Customer Form
  let showCustomerModal = false;
  let isEditingCustomer = false;
  let editingCustomerId: number | null = null;
  let isSavingCustomer = false;
  let customerForm = {
    name: '',
    phone: '',
    email: '',
    address: '',
    credit_limit: 0,
    loyalty_points: 0,
    loyalty_tier: 'bronze'
  };

  function openCreateCustomer() {
    isEditingCustomer = false;
    editingCustomerId = null;
    customerForm = {
      name: '',
      phone: '',
      email: '',
      address: '',
      credit_limit: 0,
      loyalty_points: 0,
      loyalty_tier: 'bronze'
    };
    showCustomerModal = true;
  }

  function openEditCustomer(c: any) {
    isEditingCustomer = true;
    editingCustomerId = c.id;
    customerForm = {
      name: c.name || '',
      phone: c.phone || '',
      email: c.email || '',
      address: c.address || '',
      credit_limit: c.credit_limit || 0,
      loyalty_points: c.loyalty_points || 0,
      loyalty_tier: c.loyalty_tier || 'bronze'
    };
    showCustomerModal = true;
  }

  async function saveCustomer() {
    if (!customerForm.name.trim()) {
      addToast($currentLocale === 'ar' ? 'اسم العميل مطلوب' : 'Customer name is required', 'warning');
      return;
    }
    isSavingCustomer = true;
    try {
      if (isEditingCustomer && editingCustomerId) {
        await apiRequest(`/customers/${editingCustomerId}`, {
          method: 'PUT',
          body: JSON.stringify(customerForm)
        });
        addToast($t('toast.success'), 'success');
      } else {
        await apiRequest('/customers', {
          method: 'POST',
          body: JSON.stringify(customerForm)
        });
        addToast($t('toast.success'), 'success');
      }
      showCustomerModal = false;
      await loadCustomers();
    } catch (err: any) {
      addToast(err.message || $t('toast.error'), 'error');
    } finally {
      isSavingCustomer = false;
    }
  }

  async function deleteCustomer(id: number) {
    const confirmMsg = $currentLocale === 'ar' ? 'هل أنت متأكد من حذف هذا العميل؟' : 'Are you sure you want to delete this customer?';
    if (!confirm(confirmMsg)) return;
    try {
      await apiRequest(`/customers/${id}`, { method: 'DELETE' });
      addToast($t('toast.success'), 'success');
      await loadCustomers();
    } catch (err: any) {
      addToast(err.message || $t('toast.error'), 'error');
    }
  }

  function formatCurrency(val: number) {
    return Math.round(Number(val || 0)).toLocaleString('en-US');
  }
</script>

<div class="customers-zone animate-fade-in">
  <div class="tab-header">
    <div>
      <h2>{$t('cust.title')}</h2>
      <p class="subtitle">{$t('overview.desc')}</p>
    </div>
    <div class="actions-group">
      <button class="btn btn-secondary" on:click={refreshAll} title={$t('btn.refresh')}>
        {@html icons.refresh} {$t('btn.refresh')}
      </button>
      <button class="btn btn-primary" on:click={openCreateCustomer}>
        {@html icons.plus} {$t('cust.btnAdd')}
      </button>
    </div>
  </div>

  <!-- Sub-Navigation Bar (Vuexy Segmented Buttons) -->
  <div class="vuexy-card subnav-panel">
    <button 
      class="subnav-pill {subTab === 'customers' ? 'active' : ''}" 
      on:click={() => subTab = 'customers'}
    >
      <span>{@html icons.users}</span>
      <span>{$t('cust.tab.customers')} ({customers.length})</span>
    </button>
    <button 
      class="subnav-pill pill-amber {subTab === 'requests' ? 'active' : ''}" 
      on:click={() => subTab = 'requests'}
    >
      <span>{@html icons.products}</span>
      <span>{$t('cust.tab.wishlist')} ({requests.filter(r => r.status === 'pending').length})</span>
    </button>
    <button 
      class="subnav-pill pill-emerald {subTab === 'messaging' ? 'active' : ''}" 
      on:click={() => subTab = 'messaging'}
    >
      <span>{@html icons.reports}</span>
      <span>{$t('cust.btnBroadcast')} ({communicationLogs.length})</span>
    </button>
  </div>

  <!-- Sub-View: Customers List with Loyalty -->
  {#if subTab === 'customers'}
    <div class="vuexy-card content-panel">
      {#if loading}
        <div class="loading-state">
          <div class="spinner"></div>
          <p>{$t('table.loading')}</p>
        </div>
      {:else if customers.length === 0}
        <div class="empty-state">
          <p>{$t('table.noData')}</p>
        </div>
      {:else}
        <div class="table-container">
          <table class="data-table">
            <thead>
              <tr>
                <th>{$t('cust.th.name')}</th>
                <th>{$t('cust.th.phone')}</th>
                <th>{$t('set.address')}</th>
                <th>{$t('cust.th.tier')}</th>
                <th>{$t('cust.th.points')}</th>
                <th>{$t('sup.th.balance')}</th>
                <th>{$t('prod.th.actions')}</th>
              </tr>
            </thead>
            <tbody>
              {#each customers as c}
                <tr>
                  <td>
                    <div class="customer-info">
                      <strong>{c.name}</strong>
                      <span class="sub-text">{c.email || '—'}</span>
                    </div>
                  </td>
                  <td>{c.phone || '—'}</td>
                  <td>{c.address || '—'}</td>
                  <td>
                    {#if c.loyalty_tier === 'platinum'}
                      <span class="badge badge-role">{$t('cust.tier.platinum')}</span>
                    {:else if c.loyalty_tier === 'gold'}
                      <span class="badge badge-pending">{$t('cust.tier.gold')}</span>
                    {:else if c.loyalty_tier === 'silver'}
                      <span class="badge badge-info">{$t('cust.tier.silver')}</span>
                    {:else}
                      <span class="badge badge-secondary">{$t('cust.tier.bronze')}</span>
                    {/if}
                  </td>
                  <td><strong>{c.loyalty_points || 0} {$currentLocale === 'ar' ? 'نقطة' : 'pts'}</strong></td>
                  <td>
                    <span class="{c.balance > 0 ? 'text-danger' : 'text-success'}">
                      {formatCurrency(c.balance)} {$currencyStore}
                    </span>
                  </td>
                  <td>
                    <div class="row-actions">
                      <button class="btn-icon" on:click={() => openEditCustomer(c)} title={$t('btn.edit')}>
                        {@html icons.edit}
                      </button>
                      <button class="btn-icon btn-icon-danger" on:click={() => deleteCustomer(c.id)} title={$t('btn.delete')}>
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
  {:else if subTab === 'requests'}
    <!-- Sub-View: Out-of-Stock Drug Demands -->
    <div class="vuexy-card content-panel">
      {#if requests.length === 0}
        <div class="empty-state">
          <p>{$t('table.noData')}</p>
        </div>
      {:else}
        <div class="table-container">
          <table class="data-table">
            <thead>
              <tr>
                <th>{$t('prod.th.product')}</th>
                <th>{$t('cust.th.name')}</th>
                <th>{$t('cust.th.phone')}</th>
                <th>{$t('common.date')}</th>
                <th>{$t('common.status')}</th>
                <th>{$t('common.actions')}</th>
              </tr>
            </thead>
            <tbody>
              {#each requests as req}
                <tr>
                  <td><strong>{req.requested_product_name || req.medicine_name}</strong></td>
                  <td>{req.customer_name || $t('sales.walkIn')}</td>
                  <td>{req.customer_phone || '—'}</td>
                  <td>{new Date(req.created_at).toLocaleDateString($currentLocale === 'ar' ? 'ar-EG' : 'en-US')}</td>
                  <td>
                    {#if req.status === 'notified'}
                      <span class="badge badge-approved">{$t('cust.status.notified')}</span>
                    {:else if req.status === 'fulfilled'}
                      <span class="badge badge-role">{$t('cust.status.fulfilled')}</span>
                    {:else}
                      <span class="badge badge-pending">{$t('cust.status.pending')}</span>
                    {/if}
                  </td>
                  <td>
                    <div class="row-actions">
                      {#if req.status === 'pending'}
                        <button class="btn btn-primary btn-sm" on:click={() => openNotifyModal(req)}>
                          {@html icons.bell} {$t('cust.act.notify')}
                        </button>
                        <button class="btn btn-secondary btn-sm" on:click={() => markRequestFulfilled(req.id)}>
                          {$t('cust.act.fulfill')}
                        </button>
                      {:else}
                        <span class="text-muted text-sm">{$t('cust.status.resolved')}</span>
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
  {:else if subTab === 'messaging'}
    <!-- Sub-View: Broadcast Studio -->
    <div class="messaging-layout">
      <div class="vuexy-card broadcast-card">
        <h3>{$t('cust.btnBroadcast')}</h3>
        <p class="sub-text">{$t('cust.broadcast.sub')}</p>

        <form on:submit|preventDefault={sendBroadcastCampaign} class="broadcast-form">
          <div class="form-row">
            <div class="form-group">
              <label for="b-tier">{$t('cust.broadcast.segment')}:</label>
              <select id="b-tier" class="form-select" bind:value={campaignTier}>
                <option value="all">{$t('cust.broadcast.allCustomers')} ({customers.length})</option>
                <option value="platinum">{$t('cust.broadcast.vipOnly')}</option>
                <option value="gold">{$t('cust.broadcast.goldPlus')}</option>
              </select>
            </div>
            <div class="form-group">
              <label for="b-chan">{$t('cust.broadcast.channel')}:</label>
              <select id="b-chan" class="form-select" bind:value={campaignChannel}>
                <option value="whatsapp">{$t('cust.broadcast.whatsappGw')}</option>
                <option value="sms">{$t('cust.broadcast.directSms')}</option>
              </select>
            </div>
          </div>

          <div class="form-group">
            <label for="b-msg">{$t('cust.broadcast.content')}:</label>
            <textarea id="b-msg" class="form-textarea" rows="4" bind:value={campaignContent} placeholder={$t('cust.broadcast.placeholder')}></textarea>
          </div>

          <button type="submit" class="btn btn-primary" disabled={isSendingCampaign}>
            {isSendingCampaign ? $t('app.syncing') : $t('cust.broadcast.dispatch')}
          </button>
        </form>
      </div>

      <div class="vuexy-card logs-card">
        <h3>{$t('cust.logs.title')}</h3>
        <div class="logs-list">
          {#if communicationLogs.length === 0}
            <p class="text-muted">{$t('cust.logs.empty')}</p>
          {:else}
            {#each communicationLogs.slice(0, 15) as log}
              <div class="log-item">
                <div class="log-top">
                  <span class="badge badge-{log.channel === 'whatsapp' ? 'approved' : 'role'}">{log.channel}</span>
                  <span class="log-date">{new Date(log.created_at).toLocaleTimeString($currentLocale === 'ar' ? 'ar-EG' : 'en-US', { hour: '2-digit', minute: '2-digit' })}</span>
                </div>
                <div class="log-recip"><strong>{$t('cust.logs.to')}:</strong> {log.recipient}</div>
                <div class="log-msg">{log.message}</div>
              </div>
            {/each}
          {/if}
        </div>
      </div>
    </div>
  {/if}
</div>

<!-- Notify Restock Modal -->
{#if showNotifyModal}
  <div class="modal-backdrop animate-fade-in" on:click|self={() => showNotifyModal = false} role="dialog" aria-modal="true">
    <div class="modal-card vuexy-card animate-scale-up">
      <div class="modal-header">
        <div>
          <h3>{$t('cust.notify.title')}</h3>
          <p class="sub-text">{$t('prod.th.product')}: {activeRequest?.requested_product_name || activeRequest?.medicine_name} &bull; {$t('cust.th.name')}: {activeRequest?.customer_name || $t('sales.walkIn')}</p>
        </div>
        <button class="close-btn" on:click={() => showNotifyModal = false}>{@html icons.x}</button>
      </div>

      <div class="form-group">
        <label for="notif-chan">{$t('cust.notify.channel')}:</label>
        <select id="notif-chan" class="form-select" bind:value={notifyChannel}>
          <option value="whatsapp">WhatsApp</option>
          <option value="sms">SMS</option>
        </select>
      </div>

      <div class="form-group">
        <label for="notif-phone">{$t('cust.notify.phone')}:</label>
        <input id="notif-phone" class="form-input" type="text" bind:value={activeRequest.customer_phone} />
      </div>

      <div class="form-group">
        <label for="notif-msg">{$t('cust.notify.message')}:</label>
        <textarea id="notif-msg" class="form-textarea" rows="4" bind:value={notifyMessage}></textarea>
      </div>

      <div class="modal-actions">
        <button class="btn btn-secondary" on:click={() => showNotifyModal = false} disabled={isSending}>{$t('btn.cancel')}</button>
        <button class="btn btn-primary" on:click={sendStockNotification} disabled={isSending}>
          {isSending ? $t('app.syncing') : $t('cust.notify.send')}
        </button>
      </div>
    </div>
  </div>
{/if}

<!-- Customer Add/Edit Modal -->
{#if showCustomerModal}
  <div class="modal-backdrop animate-fade-in" on:click|self={() => showCustomerModal = false} role="dialog" aria-modal="true">
    <div class="modal-card vuexy-card">
      <div class="modal-header">
        <div>
          <h3>{isEditingCustomer ? $t('btn.edit') : $t('cust.btnAdd')}</h3>
          <p class="sub-text">{$t('cust.modal.sub')}</p>
        </div>
        <button class="close-btn" on:click={() => showCustomerModal = false}>{@html icons.x}</button>
      </div>

      <form on:submit|preventDefault={saveCustomer} class="modal-form">
        <div class="form-row">
          <div class="form-group">
            <label for="c-name">{$t('cust.th.name')} *</label>
            <input id="c-name" class="form-input" type="text" required bind:value={customerForm.name} />
          </div>
          <div class="form-group">
            <label for="c-phone">{$t('cust.th.phone')}</label>
            <input id="c-phone" class="form-input" type="text" bind:value={customerForm.phone} />
          </div>
        </div>

        <div class="form-row">
          <div class="form-group">
            <label for="c-email">{$t('common.email')}</label>
            <input id="c-email" class="form-input" type="email" bind:value={customerForm.email} />
          </div>
          <div class="form-group">
            <label for="c-tier">{$t('cust.th.tier')}</label>
            <select id="c-tier" class="form-select" bind:value={customerForm.loyalty_tier}>
              <option value="bronze">{$t('cust.tier.bronze')}</option>
              <option value="silver">{$t('cust.tier.silver')}</option>
              <option value="gold">{$t('cust.tier.gold')}</option>
              <option value="platinum">{$t('cust.tier.platinum')}</option>
            </select>
          </div>
        </div>

        <div class="form-group">
          <label for="c-addr">{$t('set.address')}</label>
          <input id="c-addr" class="form-input" type="text" bind:value={customerForm.address} />
        </div>

        <div class="modal-actions">
          <button type="button" class="btn btn-secondary" on:click={() => showCustomerModal = false}>
            {$t('btn.cancel')}
          </button>
          <button type="submit" class="btn btn-primary" disabled={isSavingCustomer}>
            {isSavingCustomer ? $t('app.syncing') : $t('btn.save')}
          </button>
        </div>
      </form>
    </div>
  </div>
{/if}

<style>
  .customers-zone {
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

  .subnav-panel {
    display: flex;
    padding: 6px;
    gap: 8px;
  }
  .subnav-pill {
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
  .subnav-pill:hover {
    background: var(--color-primary-light);
    color: var(--color-primary);
  }
  .subnav-pill.active {
    background: var(--color-primary-gradient);
    color: #ffffff;
    box-shadow: var(--shadow-primary);
  }

  .content-panel {
    padding: 1.5rem;
  }
  .customer-info {
    display: flex;
    flex-direction: column;
  }
  .sub-text {
    font-size: 0.75rem;
    color: var(--text-muted);
  }
  .text-danger { color: var(--color-danger); }
  .text-success { color: var(--color-success); }
  .row-actions {
    display: flex;
    align-items: center;
    gap: 6px;
  }

  .messaging-layout {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 1.5rem;
  }
  .broadcast-card, .logs-card {
    padding: 1.5rem;
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }
  .broadcast-form {
    display: flex;
    flex-direction: column;
    gap: 1rem;
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

  .logs-list {
    display: flex;
    flex-direction: column;
    gap: 8px;
    max-height: 400px;
    overflow-y: auto;
  }
  .log-item {
    padding: 10px;
    background: rgba(22, 29, 49, 0.4);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-sm);
    font-size: 0.8125rem;
  }
  .log-top {
    display: flex;
    justify-content: space-between;
    margin-bottom: 4px;
  }
  .log-date {
    color: var(--text-muted);
  }
  .log-recip {
    color: var(--text-heading);
  }
  .log-msg {
    color: var(--text-primary);
    margin-top: 4px;
  }

  .modal-actions {
    display: flex;
    justify-content: flex-end;
    gap: 10px;
    margin-top: 0.75rem;
  }
  .modal-form {
    display: flex;
    flex-direction: column;
    gap: 1rem;
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
