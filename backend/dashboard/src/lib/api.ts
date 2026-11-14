import { writable } from "svelte/store";

const SESSION_TIME_KEY = 'mepharma_session_timestamp';
const MAX_SESSION_DURATION_MS = 24 * 60 * 60 * 1000; // 24 Hours

function getInitialToken(): string | null {
  try {
    const token = localStorage.getItem('mepharma_token');
    const sessionTimeStr = localStorage.getItem(SESSION_TIME_KEY);

    if (!token) {
      return null;
    }

    // If token exists but timestamp was not yet set, initialize it
    if (!sessionTimeStr) {
      localStorage.setItem(SESSION_TIME_KEY, Date.now().toString());
      return token;
    }

    const sessionTime = parseInt(sessionTimeStr, 10);
    const now = Date.now();

    if (isNaN(sessionTime) || (now - sessionTime) > MAX_SESSION_DURATION_MS) {
      clearStoredSession();
      return null;
    }

    // Active within 24 hours -> touch session timestamp to rotate another 24 hours
    localStorage.setItem(SESSION_TIME_KEY, now.toString());
    return token;
  } catch (_) {
    return null;
  }
}

function getInitialUser(): any {
  try {
    const raw = localStorage.getItem('mepharma_user');
    if (!raw) return null;
    return JSON.parse(raw);
  } catch (_) {
    return null;
  }
}

function clearStoredSession() {
  try {
    localStorage.removeItem('mepharma_token');
    localStorage.removeItem('mepharma_user');
    localStorage.removeItem(SESSION_TIME_KEY);
  } catch (_) {}
}

const initialToken = getInitialToken();
export const tokenStore = writable<string | null>(initialToken);
export const userStore = writable<any>(initialToken ? getInitialUser() : null);
export const alertsStore = writable<Array<{ id: string; type: 'success' | 'error' | 'info' | 'warning'; message: string }>>([]);

let initialSub = true;
tokenStore.subscribe((val) => {
  try {
    if (val) {
      localStorage.setItem('mepharma_token', val);
      if (!localStorage.getItem(SESSION_TIME_KEY)) {
        localStorage.setItem(SESSION_TIME_KEY, Date.now().toString());
      }
    } else if (!initialSub) {
      clearStoredSession();
    }
  } catch (_) {}
  initialSub = false;
});

userStore.subscribe((val) => {
  try {
    if (val) localStorage.setItem('mepharma_user', JSON.stringify(val));
    else localStorage.removeItem('mepharma_user');
  } catch (_) {}
});

export function startSession(token: string, user: any) {
  localStorage.setItem(SESSION_TIME_KEY, Date.now().toString());
  localStorage.setItem('mepharma_token', token);
  localStorage.setItem('mepharma_user', JSON.stringify(user));
  tokenStore.set(token);
  userStore.set(user);
  if (typeof window !== 'undefined' && (wildcardListeners.size > 0 || Object.keys(sseListeners).length > 0)) {
    reconnectSSE();
  }
}

export function clearSession() {
  closeSSE();
  clearStoredSession();
  tokenStore.set(null);
  userStore.set(null);
}

export function checkAndRotateSession(): boolean {
  const token = getInitialToken();
  if (!token) {
    clearSession();
    return false;
  }
  return true;
}

export function addToast(message: string, type: 'success' | 'error' | 'info' | 'warning' = 'info') {
  const id = Math.random().toString(36).substring(2, 9);
  alertsStore.update((all) => [...all, { id, type, message }]);
  setTimeout(() => {
    alertsStore.update((all) => all.filter((a) => a.id !== id));
  }, 4500);
}

export function getDomainTenant(): string | null {
  try {
    if (typeof window === 'undefined') return null;
    const host = window.location.hostname.toLowerCase();

    // 1. *.localhost (e.g. main.localhost, branch.localhost)
    if (host.endsWith('.localhost')) {
      const sub = host.slice(0, -'.localhost'.length);
      if (sub && !['admin', 'provider', 'www', 'api'].includes(sub)) {
        return sub;
      }
      return null;
    }

    // 2. Exact localhost or IP address (e.g. 127.0.0.1)
    if (host === 'localhost' || host === '127.0.0.1' || /^(\d{1,3}\.){3}\d{1,3}$/.test(host)) {
      return null;
    }

    // 3. *.mepharma.io (e.g. main.mepharma.io)
    if (host.endsWith('.mepharma.io')) {
      const sub = host.slice(0, -'.mepharma.io'.length);
      if (sub && !['admin', 'provider', 'www', 'api'].includes(sub)) {
        return sub;
      }
      return null;
    }

    // 4. Multi-part custom subdomains (sub.domain.com)
    const parts = host.split('.');
    if (parts.length >= 3) {
      const sub = parts[0];
      if (!['admin', 'provider', 'www', 'api'].includes(sub)) {
        return sub;
      }
    }
  } catch (_) {}
  return null;
}

export function detectCurrentTenant(): string {
  const domainTenant = getDomainTenant();
  if (domainTenant) {
    return domainTenant;
  }
  return localStorage.getItem('mepharma_pharmacy_code') || 'main';
}

export function setTenantCode(code: string) {
  try {
    localStorage.setItem('mepharma_pharmacy_code', code);
  } catch (_) {}
}

export async function apiRequest<T = any>(endpoint: string, options: RequestInit = {}): Promise<T> {
  const sessionTimeStr = localStorage.getItem(SESSION_TIME_KEY);
  if (sessionTimeStr) {
    const sessionTime = parseInt(sessionTimeStr, 10);
    if (isNaN(sessionTime) || (Date.now() - sessionTime) > MAX_SESSION_DURATION_MS) {
      clearSession();
      throw new Error('Session expired (24h limit reached). Please sign in again.');
    }
    localStorage.setItem(SESSION_TIME_KEY, Date.now().toString());
  }

  const token = localStorage.getItem('mepharma_token');
  const pharmacyCode = detectCurrentTenant();
  const headers: Record<string, string> = {
    'X-Pharmacy-Code': pharmacyCode,
    ...(options.headers as any),
  };

  if (options.body) {
    headers['Content-Type'] = 'application/json';
  }

  if (token) {
    headers['Authorization'] = `Bearer ${token}`;
  }

  const url = endpoint.startsWith('http') ? endpoint : (endpoint.startsWith('/') ? endpoint : `/${endpoint}`);
  const res = await fetch(url, { ...options, headers });

  const contentType = res.headers.get('content-type') || '';
  if (contentType.includes('text/html')) {
    throw new Error(`API endpoint not found: ${url}`);
  }

  if (res.status === 401) {
    if (url.includes('/auth/login')) {
      const errData = await res.json().catch(() => ({}));
      throw new Error(errData.error || errData.message || 'Invalid username or password.');
    }
    clearSession();
    throw new Error('Session expired. Please log in again.');
  }

  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    if (res.status === 403 && data.code === 'DESKTOP_CLIENT_REQUIRED') {
      throw new Error(data.message || 'Access Denied: Pharmacists and Supervisors must use the Desktop POS Application.');
    }
    throw new Error(data.message || data.error || `Request failed with status ${res.status}`);
  }

  return data as T;
}


// SSE Real-time Updates
let eventSource: EventSource | null = null;
let sseReconnectTimer: any = null;
type SSEListener = (data: any) => void;
type SSEWildcardListener = (eventObj: { event: string; data?: any }) => void;
const sseListeners: Record<string, Set<SSEListener>> = {};
const wildcardListeners: Set<SSEWildcardListener> = new Set();

export function closeSSE() {
  if (sseReconnectTimer) {
    clearTimeout(sseReconnectTimer);
    sseReconnectTimer = null;
  }
  if (eventSource) {
    eventSource.close();
    eventSource = null;
  }
}

export function reconnectSSE() {
  closeSSE();
  initSSE();
}

export function subscribeToSSE(
  eventOrCallback: string | SSEWildcardListener,
  callback?: SSEListener
) {
  if (typeof eventOrCallback === 'function') {
    const fn = eventOrCallback;
    wildcardListeners.add(fn);
    if (!eventSource && typeof window !== 'undefined') {
      initSSE();
    }
    return () => {
      wildcardListeners.delete(fn);
    };
  }

  const event = eventOrCallback;
  if (!callback) return () => {};

  if (!sseListeners[event]) {
    sseListeners[event] = new Set();
  }
  sseListeners[event].add(callback);

  if (!eventSource && typeof window !== 'undefined') {
    initSSE();
  }

  return () => {
    sseListeners[event]?.delete(callback);
  };
}

function initSSE() {
  if (eventSource || typeof window === 'undefined') return;
  try {
    const token = localStorage.getItem('mepharma_token');
    if (!token) return;
    const pharmacyCode = detectCurrentTenant();
    const sseUrl = `/sync/events?pharmacy=${encodeURIComponent(pharmacyCode)}&token=${encodeURIComponent(token)}`;
    eventSource = new EventSource(sseUrl);
    const supportedEvents = [
      'purchase_created',
      'purchase_approved',
      'sale_created',
      'product_created',
      'product_updated',
      'product_deleted',
      'user_created',
      'user_updated',
      'user_deleted',
      'category_created',
      'supplier_created',
      'settings_updated',
      'sync_event'
    ];

    supportedEvents.forEach((evtName) => {
      eventSource?.addEventListener(evtName, (e: any) => {
        try {
          const payload = JSON.parse(e.data);
          const listeners = sseListeners[evtName];
          listeners?.forEach((fn) => fn(payload));
          wildcardListeners.forEach((fn) => {
            try {
              fn({ event: evtName, data: payload, ...payload });
            } catch (_) {}
          });
        } catch (_) {}
      });
    });

    eventSource.onerror = () => {
      eventSource?.close();
      eventSource = null;
      if (sseReconnectTimer) clearTimeout(sseReconnectTimer);
      if (localStorage.getItem('mepharma_token')) {
        sseReconnectTimer = setTimeout(initSSE, 10000);
      }
    };
  } catch (_) {}
}
