import { writable } from 'svelte/store';

export type Theme = 'dark' | 'light';

const STORAGE_KEY = 'mepharma_dashboard_theme';

function getInitialTheme(): Theme {
  if (typeof window !== 'undefined') {
    const saved = localStorage.getItem(STORAGE_KEY) as Theme;
    if (saved === 'dark' || saved === 'light') {
      return saved;
    }
  }
  return 'dark';
}

export const currentTheme = writable<Theme>(getInitialTheme());

export function applyTheme(theme: Theme) {
  currentTheme.set(theme);
  if (typeof window !== 'undefined') {
    localStorage.setItem(STORAGE_KEY, theme);
    if (typeof document !== 'undefined') {
      document.body.classList.remove('theme-dark', 'theme-light');
      document.body.classList.add(`theme-${theme}`);
    }
  }
}

export function toggleTheme() {
  let activeTheme: Theme = 'dark';
  currentTheme.subscribe(t => activeTheme = t)();
  const next = activeTheme === 'dark' ? 'light' : 'dark';
  applyTheme(next);
}
