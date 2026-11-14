<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { apiRequest, addToast, subscribeToSSE } from '../api';
  import { icons } from '../utils/icons';
  import { t, currentLocale } from '../i18n/store';

  let users: any[] = [];
  let loading = true;
  let unsubSSE: Array<() => void> = [];

  // Modal
  let showModal = false;
  let isEditing = false;
  let editingId: number | null = null;
  let userForm = {
    username: '',
    password: '',
    role: 'pharmacist',
    is_active: true
  };

  function formatRole(role: string) {
    const r = (role || '').toLowerCase();
    switch (r) {
      case 'pharmacy_admin':
      case 'admin':
        return 'PHARMACY_ADMIN';
      case 'branch_admin':
      case 'branchadmin':
      case 'branch_manager':
        return 'BRANCH_ADMIN';
      case 'supervisor':
      case 'super_admin':
        return 'SUPERVISOR';
      case 'pharmacist':
      case 'staff':
        return 'PHARMACIST';
      case 'cashier':
        return 'CASHIER';
      default:
        return (role || '').toUpperCase();
    }
  }

  async function loadUsers() {
    loading = true;
    try {
      const res = await apiRequest('/users');
      users = Array.isArray(res) ? res : (Array.isArray(res?.data) ? res.data : []);
    } catch (err: any) {
      addToast(err.message || $t('toast.error'), 'error');
    } finally {
      loading = false;
    }
  }

  onMount(() => {
    loadUsers();
    const unsub = subscribeToSSE((event) => {
      if (['user_created', 'user_updated', 'user_deleted'].includes(event.event)) {
        loadUsers();
      }
    });
    unsubSSE.push(unsub);
  });

  onDestroy(() => {
    unsubSSE.forEach(u => u());
  });

  function openCreateModal() {
    isEditing = false;
    editingId = null;
    userForm = {
      username: '',
      password: '',
      role: 'pharmacist',
      is_active: true
    };
    showModal = true;
  }

  function openEditModal(u: any) {
    isEditing = true;
    editingId = u.id;
    const active = (u.is_active ?? u.isActive ?? false) === true || (u.is_active ?? u.isActive) === 1;
    let r = (u.role || 'pharmacist').toLowerCase();
    if (r === 'admin') r = 'pharmacy_admin';
    if (r === 'branchadmin' || r === 'branch_manager') r = 'branch_admin';
    if (r === 'staff') r = 'pharmacist';
    if (r === 'super_admin') r = 'supervisor';
    userForm = {
      username: u.username || '',
      password: '',
      role: r,
      is_active: active
    };
    showModal = true;
  }

  async function handleSaveUser() {
    if (!userForm.username.trim()) {
      addToast($currentLocale === 'ar' ? 'اسم المستخدم مطلوب' : 'Username is required', 'warning');
      return;
    }
    if (!isEditing && !userForm.password.trim()) {
      addToast($currentLocale === 'ar' ? 'كلمة المرور مطلوبة للحسابات الجديدة' : 'Password is required for new accounts', 'warning');
      return;
    }
    try {
      const payload: any = {
        username: userForm.username.trim().toLowerCase(),
        role: userForm.role,
        is_active: Boolean(userForm.is_active)
      };
      if (userForm.password && userForm.password.trim().length > 0) {
        payload.password = userForm.password.trim();
      }

      if (isEditing && editingId) {
        await apiRequest(`/users/${editingId}`, {
          method: 'PUT',
          body: JSON.stringify(payload)
        });
        addToast($currentLocale === 'ar' ? 'تم تحديث بيانات المستخدم بنجاح' : 'Staff credentials & role updated successfully', 'success');
      } else {
        payload.password = userForm.password.trim();
        await apiRequest('/users', {
          method: 'POST',
          body: JSON.stringify(payload)
        });
        addToast($currentLocale === 'ar' ? 'تم إنشاء الحساب بنجاح' : 'New staff account created successfully', 'success');
      }
      showModal = false;
      await loadUsers();
    } catch (err: any) {
      addToast(err.message || $t('toast.error'), 'error');
    }
  }

  async function toggleActive(u: any) {
    const currentActive = (u.is_active ?? u.isActive ?? false) === true || (u.is_active ?? u.isActive) === 1;
    try {
      await apiRequest(`/users/${u.id}`, {
        method: 'PUT',
        body: JSON.stringify({ is_active: !currentActive })
      });
      addToast($currentLocale === 'ar' ? 'تم تغيير حالة الحساب' : 'Account status toggled', 'success');
      await loadUsers();
    } catch (err: any) {
      addToast(err.message || $t('toast.error'), 'error');
    }
  }

  async function handleDelete(id: number) {
    const confirmMsg = $currentLocale === 'ar' ? 'هل أنت متأكد من حذف هذا الحساب؟' : 'Are you sure you want to delete this user?';
    if (!confirm(confirmMsg)) return;
    try {
      await apiRequest(`/users/${id}`, { method: 'DELETE' });
      addToast($t('toast.success'), 'success');
      await loadUsers();
    } catch (err: any) {
      addToast(err.message || $t('toast.error'), 'error');
    }
  }
</script>

<div class="users-tab-container animate-fade-in">
  <div class="tab-header">
    <div>
      <h2>{$t('usr.title')}</h2>
      <p class="subtitle">{$t('overview.desc')}</p>
    </div>
    <div class="actions-group">
      <button class="btn btn-secondary" on:click={loadUsers} title={$t('btn.refresh')}>
        {@html icons.refresh} {$t('btn.refresh')}
      </button>
      <button class="btn btn-primary" on:click={openCreateModal}>
        {@html icons.plus} {$t('usr.btnAdd')}
      </button>
    </div>
  </div>

  <div class="vuexy-card content-panel">
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
              <th>{$t('usr.th.user')}</th>
              <th>{$t('usr.th.role')}</th>
              <th>{$t('usr.th.status')}</th>
              <th>{$t('usr.th.branch')}</th>
              <th>{$t('prod.th.actions')}</th>
            </tr>
          </thead>
          <tbody>
            {#each users as u}
              {@const active = (u.is_active ?? u.isActive ?? false) === true || (u.is_active ?? u.isActive) === 1}
              <tr>
                <td>
                  <div class="user-avatar-cell">
                    <div class="avatar-sm">
                      {u.username?.charAt(0)?.toUpperCase()}
                    </div>
                    <strong>{u.username}</strong>
                  </div>
                </td>
                <td>
                  <span class="badge badge-role">{formatRole(u.role)}</span>
                </td>
                <td>
                  <button 
                    class="status-toggle-btn {active ? 'active' : 'inactive'}"
                    on:click={() => toggleActive(u)}
                    title="Click to toggle status"
                  >
                    <span class="status-dot"></span>
                    <span>{active ? $t('usr.status.active') : $t('usr.status.inactive')}</span>
                  </button>
                </td>
                <td>{$t('usr.branch.hq')}</td>
                <td>
                  <div class="row-actions">
                    <button class="btn-icon" on:click={() => openEditModal(u)} title={$t('btn.edit')}>
                      {@html icons.edit}
                    </button>
                    {#if u.id !== 1 && u.username !== 'admin'}
                      <button class="btn-icon btn-icon-danger" on:click={() => handleDelete(u.id)} title={$t('btn.delete')}>
                        {@html icons.trash}
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

  <!-- Add/Edit Modal -->
  {#if showModal}
    <div class="modal-backdrop animate-fade-in" on:click|self={() => showModal = false} role="dialog" aria-modal="true">
      <div class="modal-card vuexy-card animate-scale-up">
        <div class="modal-header">
          <h3>{isEditing ? $t('btn.edit') : $t('usr.btnAdd')}</h3>
          <button class="close-btn" on:click={() => showModal = false}>{@html icons.x}</button>
        </div>

        <form on:submit|preventDefault={handleSaveUser} class="modal-form">
          <div class="form-group">
            <label for="u-name">{$t('app.username')} *</label>
            <input id="u-name" class="form-input" type="text" required bind:value={userForm.username} placeholder="e.g. pharmacist1" />
          </div>

          <div class="form-group">
            <label for="u-pass">{$t('app.password')} {isEditing ? $t('usr.passHintEdit') : '*'}</label>
            <input id="u-pass" class="form-input" type="password" required={!isEditing} bind:value={userForm.password} placeholder="••••••••" />
          </div>

          <div class="form-group">
            <label for="u-role">{$t('usr.th.role')}</label>
            <select id="u-role" class="form-select" bind:value={userForm.role}>
              <option value="pharmacy_admin">{$currentLocale === 'ar' ? 'مدير الصيدلية (صلاحيات الويب ونقطة البيع كاملة)' : 'Pharmacy Administrator (Owner / Full Web & POS)'}</option>
              <option value="branch_admin">{$currentLocale === 'ar' ? 'مدير الفرع (صلاحيات إدارية لنقطة البيع)' : 'Branch Administrator (POS Administrative Privileges Only)'}</option>
              <option value="supervisor">{$currentLocale === 'ar' ? 'مشرف / صيدلي أول (اعتماد العمليات)' : 'Supervisor / Lead Pharmacist (Approvals)'}</option>
              <option value="pharmacist">{$currentLocale === 'ar' ? 'صيدلي (نقطة البيع والصرف)' : 'Staff Pharmacist (POS & Dispensing)'}</option>
              <option value="cashier">{$currentLocale === 'ar' ? 'كاشير (محاسبة نقطة البيع)' : 'Cashier (POS Checkout)'}</option>
            </select>
          </div>

          <div class="form-group checkbox-group">
            <label class="checkbox-label">
              <input type="checkbox" bind:checked={userForm.is_active} />
              <span>{$t('usr.status.active')}</span>
            </label>
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
  .users-tab-container {
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
  .user-avatar-cell {
    display: flex;
    align-items: center;
    gap: 10px;
  }
  .avatar-sm {
    width: 28px;
    height: 28px;
    border-radius: 50%;
    background: var(--color-primary-light);
    color: var(--color-primary);
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 0.75rem;
    font-weight: 700;
  }

  .status-toggle-btn {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    padding: 4px 10px;
    border-radius: var(--radius-pill);
    border: 1px solid var(--border-color);
    background: transparent;
    font-size: 0.75rem;
    font-weight: 600;
    cursor: pointer;
    transition: all var(--transition);
  }
  .status-dot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
  }
  .status-toggle-btn.active {
    background: var(--color-success-light);
    color: var(--color-success);
    border-color: rgba(40, 199, 111, 0.3);
  }
  .status-toggle-btn.active .status-dot {
    background: var(--color-success);
    box-shadow: 0 0 6px var(--color-success);
  }
  .status-toggle-btn.inactive {
    background: var(--color-danger-light);
    color: var(--color-danger);
    border-color: rgba(234, 84, 85, 0.3);
  }
  .status-toggle-btn.inactive .status-dot {
    background: var(--color-danger);
    box-shadow: 0 0 6px var(--color-danger);
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
  .checkbox-label {
    display: flex;
    align-items: center;
    gap: 8px;
    cursor: pointer;
  }

  .modal-actions {
    display: flex;
    justify-content: flex-end;
    gap: 10px;
    margin-top: 0.5rem;
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
</style>
