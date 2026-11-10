import type { PageData } from './$types';

export let data: PageData;

const stats = data.stats as any;
const loading = data.loading as boolean;

...[truncated]