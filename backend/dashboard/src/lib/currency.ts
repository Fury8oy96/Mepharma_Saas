import { writable } from 'svelte/store';
import { apiRequest } from './api';

const CURRENCY_STORAGE_KEY = 'mepharma_currency';

function getInitialCurrency(): string {
  try {
    if (typeof window !== 'undefined') {
      const saved = localStorage.getItem(CURRENCY_STORAGE_KEY);
      if (saved && saved.trim()) {
        return saved.trim();
      }
    }
  } catch (_) {}
  return 'SDG';
}

export const currencyStore = writable<string>(getInitialCurrency());

export function setCurrencySymbol(symbol: string) {
  const clean = (symbol || 'SDG').trim() || 'SDG';
  currencyStore.set(clean);
  try {
    if (typeof window !== 'undefined') {
      localStorage.setItem(CURRENCY_STORAGE_KEY, clean);
    }
  } catch (_) {}
}

export async function refreshCurrencyFromStoreSettings() {
  try {
    const res = await apiRequest('/settings/store');
    const symbol = res?.currency || res?.currencySymbol || res?.['store.currency_symbol'];
    if (symbol) {
      setCurrencySymbol(String(symbol));
    }
  } catch (_) {
    // Silent fallback when not in tenant session or endpoint unavailable
  }
}

