<script lang="ts">
  import { onMount } from 'svelte';
  import { apiRequest, addToast } from '../api';
  import { icons } from '../utils/icons';
  import { currentLocale, t } from '../i18n/store';

  interface Tenant {
    id: number;
    code: string;
    name: string;
    status: 'active' | 'suspended' | 'trial' | 'expired';
    plan: string;
    maxTerminals: number;
    maxUsers: number;
    licenseKey: string;
    terminals?: Array<{ id: number; hardwareUuid: string; name: string; isActive: boolean; lastSeenAt: string }>;
    createdAt: string;
  }

  let tenants: Tenant[] = [];
  let loading = true;
  let showModal = false;
  let modalLoading = false;
  let searchQuery = '';

  // New Pharmacy Form
  let newCode = '';
  let newName = '';
  let newPlan = 'professional';
  let newMaxTerminals = 3;
  let newAdminUser = 'admin';
  let newAdminPass = 'admin123';

  // Telemetry stats
  let telemetry: any = null;

  // Manage Seats Modal State
  let showSeatsModal = false;
  let seatsTenant: Tenant | null = null;
  let seatsLoading = false;
  let seatsSavingQuota = false;
  let tenantTerminals: Array<{
    id: number;
    hardwareUuid: string;
    name: string;
    isActive: boolean;
    lastSeenAt: string;
    createdAt: string;
  }> = [];
  let editMaxTerminals = 1;
  let unlinkingTerminalId: number | null = null;

  onMount(async () => {
    await loadData();
  });

  async function loadData() {
    loading = true;
    try {
      const [tenantsRes, telemRes] = await Promise.all([
        apiRequest('/provider/api/tenants'),
        apiRequest('/provider/api/telemetry').catch(() => null),
      ]);
      tenants = Array.isArray(tenantsRes) ? tenantsRes : (tenantsRes?.data || []);
      telemetry = telemRes;
    } catch (e: any) {
      addToast(e.message || $t('toast.error'), 'error');
    } finally {
      loading = false;
    }
  }

  $: filteredTenants = tenants.filter((tenant) => {
    if (!searchQuery.trim()) return true;
    const q = searchQuery.toLowerCase();
    return (
      tenant.name.toLowerCase().includes(q) ||
      tenant.code.toLowerCase().includes(q) ||
      tenant.plan.toLowerCase().includes(q)
    );
  });

  async function handleCreateTenant() {
    if (!newCode.trim() || !newName.trim()) {
      addToast($currentLocale === 'ar' ? 'يرجى إدخال اسم الصيدلية والرمز التعريفي' : 'Please provide both pharmacy code and name.', 'error');
      return;
    }
    modalLoading = true;
    try {
      await apiRequest('/provider/api/tenants', {
        method: 'POST',
        body: JSON.stringify({
          code: newCode.trim().toLowerCase(),
          name: newName.trim(),
          plan: newPlan,
          maxTerminals: Number(newMaxTerminals) || 1,
          adminUsername: newAdminUser.trim(),
          adminPassword: newAdminPass.trim(),
        }),
      });
      addToast($currentLocale === 'ar' ? `تم تسجيل صيدلية '${newName}' بنجاح!` : `Pharmacy '${newName}' provisioned successfully!`, 'success');
      showModal = false;
      newCode = '';
      newName = '';
      await loadData();
    } catch (e: any) {
      addToast(e.message || 'Failed to provision pharmacy.', 'error');
    } finally {
      modalLoading = false;
    }
  }

  async function handleToggleStatus(tenant: Tenant) {
    const nextStatus = tenant.status === 'active' ? 'suspended' : 'active';
    try {
      await apiRequest(`/provider/api/tenants/${tenant.id}`, {
        method: 'PUT',
        body: JSON.stringify({ status: nextStatus }),
      });
      addToast($currentLocale === 'ar' ? `تم تغيير حالة الصيدلية إلى ${nextStatus}` : `Pharmacy '${tenant.name}' is now ${nextStatus}.`, 'success');
      await loadData();
    } catch (e: any) {
      addToast(e.message || $t('toast.error'), 'error');
    }
  }

  function copyToClipboard(text: string) {
    if (!text) return;
    navigator.clipboard.writeText(text);
    addToast($t('provider.act.copied'), 'info');
  }

  async function openManageSeats(tenant: Tenant) {
    seatsTenant = tenant;
    editMaxTerminals = tenant.maxTerminals || 1;
    showSeatsModal = true;
    seatsLoading = true;
    try {
      const res = await apiRequest(`/provider/api/tenants/${tenant.id}/terminals`);
      tenantTerminals = res.terminals || [];
      editMaxTerminals = res.maxTerminals || tenant.maxTerminals || 1;
      if (res.licenseKey && seatsTenant) {
        seatsTenant.licenseKey = res.licenseKey;
      }
    } catch (e: any) {
      addToast(e.message || $t('toast.error'), 'error');
    } finally {
      seatsLoading = false;
    }
  }

  async function handleSaveQuota() {
    if (!seatsTenant) return;
    if (editMaxTerminals < 1) {
      addToast($currentLocale === 'ar' ? 'يرجى إدخال عدد مقاعد صحيح (1 على الأقل)' : 'Please enter a valid seat quota (at least 1).', 'error');
      return;
    }
    seatsSavingQuota = true;
    try {
      const res = await apiRequest(`/provider/api/tenants/${seatsTenant.id}/seats`, {
        method: 'PUT',
        body: JSON.stringify({ maxTerminals: editMaxTerminals }),
      });
      if (res.licenseKey && seatsTenant) {
        seatsTenant.licenseKey = res.licenseKey;
      }
      if (seatsTenant) {
        seatsTenant.maxTerminals = editMaxTerminals;
      }
      addToast($t('provider.seats.quotaUpdated'), 'success');
      await loadData();
    } catch (e: any) {
      addToast(e.message || $t('toast.error'), 'error');
    } finally {
      seatsSavingQuota = false;
    }
  }

  async function handleUnlinkTerminal(terminal: { id: number; name: string; hardwareUuid: string }) {
    if (!seatsTenant) return;
    const confirmMsg = $t('provider.seats.unlinkConfirm');
    if (!confirm(confirmMsg)) return;

    unlinkingTerminalId = terminal.id;
    try {
      await apiRequest(`/provider/api/tenants/${seatsTenant.id}/terminals/${terminal.id}`, {
        method: 'DELETE',
      });
      tenantTerminals = tenantTerminals.filter(t => t.id !== terminal.id);
      addToast($t('provider.seats.unlinkedSuccess'), 'success');
      await loadData();
    } catch (e: any) {
      addToast(e.message || $t('toast.error'), 'error');
    } finally {
      unlinkingTerminalId = null;
    }
  }
</script>

<div class="pharmacies-dashboard animate-fade-in">
  <!-- Hero Section (Identical styling to Telemetry Cockpit) -->
  <div class="vuexy-card hero-banner">
    <div class="hero-content">
      <div class="hero-badge-row">
        <span class="hero-badge">
          <span class="pulse-dot"></span>
          {$t('provider.active')}
        </span>
        <span class="sync-badge">
          {@html icons.activity}
          <span>{$t('provider.kpi.operational')}</span>
        </span>
      </div>
      <h2>{$t('provider.title')}</h2>
      <p>{$t('provider.sub')}</p>
    </div>

    <div class="hero-controls">
      <button class="btn btn-secondary btn-sm" on:click={loadData} disabled={loading} title={$t('btn.refresh')}>
        {@html icons.refresh}
        <span class="refresh-label">{$t('btn.refresh')}</span>
      </button>
      <button class="btn btn-primary btn-sm" on:click={() => (showModal = true)}>
        {@html icons.plus}
        <span>{$t('provider.onboardBtn')}</span>
      </button>
    </div>
  </div>

  <!-- KPI Stat Pillars (4-Card Grid matching Telemetry) -->
  <div class="kpi-grid">
    <!-- Card 1: Total Tenants -->
    <div class="vuexy-card kpi-card border-primary">
      <div class="card-top">
        <div class="icon-wrap bg-primary-light text-primary">
          {@html icons.warehouse}
        </div>
        <span class="badge badge-primary">PostgreSQL 16</span>
      </div>
      <div class="card-body">
        <span class="metric-label">{$t('provider.kpi.totalTenants')}</span>
        <h3 class="metric-val text-primary">{telemetry?.tenants?.total ?? tenants.length}</h3>
        <div class="metric-meta">
          <span>{$t('provider.kpi.totalTenantsSub')}</span>
          <span class="status-tag status-active">ISOLATED</span>
        </div>
      </div>
    </div>

    <!-- Card 2: Active Subscriptions -->
    <div class="vuexy-card kpi-card border-info">
      <div class="card-top">
        <div class="icon-wrap bg-info-light text-info">
          {@html icons.activity}
        </div>
        <span class="badge badge-info">{$t('provider.kpi.operational')}</span>
      </div>
      <div class="card-body">
        <span class="metric-label">{$t('provider.kpi.activeSubs')}</span>
        <h3 class="metric-val text-info">{telemetry?.tenants?.active ?? tenants.filter(tenant => tenant.status === 'active').length}</h3>
        <div class="metric-meta">
          <span>{$t('provider.kpi.healthyLic')}</span>
          <span class="status-tag status-active">ACTIVE</span>
        </div>
      </div>
    </div>

    <!-- Card 3: POS Terminals Seats -->
    <div class="vuexy-card kpi-card border-warning">
      <div class="card-top">
        <div class="icon-wrap bg-warning-light text-warning">
          {@html icons.creditCard}
        </div>
        <span class="badge badge-warning">Hardware Seats</span>
      </div>
      <div class="card-body">
        <span class="metric-label">{$t('provider.kpi.posTerminals')}</span>
        <h3 class="metric-val text-warning">{telemetry?.terminals?.total ?? 1} <small class="unit">{$currentLocale === 'ar' ? 'نقطة بيع' : 'terminals'}</small></h3>
        <div class="metric-meta">
          <span>{$t('provider.kpi.hwSub')}</span>
          <span class="status-tag status-active">{$currentLocale === 'ar' ? 'مقفل' : 'LOCKED'}</span>
        </div>
      </div>
    </div>

    <!-- Card 4: Engine & Gateway Core -->
    <div class="vuexy-card kpi-card border-success">
      <div class="card-top">
        <div class="icon-wrap bg-success-light text-success">
          {@html icons.sync}
        </div>
        <span class="badge badge-success">Traefik v3 Edge</span>
      </div>
      <div class="card-body">
        <span class="metric-label">{$t('provider.kpi.coreEngine')}</span>
        <h3 class="metric-val text-success text-lg-title">AdonisJS v6</h3>
        <div class="metric-meta">
          <span>Node.js 24 • Docker Core</span>
          <span class="status-tag status-active">RUNNING</span>
        </div>
      </div>
    </div>
  </div>

  <!-- Main Content Card with Data Table -->
  <div class="vuexy-card section-card">
    <div class="panel-header">
      <div class="search-wrap">
        <span class="search-icon">{@html icons.search}</span>
        <input
          type="text"
          class="form-input search-input"
          placeholder={$t('provider.filterPlaceholder')}
          bind:value={searchQuery}
        />
        {#if searchQuery}
          <button class="clear-btn" on:click={() => (searchQuery = '')}>✕</button>
        {/if}
      </div>
      <div class="table-meta">
        {$currentLocale === 'ar' 
          ? `عرض ${filteredTenants.length} من إجمالي ${tenants.length} صيدلية` 
          : `Showing ${filteredTenants.length} of ${tenants.length} pharmacies`}
      </div>
    </div>

    <!-- Data Table Container -->
    <div class="table-responsive">
      <table class="data-table">
        <thead>
          <tr>
            <th>{$t('provider.th.details')}</th>
            <th>{$t('provider.th.subdomain')}</th>
            <th>{$t('provider.th.tier')}</th>
            <th>{$t('provider.th.quota')}</th>
            <th>{$t('provider.th.status')}</th>
            <th>{$t('provider.th.license')}</th>
            <th class="text-right">{$t('provider.th.actions')}</th>
          </tr>
        </thead>
        <tbody>
          {#if loading}
            <tr>
              <td colspan="7" class="loading-cell">
                <div class="spinner"></div>
                <p>{$t('table.loading')}</p>
              </td>
            </tr>
          {:else if filteredTenants.length === 0}
            <tr>
              <td colspan="7" class="empty-cell">
                <p>{$t('table.noData')}</p>
              </td>
            </tr>
          {:else}
            {#each filteredTenants as tenant}
              <tr>
                <!-- Pharmacy Details -->
                <td>
                  <div class="pharmacy-cell">
                    <div class="avatar-pharma">
                      {tenant.name.charAt(0).toUpperCase()}
                    </div>
                    <div>
                      <div class="pharma-name">{tenant.name}</div>
                      <div class="pharma-sub">ID: #{tenant.id} • {$currentLocale === 'ar' ? 'مسجلة في' : 'Registered'} {new Date(tenant.createdAt).toLocaleDateString($currentLocale === 'ar' ? 'ar-EG' : 'en-US')}</div>
                    </div>
                  </div>
                </td>

                <!-- Subdomain / Code -->
                <td>
                  <div class="code-pill">
                    <span class="subdomain-prefix">{tenant.code}</span>
                    <span class="domain-suffix">.mepharma.io</span>
                  </div>
                  <div class="local-access-hint">
                    <a href="http://{tenant.code}.localhost:8000" target="_blank" rel="noreferrer" class="local-link">
                      http://{tenant.code}.localhost:8000 ↗
                    </a>
                  </div>
                </td>

                <!-- Plan -->
                <td>
                  <span class="plan-pill plan-{tenant.plan.toLowerCase()}">
                    {tenant.plan.toUpperCase()}
                  </span>
                </td>

                <!-- Terminal Seats -->
                <td>
                  <div
                    class="seats-cell clickable-seats"
                    on:click={() => openManageSeats(tenant)}
                    title={$t('provider.seats.manageBtn')}
                  >
                    <div class="seats-counter">
                      <strong>{tenant.terminals?.length || 1}</strong> / {tenant.maxTerminals} {$currentLocale === 'ar' ? 'مقاعد' : 'seats'}
                      <span class="seats-gear-icon">{@html icons.monitor}</span>
                    </div>
                    <div class="progress-track">
                      <div
                        class="progress-fill"
                        style="width: {Math.min(100, Math.round(((tenant.terminals?.length || 1) / (tenant.maxTerminals || 1)) * 100))}%; background: {(tenant.terminals?.length || 1) >= (tenant.maxTerminals || 1) ? 'var(--color-warning, #f59e0b)' : 'var(--color-primary)'};"
                      ></div>
                    </div>
                  </div>
                </td>

                <!-- Status -->
                <td>
                  {#if tenant.status === 'active'}
                    <span class="badge badge-success">{$currentLocale === 'ar' ? 'نشط' : 'ACTIVE'}</span>
                  {:else}
                    <span class="badge badge-danger">{$currentLocale === 'ar' ? 'معلق' : 'SUSPENDED'}</span>
                  {/if}
                </td>

                <!-- License Key -->
                <td>
                  <div class="license-cell">
                    <code class="license-code" title={tenant.licenseKey}>
                      {tenant.licenseKey ? tenant.licenseKey.substring(0, 16) + '...' : ($currentLocale === 'ar' ? 'بدون ترخيص' : 'Unlicensed')}
                    </code>
                    {#if tenant.licenseKey}
                      <button
                        class="copy-btn"
                        on:click={() => copyToClipboard(tenant.licenseKey)}
                        title={$t('provider.act.copyKey')}
                      >
                        {@html icons.barcode}
                      </button>
                    {/if}
                  </div>
                </td>

                <!-- Actions -->
                <td class="text-right">
                  <div class="actions-cell">
                    <button
                      class="btn btn-sm btn-outline-warning"
                      on:click={() => openManageSeats(tenant)}
                      title={$t('provider.seats.manageBtn')}
                    >
                      {@html icons.monitor}
                      <span>{$t('provider.seats.manageBtn')}</span>
                    </button>
                    <a
                      href="http://{tenant.code}.localhost:8000"
                      target="_blank"
                      rel="noreferrer"
                      class="btn btn-sm btn-outline"
                      title="Open Pharmacy Dashboard"
                    >
                      {@html icons.externalLink}
                      <span>{$t('provider.act.openPortal')}</span>
                    </a>
                    <button
                      class="btn btn-sm {tenant.status === 'active' ? 'btn-danger' : 'btn-success'}"
                      on:click={() => handleToggleStatus(tenant)}
                    >
                      {tenant.status === 'active' ? $t('provider.act.suspend') : $t('provider.act.activate')}
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
</div>

<!-- Modal: Onboard New Pharmacy -->
{#if showModal}
  <div class="modal-backdrop" on:click|self={() => (showModal = false)}>
    <div class="modal-card vuexy-card animate-scale-up">
      <div class="modal-header">
        <div class="modal-title-group">
          <div class="modal-icon bg-primary-light">
            {@html icons.plus}
          </div>
          <div>
            <h3>{$t('provider.modal.title')}</h3>
            <p>{$t('provider.modal.sub')}</p>
          </div>
        </div>
        <button class="close-modal-btn" on:click={() => (showModal = false)}>✕</button>
      </div>

      <div class="modal-body">
        <div class="form-row">
          <div class="form-group">
            <label for="pharmacy-name">{$currentLocale === 'ar' ? 'اسم الصيدلية / المؤسسة *' : 'Pharmacy Business Name *'}</label>
            <input
              id="pharmacy-name"
              type="text"
              class="form-input"
              bind:value={newName}
              placeholder="e.g. Al-Amal Central Pharmacy"
            />
          </div>

          <div class="form-group">
            <label for="pharmacy-code">{$currentLocale === 'ar' ? 'النطاق الفرعي / رمز المشترك *' : 'Tenant Code / Subdomain *'}</label>
            <div class="input-addon-wrap">
              <input
                id="pharmacy-code"
                type="text"
                class="form-input font-mono"
                bind:value={newCode}
                placeholder="al_amal"
              />
              <span class="input-addon">.mepharma.io</span>
            </div>
            <span class="field-hint">PostgreSQL schema: <code>tenant_{newCode || 'slug'}</code></span>
          </div>
        </div>

        <div class="form-row">
          <div class="form-group">
            <label for="pharmacy-plan">{$currentLocale === 'ar' ? 'باقة الاشتراك' : 'Subscription Tier Plan'}</label>
            <select id="pharmacy-plan" class="form-select" bind:value={newPlan}>
              <option value="starter">{$currentLocale === 'ar' ? 'الأساسية Starter (جهاز واحد)' : 'Starter (1 terminal seat)'}</option>
              <option value="professional">{$currentLocale === 'ar' ? 'الاحترافية Professional (3 أجهزة)' : 'Professional (3 terminal seats)'}</option>
              <option value="enterprise">{$currentLocale === 'ar' ? 'المؤسسية Enterprise (أجهزة غير محدودة)' : 'Enterprise (Unlimited terminal seats)'}</option>
            </select>
          </div>

          <div class="form-group">
            <label for="max-terminals">{$currentLocale === 'ar' ? 'حصة نقاط البيع (الأجهزة)' : 'Terminal Seats Quota'}</label>
            <input
              id="max-terminals"
              type="number"
              class="form-input"
              bind:value={newMaxTerminals}
              min="1"
              max="50"
            />
          </div>
        </div>

        <div class="section-divider">
          <span>{$currentLocale === 'ar' ? 'بيانات مدير الفرع الأولية' : 'Initial Pharmacy Administrator Credentials'}</span>
        </div>

        <div class="form-row">
          <div class="form-group">
            <label for="admin-user">{$currentLocale === 'ar' ? 'اسم مستخدم المدير' : 'Branch Admin Username'}</label>
            <input id="admin-user" type="text" class="form-input" bind:value={newAdminUser} />
          </div>

          <div class="form-group">
            <label for="admin-pass">{$currentLocale === 'ar' ? 'كلمة المرور' : 'Branch Admin Password'}</label>
            <input id="admin-pass" type="password" class="form-input" bind:value={newAdminPass} />
          </div>
        </div>
      </div>

      <div class="modal-footer">
        <button class="btn btn-secondary btn-sm" on:click={() => (showModal = false)}>{$t('btn.cancel')}</button>
        <button class="btn btn-primary btn-sm" on:click={handleCreateTenant} disabled={modalLoading}>
          {modalLoading ? ($currentLocale === 'ar' ? 'جاري إنشاء المخطط والترخيص...' : 'Provisioning Schema & License...') : ($currentLocale === 'ar' ? 'تأكيد تسجيل الصيدلية' : 'Provision Pharmacy Instance')}
        </button>
      </div>
    </div>
  </div>
{/if}

<!-- Modal: Manage POS Seats & Terminals -->
{#if showSeatsModal && seatsTenant}
  <div class="modal-backdrop" on:click|self={() => (showSeatsModal = false)}>
    <div class="modal-card vuexy-card animate-scale-up modal-lg">
      <div class="modal-header">
        <div class="modal-title-group">
          <div class="modal-icon bg-warning-light text-warning">
            {@html icons.monitor}
          </div>
          <div>
            <h3>{$t('provider.seats.title')} — <span class="text-primary">{seatsTenant.name}</span></h3>
            <p>{$t('provider.seats.sub')} <code class="domain-badge">{seatsTenant.code}.mepharma.io</code></p>
          </div>
        </div>
        <button class="close-modal-btn" on:click={() => (showSeatsModal = false)}>✕</button>
      </div>

      <div class="modal-body">
        {#if seatsLoading}
          <div class="modal-loading-box">
            <div class="spinner"></div>
            <p>{$t('table.loading')}</p>
          </div>
        {:else}
          {@const activeCount = tenantTerminals.filter(t => t.isActive).length}
          {@const isFull = activeCount >= editMaxTerminals}

          <!-- Quota Alert & Visual Meter -->
          <div class="seats-overview-banner {isFull ? 'banner-warning' : 'banner-success'}">
            <div class="banner-icon-wrap">
              {@html isFull ? icons.alertTriangle : icons.check}
            </div>
            <div class="banner-content">
              <div class="banner-title">
                {isFull ? $t('provider.seats.quotaFull') : `✅ ${editMaxTerminals - activeCount} ${$t('provider.seats.quotaAvailable')}`}
              </div>
              <div class="banner-meta">
                {$currentLocale === 'ar' ? 'المقاعد المستخدمة حالياً:' : 'Currently occupied seats:'}
                <strong>{activeCount}</strong> / <strong>{editMaxTerminals}</strong>
                ({Math.min(100, Math.round((activeCount / (editMaxTerminals || 1)) * 100))}%)
              </div>
            </div>
            <div class="banner-progress-wrap">
              <div class="progress-track" style="height: 10px; width: 140px;">
                <div
                  class="progress-fill"
                  style="width: {Math.min(100, Math.round((activeCount / (editMaxTerminals || 1)) * 100))}%; background: {isFull ? '#f59e0b' : '#28c76f'};"
                ></div>
              </div>
            </div>
          </div>

          <!-- Section 1: Change / Expand Seat Quota -->
          <div class="quota-control-card">
            <div class="quota-label-group">
              <div class="quota-field-label">
                {@html icons.award}
                <span>{$t('provider.seats.quota')}</span>
              </div>
              <span class="quota-help-text">
                {$currentLocale === 'ar' ? 'تعديل الحد الأقصى لأجهزة نقاط البيع المسموح بربطها في نفس الوقت' : 'Adjust the maximum number of concurrent POS terminals permitted for this pharmacy'}
              </span>
            </div>

            <div class="quota-action-row">
              <div class="stepper-box">
                <button
                  type="button"
                  class="stepper-btn"
                  on:click={() => { if (editMaxTerminals > 1) editMaxTerminals--; }}
                  disabled={editMaxTerminals <= 1 || seatsSavingQuota}
                  title="Decrease seats"
                >
                  –
                </button>
                <input
                  type="number"
                  min="1"
                  max="100"
                  class="stepper-input"
                  bind:value={editMaxTerminals}
                  disabled={seatsSavingQuota}
                />
                <button
                  type="button"
                  class="stepper-btn"
                  on:click={() => { editMaxTerminals++; }}
                  disabled={seatsSavingQuota}
                  title="Increase seats"
                >
                  +
                </button>
              </div>

              <button
                type="button"
                class="btn btn-primary btn-sm"
                on:click={handleSaveQuota}
                disabled={seatsSavingQuota || editMaxTerminals === seatsTenant.maxTerminals}
              >
                {@html icons.sync}
                <span>{seatsSavingQuota ? $t('provider.seats.updatingQuota') : $t('provider.seats.updateQuota')}</span>
              </button>
            </div>
          </div>

          <!-- Section 2: Connected Terminals / Hardware List -->
          <div class="terminals-section">
            <div class="section-header-row">
              <h4>
                {@html icons.monitor}
                <span>{$t('provider.seats.active')} ({tenantTerminals.length})</span>
              </h4>
              <span class="terminal-note">
                {$currentLocale === 'ar' ? 'أجهزة معتمدة بالبصمة الرقمية' : 'Hardware Fingerprint Enforced Devices'}
              </span>
            </div>

            {#if tenantTerminals.length === 0}
              <div class="empty-terminals-card">
                {@html icons.monitor}
                <p>{$t('provider.seats.noDevices')}</p>
              </div>
            {:else}
              <div class="table-responsive">
                <table class="data-table terminals-table">
                  <thead>
                    <tr>
                      <th>{$t('provider.seats.device')}</th>
                      <th>{$t('provider.seats.hwUuid')}</th>
                      <th>{$t('provider.seats.lastSeen')}</th>
                      <th>{$t('provider.seats.status')}</th>
                      <th class="text-right">{$t('provider.seats.actions')}</th>
                    </tr>
                  </thead>
                  <tbody>
                    {#each tenantTerminals as term}
                      <tr>
                        <!-- Device Name -->
                        <td>
                          <div class="device-cell">
                            <span class="device-icon">{@html icons.monitor}</span>
                            <strong>{term.name}</strong>
                          </div>
                        </td>

                        <!-- UUID -->
                        <td>
                          <code class="uuid-code" title={term.hardwareUuid}>
                            {term.hardwareUuid}
                          </code>
                        </td>

                        <!-- Last Seen -->
                        <td>
                          <span class="last-seen-text">
                            {term.lastSeenAt ? new Date(term.lastSeenAt).toLocaleString($currentLocale === 'ar' ? 'ar-EG' : 'en-US') : '—'}
                          </span>
                        </td>

                        <!-- Status -->
                        <td>
                          {#if term.isActive}
                            <span class="badge badge-success">
                              <span class="online-dot"></span>
                              {$currentLocale === 'ar' ? 'معتمد' : 'ACTIVE'}
                            </span>
                          {:else}
                            <span class="badge badge-secondary">
                              {$currentLocale === 'ar' ? 'غير نشط' : 'INACTIVE'}
                            </span>
                          {/if}
                        </td>

                        <!-- Unlink Action -->
                        <td class="text-right">
                          <button
                            type="button"
                            class="btn btn-sm btn-danger-outline"
                            on:click={() => handleUnlinkTerminal(term)}
                            disabled={unlinkingTerminalId === term.id}
                            title={$t('provider.seats.unlinkBtn')}
                          >
                            {@html icons.unlink}
                            <span>{unlinkingTerminalId === term.id ? ($currentLocale === 'ar' ? 'جاري الفك...' : 'Unlinking...') : $t('provider.seats.unlinkBtn')}</span>
                          </button>
                        </td>
                      </tr>
                    {/each}
                  </tbody>
                </table>
              </div>
            {/if}
          </div>

          <!-- Section 3: Hardware Swap Guidance -->
          <div class="swap-guidance-card">
            <div class="guidance-title">
              {@html icons.refresh}
              <span>{$t('provider.seats.howToSwap')}</span>
            </div>
            <ol class="guidance-steps">
              <li>{$t('provider.seats.step1')}</li>
              <li>{$t('provider.seats.step2')}</li>
              <li>{$t('provider.seats.step3')}</li>
            </ol>
          </div>

          <!-- Section 4: Cryptographic License Token -->
          <div class="license-copy-card">
            <div class="license-copy-label">
              {@html icons.key}
              <span>{$t('provider.seats.licenseKeyHint')}</span>
            </div>
            <div class="license-copy-row">
              <code class="license-full-token">{seatsTenant.licenseKey}</code>
              <button
                type="button"
                class="btn btn-sm btn-primary"
                on:click={() => copyToClipboard(seatsTenant.licenseKey)}
              >
                {@html icons.barcode}
                <span>{$t('provider.act.copyKey')}</span>
              </button>
            </div>
          </div>
        {/if}
      </div>

      <div class="modal-footer">
        <button class="btn btn-secondary btn-sm" on:click={() => (showSeatsModal = false)}>
          {$t('btn.cancel')}
        </button>
      </div>
    </div>
  </div>
{/if}

<style>
  .pharmacies-dashboard {
    display: flex;
    flex-direction: column;
    gap: 24px;
    width: 100%;
    max-width: 100%;
    min-width: 0;
  }

  /* Hero Banner matching Telemetry Cockpit */
  .hero-banner {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 24px 28px;
    background: linear-gradient(135deg, rgba(30, 41, 59, 0.7) 0%, rgba(15, 23, 42, 0.9) 100%);
    border: 1px solid rgba(255, 255, 255, 0.08);
    border-radius: 12px;
  }

  .hero-content h2 {
    margin: 0 0 6px 0;
    font-size: 1.4rem;
    font-weight: 700;
    color: #f1f5f9;
  }

  .hero-content p {
    margin: 0;
    font-size: 0.88rem;
    color: #94a3b8;
  }

  .hero-badge-row {
    display: flex;
    align-items: center;
    gap: 10px;
    margin-bottom: 8px;
  }

  .hero-badge {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    padding: 4px 10px;
    border-radius: 20px;
    background: rgba(16, 185, 129, 0.15);
    color: #10b981;
    font-size: 0.75rem;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }

  .pulse-dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    background: #10b981;
    box-shadow: 0 0 8px #10b981;
    animation: pulse 2s infinite;
  }

  .sync-badge {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    padding: 4px 10px;
    border-radius: 20px;
    background: rgba(59, 130, 246, 0.15);
    color: #3b82f6;
    font-size: 0.75rem;
    font-weight: 600;
  }

  .hero-controls {
    display: flex;
    align-items: center;
    gap: 12px;
    flex-shrink: 0;
  }

  /* KPI Stat Pillars (Identical sizing to Telemetry cards) */
  .kpi-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
    gap: 20px;
    width: 100%;
    max-width: 100%;
    box-sizing: border-box;
  }

  .kpi-card {
    padding: 20px;
    border-radius: 12px;
    background: var(--bg-card);
    border: 1px solid rgba(255, 255, 255, 0.08);
    display: flex;
    flex-direction: column;
    gap: 16px;
    min-width: 0;
    box-sizing: border-box;
  }

  .border-primary { border-top: 3px solid var(--color-primary); }
  .border-success { border-top: 3px solid var(--color-success); }
  .border-info { border-top: 3px solid var(--color-info); }
  .border-warning { border-top: 3px solid var(--color-warning); }

  .card-top {
    display: flex;
    align-items: center;
    justify-content: space-between;
  }

  .icon-wrap {
    width: 42px;
    height: 42px;
    border-radius: 10px;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .bg-primary-light { background: rgba(115, 103, 240, 0.15); color: #7367f0; }
  .bg-success-light { background: rgba(40, 199, 111, 0.15); color: #28c76f; }
  .bg-info-light { background: rgba(0, 207, 232, 0.15); color: #00cfe8; }
  .bg-warning-light { background: rgba(255, 159, 67, 0.15); color: #ff9f43; }

  .metric-label {
    font-size: 0.8rem;
    text-transform: uppercase;
    font-weight: 700;
    letter-spacing: 0.5px;
    color: #94a3b8;
  }

  .metric-val {
    font-size: 1.8rem;
    font-weight: 800;
    margin: 4px 0 8px 0;
  }

  .metric-val .unit {
    font-size: 0.9rem;
    font-weight: 500;
    color: #94a3b8;
  }

  .text-lg-title {
    font-size: 1.4rem;
  }

  .metric-meta {
    display: flex;
    align-items: center;
    justify-content: space-between;
    font-size: 0.8rem;
    color: #94a3b8;
  }

  .status-tag {
    padding: 2px 8px;
    border-radius: 4px;
    font-size: 0.7rem;
    font-weight: 700;
    letter-spacing: 0.5px;
  }

  .status-active {
    background: rgba(40, 199, 111, 0.15);
    color: #28c76f;
  }

  /* Table Section Card */
  .section-card {
    padding: 24px;
    border-radius: 12px;
    background: var(--bg-card);
    border: 1px solid rgba(255, 255, 255, 0.08);
    display: flex;
    flex-direction: column;
    gap: 16px;
    min-width: 0;
    max-width: 100%;
    width: 100%;
    overflow: hidden;
    box-sizing: border-box;
  }

  .panel-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 16px;
    flex-wrap: wrap;
  }

  .search-wrap {
    flex: 1;
    min-width: 260px;
    max-width: 480px;
    display: flex;
    align-items: center;
    gap: 10px;
    background: rgba(15, 23, 42, 0.4);
    border: 1px solid rgba(255, 255, 255, 0.08);
    border-radius: 8px;
    padding: 0 12px;
    color: #94a3b8;
  }

  .search-wrap:focus-within {
    border-color: var(--color-primary);
  }

  .search-input {
    border: none;
    background: transparent;
    padding: 10px 0;
    width: 100%;
    color: #f1f5f9;
  }

  .search-input:focus {
    outline: none;
  }

  .clear-btn {
    border: none;
    background: transparent;
    color: #94a3b8;
    cursor: pointer;
  }

  .table-meta {
    font-size: 0.8125rem;
    color: #94a3b8;
  }

  /* Responsive Table Container */
  .table-responsive {
    width: 100%;
    max-width: 100%;
    min-width: 0;
    overflow-x: auto;
    border-radius: 8px;
    border: 1px solid rgba(255, 255, 255, 0.05);
    display: block;
    -webkit-overflow-scrolling: touch;
    box-sizing: border-box;
  }

  .data-table {
    width: 100%;
    min-width: 820px;
    border-collapse: collapse;
    font-size: 0.88rem;
  }

  .data-table th {
    text-align: left;
    padding: 12px 14px;
    color: #94a3b8;
    font-size: 0.75rem;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    border-bottom: 1px solid rgba(255, 255, 255, 0.08);
    background: rgba(15, 23, 42, 0.3);
    white-space: nowrap;
  }

  :global(.rtl-mode) .data-table th {
    text-align: right;
  }

  .data-table td {
    padding: 14px;
    border-bottom: 1px solid rgba(255, 255, 255, 0.05);
    vertical-align: middle;
  }

  .pharmacy-cell {
    display: flex;
    align-items: center;
    gap: 12px;
  }

  .avatar-pharma {
    width: 36px;
    height: 36px;
    border-radius: 8px;
    background: rgba(115, 103, 240, 0.15);
    color: var(--color-primary);
    font-weight: 700;
    font-size: 1rem;
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
  }

  .pharma-name {
    font-weight: 700;
    color: #f1f5f9;
  }

  .pharma-sub {
    font-size: 0.75rem;
    color: #64748b;
    margin-top: 2px;
  }

  .code-pill {
    display: inline-flex;
    align-items: center;
    font-family: var(--font-mono);
    font-size: 0.8125rem;
    font-weight: 600;
  }

  .subdomain-prefix {
    color: var(--color-primary);
  }

  .domain-suffix {
    color: #64748b;
  }

  .local-access-hint {
    margin-top: 4px;
  }

  .local-link {
    font-size: 0.75rem;
    color: #00cfe8;
    text-decoration: none;
    font-family: var(--font-mono);
  }

  .local-link:hover {
    text-decoration: underline;
  }

  .plan-pill {
    display: inline-block;
    padding: 3px 8px;
    border-radius: 20px;
    font-size: 0.7rem;
    font-weight: 700;
    letter-spacing: 0.04em;
  }

  .plan-starter { background: rgba(130, 134, 139, 0.15); color: #82868b; }
  .plan-professional { background: rgba(0, 207, 232, 0.15); color: #00cfe8; }
  .plan-enterprise { background: rgba(115, 103, 240, 0.15); color: #7367f0; }

  .seats-cell {
    min-width: 110px;
  }

  .seats-counter {
    font-size: 0.8125rem;
    margin-bottom: 6px;
    color: #94a3b8;
  }

  .seats-counter strong {
    color: #f1f5f9;
  }

  .progress-track {
    width: 100%;
    height: 5px;
    background: rgba(255, 255, 255, 0.1);
    border-radius: 3px;
    overflow: hidden;
  }

  .progress-fill {
    height: 100%;
    border-radius: 3px;
    transition: width 0.3s ease;
  }

  .license-cell {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .license-code {
    background: rgba(15, 23, 42, 0.6);
    padding: 4px 8px;
    border-radius: 4px;
    font-family: var(--font-mono);
    font-size: 0.75rem;
    color: #38bdf8;
    border: 1px solid rgba(255, 255, 255, 0.08);
  }

  .copy-btn {
    border: none;
    background: transparent;
    cursor: pointer;
    color: #94a3b8;
    padding: 4px;
    border-radius: 4px;
    display: flex;
    align-items: center;
  }

  .copy-btn:hover {
    color: var(--color-primary);
  }

  .actions-cell {
    display: inline-flex;
    align-items: center;
    gap: 8px;
  }

  .text-right {
    text-align: right;
  }

  :global(.rtl-mode) .text-right {
    text-align: left;
  }

  .btn-outline {
    background: rgba(255, 255, 255, 0.05);
    border: 1px solid rgba(255, 255, 255, 0.1);
    color: #f1f5f9;
    text-decoration: none;
  }

  .btn-outline:hover {
    background: rgba(115, 103, 240, 0.15);
    border-color: var(--color-primary);
    color: var(--color-primary);
  }

  .badge-success { background: rgba(40, 199, 111, 0.15); color: #28c76f; }
  .badge-danger { background: rgba(234, 84, 85, 0.15); color: #ea5455; }
  .badge-primary { background: rgba(115, 103, 240, 0.15); color: #7367f0; }
  .badge-info { background: rgba(0, 207, 232, 0.15); color: #00cfe8; }

  .loading-cell, .empty-cell {
    text-align: center;
    padding: 48px 16px !important;
    color: #94a3b8;
  }

  /* Modal */
  .modal-backdrop {
    position: fixed;
    inset: 0;
    background: rgba(15, 23, 42, 0.75);
    backdrop-filter: blur(4px);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 999;
    padding: 16px;
  }

  .modal-card {
    width: 100%;
    max-width: 600px;
    border-radius: 12px;
    box-shadow: 0 10px 30px rgba(0, 0, 0, 0.5);
    border: 1px solid rgba(255, 255, 255, 0.1);
    background: var(--bg-card);
    padding: 0;
    overflow: hidden;
  }

  .modal-header {
    padding: 20px 24px;
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    border-bottom: 1px solid rgba(255, 255, 255, 0.08);
  }

  .modal-title-group {
    display: flex;
    align-items: center;
    gap: 14px;
  }

  .modal-icon {
    width: 42px;
    height: 42px;
    border-radius: 10px;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .modal-title-group h3 {
    margin: 0;
    font-size: 1.15rem;
    font-weight: 700;
    color: #f1f5f9;
  }

  .modal-title-group p {
    margin: 3px 0 0 0;
    font-size: 0.8125rem;
    color: #94a3b8;
  }

  .close-modal-btn {
    border: none;
    background: transparent;
    color: #94a3b8;
    font-size: 1.1rem;
    cursor: pointer;
  }

  .modal-body {
    padding: 24px;
    display: flex;
    flex-direction: column;
    gap: 16px;
    max-height: 70vh;
    overflow-y: auto;
  }

  .form-row {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 16px;
  }

  .input-addon-wrap {
    display: flex;
    align-items: center;
  }

  .input-addon-wrap .form-input {
    border-top-right-radius: 0;
    border-bottom-right-radius: 0;
  }

  :global(.rtl-mode) .input-addon-wrap .form-input {
    border-radius: 0 8px 8px 0;
  }

  .input-addon {
    background: rgba(15, 23, 42, 0.6);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-left: none;
    padding: 10px 12px;
    font-size: 0.8125rem;
    color: #94a3b8;
    border-top-right-radius: 8px;
    border-bottom-right-radius: 8px;
    font-family: var(--font-mono);
  }

  :global(.rtl-mode) .input-addon {
    border-left: 1px solid rgba(255, 255, 255, 0.1);
    border-right: none;
    border-radius: 8px 0 0 8px;
  }

  .field-hint {
    display: block;
    margin-top: 4px;
    font-size: 0.72rem;
    color: #94a3b8;
  }

  .field-hint code {
    background: rgba(15, 23, 42, 0.6);
    padding: 1px 4px;
    border-radius: 3px;
    color: var(--color-primary);
  }

  .section-divider {
    border-top: 1px dashed rgba(255, 255, 255, 0.1);
    margin: 8px 0;
    text-align: center;
  }

  .section-divider span {
    background: var(--bg-card);
    padding: 0 12px;
    position: relative;
    top: -10px;
    font-size: 0.75rem;
    font-weight: 700;
    color: #94a3b8;
    text-transform: uppercase;
    letter-spacing: 0.04em;
  }

  .modal-footer {
    padding: 16px 24px;
    display: flex;
    align-items: center;
    justify-content: flex-end;
    gap: 12px;
    border-top: 1px solid rgba(255, 255, 255, 0.08);
    background: rgba(15, 23, 42, 0.4);
  }

  @keyframes pulse {
    0%, 100% { opacity: 1; transform: scale(1); }
    50% { opacity: 0.5; transform: scale(0.9); }
  }

  /* Manage Seats & Terminals Enhancements */
  .modal-lg {
    max-width: 820px;
  }

  .clickable-seats {
    cursor: pointer;
    padding: 6px 10px;
    border-radius: 8px;
    transition: all 0.2s ease;
    border: 1px solid transparent;
  }

  .clickable-seats:hover {
    background: rgba(245, 158, 11, 0.08);
    border-color: rgba(245, 158, 11, 0.25);
  }

  .seats-gear-icon {
    display: inline-flex;
    vertical-align: middle;
    margin-left: 6px;
    opacity: 0.6;
    color: #f59e0b;
  }

  :global(.rtl-mode) .seats-gear-icon {
    margin-left: 0;
    margin-right: 6px;
  }

  .clickable-seats:hover .seats-gear-icon {
    opacity: 1;
    transform: rotate(30deg);
  }

  .btn-outline-warning {
    background: rgba(245, 158, 11, 0.1);
    border: 1px solid rgba(245, 158, 11, 0.3);
    color: #f59e0b;
  }

  .btn-outline-warning:hover {
    background: rgba(245, 158, 11, 0.2);
    border-color: #f59e0b;
    color: #fbbf24;
  }

  .btn-danger-outline {
    background: rgba(234, 84, 85, 0.08);
    border: 1px solid rgba(234, 84, 85, 0.25);
    color: #ea5455;
  }

  .btn-danger-outline:hover:not(:disabled) {
    background: rgba(234, 84, 85, 0.2);
    border-color: #ea5455;
    color: #ff6b6b;
  }

  /* Seats Overview Banner */
  .seats-overview-banner {
    display: flex;
    align-items: center;
    gap: 16px;
    padding: 16px 20px;
    border-radius: 10px;
    margin-bottom: 20px;
    border: 1px solid;
  }

  .banner-warning {
    background: linear-gradient(135deg, rgba(245, 158, 11, 0.12) 0%, rgba(217, 119, 6, 0.06) 100%);
    border-color: rgba(245, 158, 11, 0.35);
    color: #fbbf24;
  }

  .banner-success {
    background: linear-gradient(135deg, rgba(40, 199, 111, 0.12) 0%, rgba(16, 185, 129, 0.06) 100%);
    border-color: rgba(40, 199, 111, 0.35);
    color: #34d399;
  }

  .banner-icon-wrap {
    width: 38px;
    height: 38px;
    border-radius: 8px;
    display: flex;
    align-items: center;
    justify-content: center;
    background: rgba(255, 255, 255, 0.08);
    flex-shrink: 0;
  }

  .banner-content {
    flex: 1;
  }

  .banner-title {
    font-size: 0.95rem;
    font-weight: 700;
    line-height: 1.4;
    color: #f8fafc;
  }

  .banner-meta {
    font-size: 0.82rem;
    margin-top: 3px;
    color: #94a3b8;
  }

  .banner-meta strong {
    color: #f1f5f9;
  }

  /* Quota Control Card */
  .quota-control-card {
    background: rgba(15, 23, 42, 0.4);
    border: 1px solid rgba(255, 255, 255, 0.08);
    border-radius: 10px;
    padding: 16px 20px;
    margin-bottom: 24px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    flex-wrap: wrap;
    gap: 16px;
  }

  .quota-label-group {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  .quota-field-label {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 0.95rem;
    font-weight: 700;
    color: #f1f5f9;
  }

  .quota-help-text {
    font-size: 0.78rem;
    color: #94a3b8;
  }

  .quota-action-row {
    display: flex;
    align-items: center;
    gap: 14px;
  }

  .stepper-box {
    display: inline-flex;
    align-items: center;
    background: rgba(15, 23, 42, 0.8);
    border: 1px solid rgba(255, 255, 255, 0.15);
    border-radius: 8px;
    overflow: hidden;
  }

  .stepper-btn {
    border: none;
    background: transparent;
    color: #f1f5f9;
    font-size: 1.1rem;
    font-weight: 700;
    width: 36px;
    height: 38px;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: background 0.15s ease;
  }

  .stepper-btn:hover:not(:disabled) {
    background: rgba(255, 255, 255, 0.1);
    color: var(--color-primary);
  }

  .stepper-btn:disabled {
    opacity: 0.35;
    cursor: not-allowed;
  }

  .stepper-input {
    border: none;
    background: transparent;
    color: #f1f5f9;
    font-size: 1.05rem;
    font-weight: 700;
    width: 54px;
    text-align: center;
    outline: none;
    -moz-appearance: textfield;
  }

  .stepper-input::-webkit-outer-spin-button,
  .stepper-input::-webkit-inner-spin-button {
    -webkit-appearance: none;
    margin: 0;
  }

  /* Terminals Section */
  .terminals-section {
    margin-bottom: 24px;
  }

  .section-header-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 12px;
  }

  .section-header-row h4 {
    margin: 0;
    font-size: 0.95rem;
    font-weight: 700;
    color: #f1f5f9;
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .terminal-note {
    font-size: 0.75rem;
    color: #64748b;
  }

  .terminals-table {
    min-width: 100%;
  }

  .device-cell {
    display: flex;
    align-items: center;
    gap: 8px;
    color: #f1f5f9;
  }

  .device-icon {
    color: #7367f0;
    display: flex;
  }

  .uuid-code {
    background: rgba(15, 23, 42, 0.7);
    padding: 3px 8px;
    border-radius: 4px;
    font-family: var(--font-mono);
    font-size: 0.75rem;
    color: #38bdf8;
    border: 1px solid rgba(255, 255, 255, 0.08);
  }

  .last-seen-text {
    font-size: 0.78rem;
    color: #94a3b8;
  }

  .online-dot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    background: #28c76f;
    display: inline-block;
    margin-right: 5px;
    box-shadow: 0 0 6px rgba(40, 199, 111, 0.6);
  }

  :global(.rtl-mode) .online-dot {
    margin-right: 0;
    margin-left: 5px;
  }

  .empty-terminals-card {
    text-align: center;
    padding: 32px 16px;
    background: rgba(15, 23, 42, 0.3);
    border: 1px dashed rgba(255, 255, 255, 0.1);
    border-radius: 10px;
    color: #94a3b8;
  }

  .empty-terminals-card p {
    margin: 8px 0 0 0;
    font-size: 0.85rem;
  }

  /* Swap Guidance Card */
  .swap-guidance-card {
    background: rgba(115, 103, 240, 0.06);
    border: 1px solid rgba(115, 103, 240, 0.2);
    border-radius: 10px;
    padding: 14px 18px;
    margin-bottom: 20px;
  }

  .guidance-title {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 0.85rem;
    font-weight: 700;
    color: #a5b4fc;
    margin-bottom: 8px;
  }

  .guidance-steps {
    margin: 0;
    padding-left: 20px;
    font-size: 0.8rem;
    color: #cbd5e1;
    line-height: 1.6;
  }

  :global(.rtl-mode) .guidance-steps {
    padding-left: 0;
    padding-right: 20px;
  }

  /* License Key Copy Card */
  .license-copy-card {
    background: rgba(15, 23, 42, 0.5);
    border: 1px solid rgba(255, 255, 255, 0.08);
    border-radius: 10px;
    padding: 14px 18px;
  }

  .license-copy-label {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 0.82rem;
    font-weight: 700;
    color: #94a3b8;
    margin-bottom: 8px;
  }

  .license-copy-row {
    display: flex;
    align-items: center;
    gap: 10px;
  }

  .license-full-token {
    flex: 1;
    background: rgba(15, 23, 42, 0.8);
    padding: 8px 12px;
    border-radius: 6px;
    font-family: var(--font-mono);
    font-size: 0.72rem;
    color: #38bdf8;
    border: 1px solid rgba(255, 255, 255, 0.08);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .domain-badge {
    background: rgba(115, 103, 240, 0.15);
    color: var(--color-primary);
    padding: 2px 6px;
    border-radius: 4px;
    font-family: var(--font-mono);
    font-size: 0.78rem;
  }

  .modal-loading-box {
    text-align: center;
    padding: 48px 16px;
    color: #94a3b8;
  }
</style>
