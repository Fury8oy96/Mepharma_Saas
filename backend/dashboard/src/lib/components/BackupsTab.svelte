<script lang="ts">
  import { onMount } from 'svelte';
  import { apiRequest, addToast } from '../api';
  import { icons } from '../utils/icons';
  import { t, currentLocale } from '../i18n/store';

  let backups: any[] = [];
  let loading = true;
  let isCreating = false;
  let restoringFilename: string | null = null;
  let isRestoring = false;

  async function loadBackups() {
    loading = true;
    try {
      const res = await apiRequest('/provider/api/backups');
      backups = Array.isArray(res) ? res : (Array.isArray(res?.data) ? res.data : []);
    } catch (err: any) {
      addToast(err.message || $t('toast.error'), 'error');
      backups = [];
    } finally {
      loading = false;
    }
  }

  async function handleCreateSnapshot() {
    isCreating = true;
    try {
      const res = await apiRequest('/provider/api/backups/create', { method: 'POST' });
      addToast(`Backup created: ${res.filename} (${res.sizeMb} MB)`, 'success');
      await loadBackups();
    } catch (err: any) {
      addToast(err.message || $t('toast.error'), 'error');
    } finally {
      isCreating = false;
    }
  }

  async function handleRestore(filename: string) {
    const confirmMsg = $currentLocale === 'ar'
      ? `تحذير هام: هل أنت متأكد من استعادة النظام إلى النسخة الاحتياطية (${filename})؟ سيتم استبدال قاعدة البيانات بالكامل بما فيها جميع الصيدليات.`
      : `CRITICAL WARNING: Are you sure you want to restore the entire platform database from (${filename})? This will replace all schemas and tenant records with the snapshot data.`;

    if (!confirm(confirmMsg)) return;

    restoringFilename = filename;
    isRestoring = true;
    try {
      const res = await apiRequest(`/provider/api/backups/${encodeURIComponent(filename)}/restore`, {
        method: 'POST'
      });
      addToast(res.message || 'System restored successfully.', 'success');
      await loadBackups();
    } catch (err: any) {
      addToast(err.message || $t('toast.error'), 'error');
    } finally {
      isRestoring = false;
      restoringFilename = null;
    }
  }

  function handleDownload(filename: string) {
    const token = localStorage.getItem('mepharma_access_token') || '';
    const url = `/provider/api/backups/${encodeURIComponent(filename)}/download?token=${encodeURIComponent(token)}`;
    window.open(url, '_blank');
  }

  function formatTime(isoStr: string): string {
    if (!isoStr) return '--';
    const d = new Date(isoStr);
    return d.toLocaleString($currentLocale === 'ar' ? 'ar-EG' : 'en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  }

  onMount(loadBackups);
</script>

<div class="backups-zone animate-fade-in">
  <!-- Hero Banner -->
  <div class="vuexy-card hero-banner">
    <div class="hero-content">
      <div class="hero-badge-row">
        <span class="hero-badge">
          {@html icons.database}
          <span>{$t('backup.title')}</span>
        </span>
      </div>
      <h2>{$t('backup.title')}</h2>
      <p>{$t('backup.sub')}</p>
    </div>

    <div class="hero-controls">
      <button class="btn btn-secondary btn-sm" on:click={loadBackups} title={$t('btn.refresh')}>
        {@html icons.refresh}
        <span class="refresh-label">{$t('btn.refresh')}</span>
      </button>
      <button class="btn btn-primary" on:click={handleCreateSnapshot} disabled={isCreating}>
        {@html icons.plus}
        <span>{isCreating ? $t('backup.creating') : $t('backup.createBtn')}</span>
      </button>
    </div>
  </div>

  <!-- Scope Notice Banner -->
  <div class="vuexy-card scope-card">
    <div class="scope-icon">
      {@html icons.shield}
    </div>
    <div class="scope-text">
      <strong>Whole-System Database Scope:</strong>
      <span> Each snapshot produces an atomic, self-consistent PostgreSQL 16 dump covering both the root public control plane (tenant registries, cryptographic license tables, audit logs) and all independent branch schema namespaces (<code>tenant_main</code>, <code>tenant_*</code>).</span>
    </div>
  </div>

  <!-- Backups Table -->
  <div class="vuexy-card table-panel">
    {#if loading && backups.length === 0}
      <div class="loading-state">
        <div class="spinner"></div>
        <p>{$t('table.loading')}</p>
      </div>
    {:else if backups.length === 0}
      <div class="empty-state">
        <p>{$t('table.noData')}</p>
        <button class="btn btn-primary" on:click={handleCreateSnapshot} style="margin-top: 12px;">
          {@html icons.plus} {$t('backup.createBtn')}
        </button>
      </div>
    {:else}
      <div class="table-responsive">
        <table class="data-table">
          <thead>
            <tr>
              <th>{$t('backup.th.name')}</th>
              <th>{$t('backup.th.size')}</th>
              <th>{$t('backup.th.date')}</th>
              <th>Scope</th>
              <th class="text-right">Actions</th>
            </tr>
          </thead>
          <tbody>
            {#each backups as b}
              <tr>
                <td>
                  <div class="file-name-cell">
                    {@html icons.database}
                    <code>{b.filename}</code>
                  </div>
                </td>
                <td>
                  <strong>{b.sizeMb} MB</strong>
                </td>
                <td class="cell-time">{formatTime(b.createdAt)}</td>
                <td>
                  <span class="badge badge-role">All Schemas + Public</span>
                </td>
                <td class="text-right">
                  <div class="actions-group-row">
                    <button 
                      class="btn btn-sm btn-secondary" 
                      on:click={() => handleDownload(b.filename)}
                      title={$t('backup.act.download')}
                    >
                      {@html icons.download}
                      <span>{$t('backup.act.download')}</span>
                    </button>
                    <button 
                      class="btn btn-sm btn-danger" 
                      on:click={() => handleRestore(b.filename)}
                      disabled={isRestoring && restoringFilename === b.filename}
                      title={$t('backup.act.restore')}
                    >
                      {@html icons.undo}
                      <span>{isRestoring && restoringFilename === b.filename ? $t('backup.restoring') : $t('backup.act.restore')}</span>
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
</div>

<style>
  .backups-zone {
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

  .hero-controls {
    display: flex;
    align-items: center;
    gap: 12px;
  }

  .scope-card {
    display: flex;
    align-items: center;
    gap: 14px;
    padding: 16px 20px;
    border-radius: 10px;
    background: rgba(15, 23, 42, 0.6);
    border: 1px solid rgba(59, 130, 246, 0.2);
  }

  .scope-icon {
    color: #3b82f6;
    flex-shrink: 0;
  }

  .scope-text {
    font-size: 0.85rem;
    color: #94a3b8;
    line-height: 1.5;
  }

  .scope-text strong {
    color: #f1f5f9;
  }

  .scope-text code {
    background: rgba(255, 255, 255, 0.08);
    padding: 2px 6px;
    border-radius: 4px;
    font-family: var(--font-mono);
    color: #38bdf8;
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

  .file-name-cell {
    display: flex;
    align-items: center;
    gap: 10px;
    color: var(--color-primary);
  }

  .file-name-cell code {
    font-family: var(--font-mono);
    font-size: 0.85rem;
    color: #f1f5f9;
  }

  .cell-time {
    font-family: var(--font-mono);
    font-size: 0.8rem;
    color: #94a3b8;
  }

  .text-right {
    text-align: right;
  }

  :global(.rtl-mode) .text-right {
    text-align: left;
  }

  .actions-group-row {
    display: inline-flex;
    align-items: center;
    gap: 8px;
  }

  .btn-danger {
    background: rgba(234, 84, 85, 0.15);
    color: #ea5455;
    border: 1px solid rgba(234, 84, 85, 0.3);
  }

  .btn-danger:hover {
    background: #ea5455;
    color: #fff;
  }
</style>
