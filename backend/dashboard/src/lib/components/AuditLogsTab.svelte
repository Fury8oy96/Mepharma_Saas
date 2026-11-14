<script lang="ts">
  import { onMount } from 'svelte';
  import { apiRequest, addToast } from '../api';
  import { icons } from '../utils/icons';
  import { t, currentLocale } from '../i18n/store';

  let logs: any[] = [];
  let loading = true;
  let searchQuery = '';
  let selectedAction = '';
  let selectedLimit = 50;
  let expandedRowId: number | null = null;

  async function loadLogs() {
    loading = true;
    try {
      const params = new URLSearchParams();
      if (searchQuery.trim()) params.set('search', searchQuery.trim());
      if (selectedAction) params.set('action', selectedAction);
      if (selectedLimit) params.set('limit', String(selectedLimit));

      const res = await apiRequest(`/provider/api/audit-logs?${params.toString()}`);
      logs = Array.isArray(res) ? res : (Array.isArray(res?.data) ? res.data : []);
    } catch (err: any) {
      addToast(err.message || $t('toast.error'), 'error');
      logs = [];
    } finally {
      loading = false;
    }
  }

  function toggleExpand(id: number) {
    expandedRowId = expandedRowId === id ? null : id;
  }

  function getActionBadgeClass(action: string): string {
    const act = (action || '').toUpperCase();
    if (act.includes('PROVISIONED') || act.includes('CREATE')) return 'badge-primary';
    if (act.includes('ACTIVE') || act.includes('RESTORE')) return 'badge-success';
    if (act.includes('SUSPEND') || act.includes('DELETE')) return 'badge-danger';
    if (act.includes('LICENSE')) return 'badge-info';
    return 'badge-secondary';
  }

  function formatTime(isoStr: string): string {
    if (!isoStr) return '--';
    const d = new Date(isoStr);
    return d.toLocaleString($currentLocale === 'ar' ? 'ar-EG' : 'en-US', {
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit'
    });
  }

  onMount(loadLogs);
</script>

<div class="audit-tab-container animate-fade-in">
  <!-- Header Bar -->
  <div class="vuexy-card hero-banner">
    <div class="hero-content">
      <div class="hero-badge-row">
        <span class="hero-badge">
          {@html icons.shield}
          <span>{$t('audit.title')}</span>
        </span>
      </div>
      <h2>{$t('audit.title')}</h2>
      <p>{$t('audit.sub')}</p>
    </div>

    <div class="hero-controls">
      <button class="btn btn-secondary btn-sm" on:click={loadLogs} title={$t('btn.refresh')}>
        {@html icons.refresh}
        <span class="refresh-label">{$t('btn.refresh')}</span>
      </button>
    </div>
  </div>

  <!-- Filter & Search Toolbar -->
  <div class="vuexy-card filter-toolbar">
    <div class="search-wrap">
      {@html icons.search}
      <input 
        type="text" 
        class="form-input search-input" 
        placeholder={$t('audit.search')} 
        bind:value={searchQuery}
        on:keydown={(e) => e.key === 'Enter' && loadLogs()}
      />
    </div>

    <div class="filter-actions">
      <select class="form-input select-filter" bind:value={selectedAction} on:change={loadLogs}>
        <option value="">{$t('audit.filterAll')}</option>
        <option value="TENANT_PROVISIONED">TENANT_PROVISIONED</option>
        <option value="LICENSE_GENERATED">LICENSE_GENERATED</option>
        <option value="TENANT_SUSPENDED">TENANT_SUSPENDED</option>
        <option value="TENANT_ACTIVATED">TENANT_ACTIVATED</option>
        <option value="DATABASE_MIGRATION">DATABASE_MIGRATION</option>
        <option value="SYSTEM_BACKUP">SYSTEM_BACKUP</option>
      </select>

      <select class="form-input select-limit" bind:value={selectedLimit} on:change={loadLogs}>
        <option value={25}>25 {$currentLocale === 'ar' ? 'سجل' : 'rows'}</option>
        <option value={50}>50 {$currentLocale === 'ar' ? 'سجل' : 'rows'}</option>
        <option value={100}>100 {$currentLocale === 'ar' ? 'سجل' : 'rows'}</option>
      </select>

      <button class="btn btn-primary" on:click={loadLogs}>
        {@html icons.search} {$t('btn.search')}
      </button>
    </div>
  </div>

  <!-- Logs Table -->
  <div class="vuexy-card table-panel">
    {#if loading}
      <div class="loading-state">
        <div class="spinner"></div>
        <p>{$t('table.loading')}</p>
      </div>
    {:else if logs.length === 0}
      <div class="empty-state">
        <p>{$t('table.noData')}</p>
      </div>
    {:else}
      <div class="table-responsive">
        <table class="data-table">
          <thead>
            <tr>
              <th>{$t('audit.th.timestamp')}</th>
              <th>{$t('audit.th.actor')}</th>
              <th>{$t('audit.th.action')}</th>
              <th>{$t('audit.th.entity')}</th>
              <th>{$t('audit.th.details')}</th>
              <th>{$t('audit.th.ip')}</th>
            </tr>
          </thead>
          <tbody>
            {#each logs as log}
              <tr>
                <td class="cell-time">{formatTime(log.created_at)}</td>
                <td>
                  <span class="user-chip-mini">
                    <span class="actor-avatar">{(log.actor_username || 'U')[0].toUpperCase()}</span>
                    <span class="actor-name">{log.actor_username}</span>
                  </span>
                </td>
                <td>
                  <span class="badge {getActionBadgeClass(log.action)}">
                    {log.action}
                  </span>
                </td>
                <td>
                  <span class="entity-tag">
                    <code>{log.entity_type}:{log.entity_id}</code>
                  </span>
                </td>
                <td class="cell-details">
                  <div class="details-summary">
                    {#if typeof log.details === 'object' && log.details !== null}
                      <button class="btn-link" on:click={() => toggleExpand(log.id)}>
                        {expandedRowId === log.id
                          ? ($currentLocale === 'ar' ? 'إخفاء JSON' : 'Hide JSON')
                          : ($currentLocale === 'ar' ? `عرض التفاصيل (${Object.keys(log.details).length})` : 'View Payload (' + Object.keys(log.details).length + ' keys)')}
                      </button>
                      {#if expandedRowId === log.id}
                        <pre class="json-viewer">{JSON.stringify(log.details, null, 2)}</pre>
                      {/if}
                    {:else}
                      <span class="text-muted">{String(log.details || '—')}</span>
                    {/if}
                  </div>
                </td>
                <td class="cell-ip">
                  <span class="ip-tag">{log.ip_address || '127.0.0.1'}</span>
                </td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
    {/if}
  </div>
</div>

<style>
  .audit-tab-container {
    display: flex;
    flex-direction: column;
    gap: 20px;
  }

  .hero-banner {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 24px 28px;
    background: linear-gradient(135deg, rgba(30, 41, 59, 0.7) 0%, rgba(15, 23, 42, 0.9) 100%);
    border: 1px solid rgba(255, 255, 255, 0.08);
    border-radius: 12px;
  }

  .hero-badge-row {
    margin-bottom: 8px;
  }

  .hero-badge {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    padding: 4px 10px;
    border-radius: 20px;
    background: rgba(115, 103, 240, 0.15);
    color: var(--color-primary);
    font-size: 0.75rem;
    font-weight: 700;
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

  .filter-toolbar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 16px;
    padding: 16px 20px;
    border-radius: 12px;
    background: var(--bg-card);
    border: 1px solid rgba(255, 255, 255, 0.08);
    flex-wrap: wrap;
  }

  .search-wrap {
    flex: 1;
    min-width: 260px;
    display: flex;
    align-items: center;
    gap: 10px;
    background: rgba(15, 23, 42, 0.4);
    border: 1px solid rgba(255, 255, 255, 0.08);
    border-radius: 8px;
    padding: 0 12px;
    color: #94a3b8;
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

  .filter-actions {
    display: flex;
    align-items: center;
    gap: 12px;
  }

  .select-filter, .select-limit {
    padding: 9px 12px;
    background: rgba(15, 23, 42, 0.4);
    border: 1px solid rgba(255, 255, 255, 0.08);
    border-radius: 8px;
    color: #f1f5f9;
  }

  .table-panel {
    padding: 20px;
    border-radius: 12px;
    background: var(--bg-card);
    border: 1px solid rgba(255, 255, 255, 0.08);
  }

  .data-table {
    width: 100%;
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
  }

  :global(.rtl-mode) .data-table th {
    text-align: right;
  }

  .data-table td {
    padding: 14px;
    border-bottom: 1px solid rgba(255, 255, 255, 0.05);
    vertical-align: middle;
  }

  .cell-time {
    font-family: var(--font-mono);
    font-size: 0.8rem;
    color: #94a3b8;
    white-space: nowrap;
  }

  .user-chip-mini {
    display: inline-flex;
    align-items: center;
    gap: 8px;
  }

  .actor-avatar {
    width: 26px;
    height: 26px;
    border-radius: 50%;
    background: rgba(115, 103, 240, 0.2);
    color: var(--color-primary);
    display: flex;
    align-items: center;
    justify-content: center;
    font-weight: 700;
    font-size: 0.75rem;
  }

  .actor-name {
    font-weight: 600;
    color: #f1f5f9;
  }

  .badge-primary { background: rgba(115, 103, 240, 0.15); color: #7367f0; }
  .badge-success { background: rgba(40, 199, 111, 0.15); color: #28c76f; }
  .badge-danger { background: rgba(234, 84, 85, 0.15); color: #ea5455; }
  .badge-info { background: rgba(0, 207, 232, 0.15); color: #00cfe8; }
  .badge-secondary { background: rgba(130, 134, 139, 0.15); color: #82868b; }

  .entity-tag code {
    background: rgba(255, 255, 255, 0.06);
    padding: 3px 8px;
    border-radius: 4px;
    font-family: var(--font-mono);
    font-size: 0.8rem;
    color: #38bdf8;
  }

  .btn-link {
    background: none;
    border: none;
    color: var(--color-primary);
    cursor: pointer;
    font-size: 0.8rem;
    padding: 0;
    text-decoration: underline;
  }

  .json-viewer {
    margin-top: 8px;
    background: #0f172a;
    padding: 10px;
    border-radius: 6px;
    font-family: var(--font-mono);
    font-size: 0.75rem;
    color: #38bdf8;
    max-height: 180px;
    overflow-y: auto;
    border: 1px solid rgba(255, 255, 255, 0.08);
  }

  .ip-tag {
    font-family: var(--font-mono);
    font-size: 0.8rem;
    color: #64748b;
  }
</style>
