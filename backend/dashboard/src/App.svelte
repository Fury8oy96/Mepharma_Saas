<script lang="ts">
  import { onMount } from 'svelte';
  import { 
    tokenStore, 
    userStore, 
    alertsStore, 
    apiRequest, 
    addToast, 
    startSession, 
    clearSession, 
    checkAndRotateSession,
    getDomainTenant
  } from './lib/api';
  import { icons } from './lib/utils/icons';
  import { t, currentLocale, setLocale, updateDocumentDirection } from './lib/i18n/store';
  import { currentTheme, toggleTheme, applyTheme } from './lib/theme/store';

  import OverviewTab from './lib/components/OverviewTab.svelte';
  import ProductsTab from './lib/components/ProductsTab.svelte';
  import PurchasesTab from './lib/components/PurchasesTab.svelte';
  import SalesTab from './lib/components/SalesTab.svelte';
  import CategoriesTab from './lib/components/CategoriesTab.svelte';
  import SuppliersTab from './lib/components/SuppliersTab.svelte';
  import UsersTab from './lib/components/UsersTab.svelte';
  import CustomersTab from './lib/components/CustomersTab.svelte';
  import ReportsTab from './lib/components/ReportsTab.svelte';
  import SettingsTab from './lib/components/SettingsTab.svelte';
  import PharmaciesTab from './lib/components/PharmaciesTab.svelte';
  import TelemetryTab from './lib/components/TelemetryTab.svelte';
  import AuditLogsTab from './lib/components/AuditLogsTab.svelte';
  import BackupsTab from './lib/components/BackupsTab.svelte';

  // Domain-driven portal detection
  const domainTenant = getDomainTenant(); // e.g. 'main' if on main.localhost, or null if on localhost
  const isPharmacyPortal = domainTenant !== null;

  let currentTab = isPharmacyPortal ? 'overview' : 'pharmacies';

  // Login Form State
  let loginUsername = isPharmacyPortal ? 'admin' : 'superadmin';
  let loginPassword = '';
  let loginLoading = false;
  let loginError = '';
  let pharmacyInfo: { id: number; code: string; name: string; status: string; plan: string } | null = null;
  let pharmacyLoadError = '';

  onMount(async () => {
    applyTheme($currentTheme);
    updateDocumentDirection($currentLocale);

    // If on a pharmacy tenant domain, fetch branch details from /admin/api/info
    if (isPharmacyPortal && domainTenant) {
      document.title = `MePharma - Pharmacy Admin (${domainTenant})`;
      try {
        const info = await apiRequest('/admin/api/info');
        pharmacyInfo = info;
        document.title = `${info.name || domainTenant} - MePharma Pharmacy Admin`;
      } catch (err: any) {
        pharmacyLoadError = err.message || `Pharmacy branch '${domainTenant}' was not found in the platform registry.`;
      }
    } else {
      document.title = 'MePharma - Provider Platform Control Plane';
    }

    // 24-Hour Session Lifecycle Validation & Domain-Role Match
    if (!checkAndRotateSession() || !$tokenStore || !$userStore) {
      clearSession();
    } else {
      const role = ($userStore?.role || '').toLowerCase();
      const isSuper = role === 'system_admin' || role === 'super_admin';
      // Total domain isolation: superadmin tokens cannot access tenant portal and vice-versa
      if (isPharmacyPortal && isSuper) {
        clearSession();
      } else if (!isPharmacyPortal && !isSuper) {
        clearSession();
      } else {
        currentTab = isSuper ? 'pharmacies' : 'overview';
      }
    }
  });

  function handleSwitchLanguage() {
    const next = $currentLocale === 'en' ? 'ar' : 'en';
    setLocale(next);
  }

  $: isProviderAdmin = !isPharmacyPortal && ($userStore?.role === 'system_admin' || $userStore?.role === 'super_admin');

  $: navSections = isProviderAdmin
    ? [
        {
          title: $t('provider.planeTitle', 'Provider Platform Control Plane'),
          items: [
            { id: 'pharmacies', name: $t('provider.nav.pharmacies', 'Pharmacies & Tenants'), icon: icons.overview, badge: null },
            { id: 'telemetry', name: $t('provider.nav.telemetry', 'System Monitoring & Telemetry'), icon: icons.activity, badge: null },
            { id: 'audit_logs', name: $t('provider.nav.audit', 'Audit Trail Logs'), icon: icons.shield, badge: null },
            { id: 'backups', name: $t('provider.nav.backups', 'Backups & Disaster Recovery'), icon: icons.database, badge: null },
          ]
        }
      ]
    : [
    {
      title: $t('nav.sec.operations', 'Operations & Inventory'),
      items: [
        { id: 'overview', name: $t('nav.overview', 'Overview'), icon: icons.overview, badge: null },
        { id: 'products', name: $t('nav.products', 'Products & Stock'), icon: icons.products, badge: null },
        { id: 'purchases', name: $t('nav.purchases', 'Purchase Orders'), icon: icons.purchases, badge: null },
        { id: 'sales', name: $t('nav.sales', 'Sales Ledger'), icon: icons.sales, badge: null }
      ]
    },
    {
      title: $t('nav.sec.relations', 'Commercial Network'),
      items: [
        { id: 'customers', name: $t('nav.customers', 'Customers & CRM'), icon: icons.customers, badge: null },
        { id: 'suppliers', name: $t('nav.suppliers', 'Suppliers Directory'), icon: icons.suppliers, badge: null },
        { id: 'categories', name: $t('nav.categories', 'Categories'), icon: icons.categories, badge: null }
      ]
    },
    {
      title: $t('nav.sec.analytics', 'Analytics & Security'),
      items: [
        { id: 'reports', name: $t('nav.reports', 'Financial Reports'), icon: icons.reports, badge: null },
        { id: 'users', name: $t('nav.users', 'Staff & Roles'), icon: icons.users, badge: null },
        { id: 'settings', name: $t('nav.settings', 'Store Settings'), icon: icons.settings, badge: null }
      ]
    }
  ];

  $: activeNav = (() => {
    const sections = navSections || [];
    for (const sec of sections) {
      const it = sec?.items?.find(i => i.id === currentTab);
      if (it) return { title: it.name, section: sec.title };
    }
    return { title: 'Overview', section: 'Operations & Inventory' };
  })();

  async function handleLogin() {
    loginLoading = true;
    loginError = '';
    const username = loginUsername.trim();
    const password = loginPassword.trim();
    try {
      let res: any;
      if (isPharmacyPortal) {
        // Exclusively Pharmacy Admin login endpoint
        res = await apiRequest('/admin/api/auth/login', {
          method: 'POST',
          body: JSON.stringify({ username, password })
        });
        const role = (res.user?.role || '').toLowerCase();
        if (role !== 'pharmacy_admin' && role !== 'admin') {
          throw new Error(
            $currentLocale === 'ar'
              ? 'تم رفض الوصول: لوحة الويب مخصصة لمدير الصيدلية فقط.'
              : 'Access denied: Web dashboard is reserved exclusively for Pharmacy Administrators.'
          );
        }
        startSession(res.token, res.user);
        currentTab = 'overview';
      } else {
        // Exclusively Provider Platform Superadmin login endpoint
        res = await apiRequest('/provider/api/auth/login', {
          method: 'POST',
          body: JSON.stringify({ username, password })
        });
        const role = (res.user?.role || '').toLowerCase();
        if (role !== 'system_admin' && role !== 'super_admin') {
          throw new Error(
            $currentLocale === 'ar'
              ? 'تم رفض الوصول: هذه البوابة مخصصة لمدراء المنظومة فقط.'
              : 'Access denied: This portal is reserved for Provider Platform System Administrators.'
          );
        }
        startSession(res.token, res.user);
        currentTab = 'pharmacies';
      }
      addToast($t('toast.success', 'Operation completed successfully'), 'success');
    } catch (err: any) {
      loginError = err.message || ($currentLocale === 'ar' ? 'فشل تسجيل الدخول' : 'Login failed');
    } finally {
      loginLoading = false;
    }
  }

  function handleLogout() {
    clearSession();
    addToast($currentLocale === 'ar' ? 'تم تسجيل الخروج بنجاح' : 'Logged out successfully', 'info');
  }
</script>

<!-- Real-time Toast Notifications -->
<div class="toast-container" aria-live="polite">
  {#each $alertsStore as alert (alert.id)}
    <div class="toast toast-{alert.type} animate-fade-in">
      <span class="toast-icon">
        {#if alert.type === 'success'}{@html icons.check}
        {:else if alert.type === 'error'}{@html icons.alertTriangle}
        {:else}{@html icons.sparkle}{/if}
      </span>
      <span class="toast-text">{alert.message}</span>
    </div>
  {/each}
</div>

{#if !$tokenStore || !$userStore}
  <!-- Vuexy Style Authentication Screen (Domain-Determined Portal) -->
  <div class="login-wrapper">
    <div class="login-card-container animate-scale-up">
      <!-- Quick Settings Bar on Login -->
      <div class="login-top-bar">
        <button class="btn btn-sm btn-secondary lang-btn" on:click={handleSwitchLanguage} title={$t('lang.switch')}>
          <span class="btn-svg">{@html icons.globe}</span>
          <span>{$currentLocale === 'en' ? 'العربية' : 'English'}</span>
        </button>
        <button class="btn-icon theme-btn" on:click={toggleTheme} title={$currentTheme === 'dark' ? $t('theme.light') : $t('theme.dark')}>
          {@html $currentTheme === 'dark' ? icons.sun : icons.moon}
        </button>
      </div>

      <div class="vuexy-card login-card">
        <div class="login-brand">
          <div class="vuexy-logo">
            <img src="/logo.png" alt="MePharma Logo" class="brand-logo-img" />
          </div>
          <div class="brand-text">
            <h2>{$t('app.name')}</h2>
            <span class="brand-tag">
              {#if isPharmacyPortal}
                Branch: {domainTenant?.toUpperCase()}
              {:else}
                Provider HQ Control Plane
              {/if}
            </span>
          </div>
        </div>

        {#if pharmacyLoadError}
          <div class="alert alert-danger animate-fade-in">
            <span>{@html icons.alertTriangle}</span>
            <span>{pharmacyLoadError}</span>
          </div>
          <div class="portal-error-hint">
            <p>Please verify that the subdomain matches a registered pharmacy instance, or contact your platform administrator.</p>
          </div>
        {:else}
          <div class="login-heading">
            <h3>
              {#if isPharmacyPortal}
                {$currentLocale === 'ar' ? `لوحة إدارة صيدلية ${pharmacyInfo?.name || domainTenant} 👋` : `${pharmacyInfo?.name || `Pharmacy (${domainTenant})`} Admin Portal 👋`}
              {:else}
                {$currentLocale === 'ar' ? 'لوحة إدارة المنصة المركزية 👋' : 'Platform System Administration 👋'}
              {/if}
            </h3>
            <p>
              {#if isPharmacyPortal}
                {$currentLocale === 'ar' ? 'تسجيل الدخول لإدارة عمليات الصيدلية، المخزون، أوامر الشراء، وفريق العمل.' : 'Sign in to manage branch operations, inventory, stock approvals, and staff (supervisors & pharmacists).'}
              {:else}
                {$currentLocale === 'ar' ? 'تسجيل الدخول لإدارة الفروع، التراخيص المشفرة، والنسخ الاحتياطي ومراقبة النظام.' : 'Sign in to manage provider platform tenants, cryptographic licensing, and system telemetry.'}
              {/if}
            </p>
          </div>

          {#if loginError}
            <div class="alert alert-danger animate-fade-in">
              <span>{@html icons.alertTriangle}</span>
              <span>{loginError}</span>
            </div>
          {/if}

          <form on:submit|preventDefault={handleLogin} class="login-form">
            <div class="form-group">
              <label for="login-username">
                {isPharmacyPortal ? 'Pharmacy Admin Username' : 'System Admin Username'}
              </label>
              <input 
                id="login-username"
                class="form-input" 
                type="text" 
                required 
                bind:value={loginUsername} 
                placeholder={isPharmacyPortal ? 'admin' : 'superadmin'}
                autocomplete="username"
                disabled={loginLoading}
              />
            </div>

            <div class="form-group">
              <label for="login-password">{$t('app.password')}</label>
              <input 
                id="login-password"
                class="form-input" 
                type="password" 
                required 
                bind:value={loginPassword} 
                placeholder="••••••••"
                autocomplete="current-password"
                disabled={loginLoading}
              />
            </div>

            <button type="submit" class="btn btn-primary btn-block" disabled={loginLoading}>
              {loginLoading ? $t('app.authenticating') : (isPharmacyPortal ? ($currentLocale === 'ar' ? 'تسجيل الدخول للصيدلية' : 'Sign In to Pharmacy Portal') : ($currentLocale === 'ar' ? 'تسجيل الدخول للوحة التحكم' : 'Sign In to Control Plane'))}
            </button>
          </form>

          <div class="login-footer-hint">
            {#if isPharmacyPortal}
              <span>Branch Administrator: <code>admin</code> / <code>admin123</code></span>
            {:else}
              <span>Platform Administrator: <code>superadmin</code> / <code>superadmin123</code></span>
            {/if}
          </div>
        {/if}
      </div>
    </div>
  </div>
{:else}
  <!-- Signature Vuexy Master Shell -->
  <div class="vuexy-layout">
    <!-- Vuexy Sidebar -->
    <aside class="vuexy-sidebar">
      <div class="sidebar-header">
        <div class="sidebar-logo">
          <img src="/logo.png" alt="MePharma Logo" class="sidebar-logo-img" />
          <span class="logo-title">{$t('app.name')}</span>
        </div>
        <span class="badge badge-role">
          {isProviderAdmin ? 'HQ' : (domainTenant?.toUpperCase() || 'PHARMACY')}
        </span>
      </div>

      <div class="sidebar-menu">
        {#each navSections as section}
          <div class="menu-section">
            <div class="section-label">{section.title}</div>
            <ul class="nav-list">
              {#each section.items as item}
                <li>
                  <button 
                    class="nav-link {currentTab === item.id ? 'active' : ''}"
                    on:click={() => currentTab = item.id}
                  >
                    <span class="nav-icon">{@html item.icon}</span>
                    <span class="nav-title">{item.name}</span>
                  </button>
                </li>
              {/each}
            </ul>
          </div>
        {/each}
      </div>

      <div class="sidebar-footer">
        <div class="user-chip">
          <div class="avatar-box">
            <span>{$userStore?.username?.charAt(0)?.toUpperCase() || (isProviderAdmin ? 'S' : 'A')}</span>
            <span class="status-online"></span>
          </div>
          <div class="user-meta">
            <span class="user-name">{$userStore?.username || (isProviderAdmin ? 'Superadmin' : 'Branch Admin')}</span>
            <span class="user-role">
              {isProviderAdmin ? ($currentLocale === 'ar' ? 'مدير المنصة العام' : 'Platform Administrator') : ($currentLocale === 'ar' ? 'مدير الصيدلية' : 'Pharmacy Administrator')}
            </span>
          </div>
          <button class="logout-btn" on:click={handleLogout} title={$t('app.logout')}>
            {@html icons.logout}
          </button>
        </div>
      </div>
    </aside>

    <!-- Main Content Area with Inset Floating Navbar -->
    <div class="vuexy-page-content">
      <!-- Vuexy Floating Inset Navbar -->
      <nav class="vuexy-navbar vuexy-card">
        <div class="navbar-left">
          <div class="breadcrumb-item">
            <span class="section-crumb">{activeNav.section}</span>
            <span class="crumb-separator">/</span>
            <strong class="active-crumb">{activeNav.title}</strong>
          </div>
          {#if isPharmacyPortal}
            <div class="branch-indicator-pill">
              <span class="pulse-indicator-emerald"></span>
              <span>{pharmacyInfo?.name || `Branch: ${domainTenant}`}</span>
            </div>
          {/if}
        </div>

        <div class="navbar-right">
          <!-- Language Switcher Pill -->
          <button class="btn btn-sm btn-secondary nav-action-btn" on:click={handleSwitchLanguage} title={$t('lang.switch')}>
            <span class="btn-svg">{@html icons.globe}</span>
            <span class="lang-label">{$currentLocale === 'en' ? 'العربية' : 'English'}</span>
          </button>

          <!-- Light / Dark Theme Toggle Button -->
          <button class="btn-icon theme-toggle-btn" on:click={toggleTheme} title={$currentTheme === 'dark' ? $t('theme.light') : $t('theme.dark')}>
            {@html $currentTheme === 'dark' ? icons.sun : icons.moon}
          </button>

          <!-- Live Sync Status -->
          <div class="live-sync-pill">
            <span class="pulse-indicator"></span>
            <span>{$t('app.liveTelemetry')}</span>
          </div>

          <div class="nav-date">
            <span>{new Date().toLocaleDateString($currentLocale === 'ar' ? 'ar-EG' : 'en-US', { month: 'short', day: 'numeric', year: 'numeric' })}</span>
          </div>
        </div>
      </nav>

      <!-- View Container -->
      <main class="content-wrapper">
        {#if currentTab === 'overview'}
          <OverviewTab />
        {:else if currentTab === 'products'}
          <ProductsTab />
        {:else if currentTab === 'purchases'}
          <PurchasesTab />
        {:else if currentTab === 'sales'}
          <SalesTab />
        {:else if currentTab === 'categories'}
          <CategoriesTab />
        {:else if currentTab === 'suppliers'}
          <SuppliersTab />
        {:else if currentTab === 'customers'}
          <CustomersTab />
        {:else if currentTab === 'reports'}
          <ReportsTab />
        {:else if currentTab === 'users'}
          <UsersTab />
        {:else if currentTab === 'settings'}
          <SettingsTab />
        {:else if currentTab === 'pharmacies'}
          <PharmaciesTab />
        {:else if currentTab === 'telemetry'}
          <TelemetryTab />
        {:else if currentTab === 'audit_logs'}
          <AuditLogsTab />
        {:else if currentTab === 'backups'}
          <BackupsTab />
        {/if}
      </main>
    </div>
  </div>
{/if}

<style>
  /* Base Layout */
  :global(:root) {
    --font-tajawal: 'Tajawal', sans-serif;
    --font-public-sans: 'Tajawal', 'Public Sans', -apple-system, BlinkMacSystemFont, sans-serif;
    --font-mono: 'JetBrains Mono', monospace;
  }

  :global(body) {
    font-family: var(--font-tajawal);
    background-color: var(--bg-body);
    color: var(--text-primary);
    margin: 0;
    padding: 0;
  }

  :global(html[dir="rtl"] body) {
    font-family: var(--font-tajawal);
  }

  :global(button), :global(input), :global(select), :global(textarea) {
    font-family: var(--font-tajawal);
  }

  /* Real-time Toasts */
  .toast-container {
    position: fixed;
    top: 24px;
    right: 24px;
    z-index: 9999;
    display: flex;
    flex-direction: column;
    gap: 12px;
    max-width: 400px;
    pointer-events: none;
  }

  :global(html[dir="rtl"]) .toast-container {
    right: auto;
    left: 24px;
  }

  .toast {
    padding: 12px 18px;
    border-radius: var(--radius-sm);
    background: var(--bg-card);
    border: 1px solid var(--border-color);
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.4);
    font-size: 0.875rem;
    font-weight: 500;
    display: flex;
    align-items: center;
    gap: 10px;
  }
  .toast-icon {
    display: flex;
    align-items: center;
  }
  .toast-text {
    color: var(--text-primary);
  }
  .toast-success {
    border-color: var(--color-success);
  }
  .toast-success .toast-icon {
    color: var(--color-success);
  }
  .toast-error {
    border-color: var(--color-danger);
  }
  .toast-error .toast-icon {
    color: var(--color-danger);
  }
  .toast-info {
    border-color: var(--color-primary);
  }
  .toast-info .toast-icon {
    color: var(--color-primary);
  }

  /* Login Form */
  .login-wrapper {
    min-height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
    background-color: var(--bg-body);
    padding: 1.5rem;
  }
  .login-card-container {
    width: 100%;
    max-width: 440px;
  }
  .login-card {
    padding: 2.5rem 2rem;
    display: flex;
    flex-direction: column;
    gap: 1.5rem;
  }
  .login-brand {
    display: flex;
    align-items: center;
    gap: 12px;
  }
  .brand-logo-img {
    width: 44px;
    height: 44px;
    object-fit: contain;
    border-radius: 10px;
    background: #ffffff;
    padding: 3px;
    box-shadow: 0 2px 8px rgba(115, 103, 240, 0.15);
  }
  .sidebar-logo-img {
    width: 32px;
    height: 32px;
    object-fit: contain;
    border-radius: 8px;
    background: #ffffff;
    padding: 2px;
    box-shadow: 0 2px 6px rgba(0, 0, 0, 0.08);
  }
  .brand-text h2 {
    font-size: 1.4rem;
    font-weight: 700;
    color: var(--text-heading);
    margin: 0;
  }
  .brand-tag {
    font-size: 0.75rem;
    color: var(--color-primary);
    font-weight: 600;
    letter-spacing: 0.05em;
  }
  .login-heading h3 {
    font-size: 1.25rem;
    font-weight: 600;
    color: var(--text-heading);
    margin: 0 0 6px 0;
  }
  .login-heading p {
    font-size: 0.875rem;
    color: var(--text-muted);
    line-height: 1.45;
    margin: 0;
  }
  .portal-error-hint {
    font-size: 0.8125rem;
    color: var(--text-muted);
    line-height: 1.5;
  }
  .alert {
    padding: 10px 14px;
    border-radius: var(--radius-sm);
    font-size: 0.85rem;
    display: flex;
    align-items: center;
    gap: 8px;
  }
  .alert-danger {
    background: var(--color-danger-light);
    border: 1px solid rgba(234, 84, 85, 0.3);
    color: #ea5455;
  }
  .login-form {
    display: flex;
    flex-direction: column;
    gap: 1.25rem;
  }
  .login-top-bar {
    display: flex;
    justify-content: flex-end;
    gap: 8px;
    margin-bottom: 12px;
  }
  .login-footer-hint {
    text-align: center;
    font-size: 0.8rem;
    color: var(--text-muted);
  }
  .login-footer-hint code {
    background: rgba(115, 103, 240, 0.1);
    color: var(--color-primary);
    padding: 2px 6px;
    border-radius: 4px;
    font-family: var(--font-mono);
  }

  /* Vuexy Master Layout */
  .vuexy-layout {
    display: flex;
    min-height: 100vh;
    background-color: var(--bg-body);
    width: 100%;
    max-width: 100vw;
    overflow-x: hidden;
  }

  /* Vuexy Sidebar */
  .vuexy-sidebar {
    width: 260px;
    background: var(--bg-sidebar);
    border-right: 1px solid var(--border-color);
    display: flex;
    flex-direction: column;
    position: fixed;
    top: 0;
    bottom: 0;
    left: 0;
    z-index: 100;
    font-family: var(--font-tajawal) !important;
  }

  :global(html[dir="rtl"]) .vuexy-sidebar {
    left: auto;
    right: 0;
    border-right: none;
    border-left: 1px solid var(--border-color);
  }

  .sidebar-header {
    height: 70px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0 1.5rem;
    border-bottom: 1px solid var(--border-color);
  }
  .sidebar-logo {
    display: flex;
    align-items: center;
    gap: 10px;
  }
  .logo-title {
    font-size: 1.2rem;
    font-weight: 700;
    color: var(--text-heading);
  }
  .badge-role {
    font-size: 0.7rem;
    font-weight: 700;
    padding: 3px 8px;
    background: var(--color-primary-light);
    color: var(--color-primary);
    border-radius: var(--radius-xs);
  }

  .sidebar-menu {
    flex: 1;
    overflow-y: auto;
    padding: 1rem 0;
  }
  .menu-section {
    margin-bottom: 1.5rem;
  }
  .section-label {
    padding: 0 1.5rem;
    font-size: 0.72rem;
    font-weight: 700;
    text-transform: uppercase;
    color: var(--text-muted);
    letter-spacing: 0.05em;
    margin-bottom: 0.5rem;
    font-family: var(--font-tajawal) !important;
  }
  .nav-list {
    list-style: none;
    margin: 0;
    padding: 0;
  }
  .nav-link {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 10px 1.5rem;
    color: var(--text-primary);
    text-decoration: none;
    font-size: 0.9rem;
    font-weight: 500;
    transition: all var(--transition);
    border: none;
    background: transparent;
    width: 100%;
    cursor: pointer;
    text-align: left;
    font-family: var(--font-tajawal) !important;
  }

  :global(html[dir="rtl"]) .nav-link {
    text-align: right;
  }

  .nav-link:hover {
    color: var(--color-primary);
    background: var(--color-primary-light);
  }
  .nav-link.active {
    background: linear-gradient(72.47deg, var(--color-primary) 22.16%, rgba(115, 103, 240, 0.7) 76.47%);
    color: #ffffff;
    box-shadow: 0px 2px 6px rgba(115, 103, 240, 0.48);
  }
  .nav-icon {
    display: flex;
    align-items: center;
  }

  .sidebar-footer {
    padding: 1rem 1.25rem;
    border-top: 1px solid var(--border-color);
  }
  .user-chip {
    display: flex;
    align-items: center;
    gap: 10px;
  }
  .avatar-box {
    position: relative;
    width: 38px;
    height: 38px;
    border-radius: 50%;
    background: var(--color-primary-light);
    color: var(--color-primary);
    font-weight: 700;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .status-online {
    position: absolute;
    bottom: 0;
    right: 0;
    width: 10px;
    height: 10px;
    border-radius: 50%;
    background: var(--color-success);
    border: 2px solid var(--bg-sidebar);
  }
  .user-meta {
    flex: 1;
    overflow: hidden;
  }
  .user-name {
    display: block;
    font-size: 0.85rem;
    font-weight: 600;
    color: var(--text-heading);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .user-role {
    display: block;
    font-size: 0.75rem;
    color: var(--text-muted);
  }
  .logout-btn {
    background: transparent;
    border: none;
    color: var(--text-muted);
    cursor: pointer;
    padding: 6px;
    border-radius: var(--radius-xs);
    display: flex;
    align-items: center;
    transition: all var(--transition);
  }
  .logout-btn:hover {
    color: var(--color-danger);
    background: var(--color-danger-light);
  }

  /* Vuexy Page Content */
  .vuexy-page-content {
    flex: 1;
    min-width: 0;
    max-width: calc(100% - 260px);
    width: calc(100% - 260px);
    margin-left: 260px;
    display: flex;
    flex-direction: column;
    min-height: 100vh;
    padding: 1.5rem;
    overflow-x: hidden;
    box-sizing: border-box;
  }

  :global(html[dir="rtl"]) .vuexy-page-content {
    margin-left: 0;
    margin-right: 260px;
  }

  /* Vuexy Inset Floating Navbar */
  .vuexy-navbar {
    height: 62px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0 1.5rem;
    margin-bottom: 1.5rem;
    background: var(--bg-card);
    border-radius: var(--radius-sm);
    box-shadow: 0 4px 18px rgba(0, 0, 0, 0.2);
    width: 100%;
    max-width: 100%;
    box-sizing: border-box;
  }
  .navbar-left {
    display: flex;
    align-items: center;
    gap: 16px;
  }
  .breadcrumb-item {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 0.875rem;
  }
  .section-crumb {
    color: var(--text-muted);
  }
  .crumb-separator {
    color: var(--text-muted);
    font-size: 0.75rem;
  }
  .active-crumb {
    color: var(--text-heading);
    font-weight: 600;
  }
  .branch-indicator-pill {
    display: flex;
    align-items: center;
    gap: 8px;
    background: rgba(40, 199, 111, 0.12);
    color: #28c76f;
    border: 1px solid rgba(40, 199, 111, 0.25);
    padding: 4px 12px;
    border-radius: var(--radius-pill);
    font-size: 0.8rem;
    font-weight: 600;
  }
  .pulse-indicator-emerald {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    background: #28c76f;
    box-shadow: 0 0 8px #28c76f;
  }
  .navbar-right {
    display: flex;
    align-items: center;
    gap: 12px;
  }
  .nav-action-btn {
    display: flex;
    align-items: center;
    gap: 6px;
    font-size: 0.8rem;
  }
  .theme-toggle-btn {
    background: transparent;
    border: none;
    color: var(--text-primary);
    cursor: pointer;
    padding: 8px;
    border-radius: var(--radius-xs);
    display: flex;
    align-items: center;
  }
  .live-sync-pill {
    display: flex;
    align-items: center;
    gap: 6px;
    font-size: 0.75rem;
    font-weight: 600;
    color: var(--color-success);
    background: var(--color-success-light);
    padding: 4px 10px;
    border-radius: var(--radius-pill);
  }
  .pulse-indicator {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    background: var(--color-success);
    box-shadow: 0 0 6px var(--color-success);
  }
  .nav-date {
    font-size: 0.8rem;
    color: var(--text-muted);
  }

  .content-wrapper {
    flex: 1;
    min-width: 0;
    width: 100%;
    max-width: 100%;
    overflow-x: hidden;
    box-sizing: border-box;
  }
</style>
