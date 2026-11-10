import { writable, derived } from 'svelte/store';
import { translations, type Locale } from './translations';

const STORAGE_KEY = 'mepharma_dashboard_locale';

function getInitialLocale(): Locale {
  if (typeof window !== 'undefined') {
    const saved = localStorage.getItem(STORAGE_KEY) as Locale;
    if (saved === 'en' || saved === 'ar') {
      return saved;
    }
  }
  return 'en';
}

export const currentLocale = writable<Locale>(getInitialLocale());

export function setLocale(locale: Locale) {
  currentLocale.set(locale);
  if (typeof window !== 'undefined') {
    localStorage.setItem(STORAGE_KEY, locale);
    updateDocumentDirection(locale);
  }
}

export function updateDocumentDirection(locale: Locale) {
  if (typeof document !== 'undefined') {
    document.documentElement.dir = locale === 'ar' ? 'rtl' : 'ltr';
    document.documentElement.lang = locale;
    if (locale === 'ar') {
      document.body.classList.add('rtl-mode');
    } else {
      document.body.classList.remove('rtl-mode');
    }
  }
}

// Derived store for reactive translation lookup: $t('key')
export const t = derived(currentLocale, ($locale) => {
  return (key: string, fallback?: string): string => {
    const entry = translations[key];
    if (!entry) {
      return fallback || key;
    }
    return entry[$locale] || entry['en'] || fallback || key;
  };
});

// Non-store helper
export function translate(key: string, locale: Locale, fallback?: string): string {
  const entry = translations[key];
  if (!entry) return fallback || key;
  return entry[locale] || entry['en'] || fallback || key;
}
