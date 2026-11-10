const http = require('http');
const fs = require('fs');

const loginReq = http.request({
  hostname: 'localhost',
  port: 8000,
  path: '/auth/login',
  method: 'POST',
  headers: { 'Content-Type': 'application/json' }
}, res => {
  let data = '';
  res.on('data', c => data += c);
  res.on('end', () => {
    const login = JSON.parse(data);
    const token = login.token;
    console.log('[1] Token obtained, length:', token.length);

    // Test overview
    const overviewReq = http.get({
      hostname: 'localhost', port: 8000, path: '/reports/overview',
      headers: { 'Authorization': 'Bearer ' + token }
    }, overviewRes => {
      let s = '';
      overviewRes.on('data', c => s += c);
      overviewRes.on('end', () => {
        if (overviewRes.statusCode !== 200) {
          console.log('[2] /reports/overview HTTP ' + overviewRes.statusCode + ': ' + s);
          return;
        }
        const j = JSON.parse(s);
        console.log('=== /reports/overview OK ===');
        console.log('  revenue:', j.sales.revenue);
        console.log('  grossRevenue:', j.sales.grossRevenue);
        console.log('  costOfGoods:', j.sales.costOfGoods);
        console.log('  grossProfit:', j.sales.grossProfit);
        console.log('  total:', j.sales.total);
        console.log('  aov:', j.sales.aov);
        console.log('  profitMarginPct:', j.sales.profitMarginPct);
        console.log('  products.total:', j.products.total);
        console.log('  products.lowStock:', j.products.lowStock);
        console.log('  products.expiring:', j.products.expiring);
        console.log('  stock.retailValue:', j.stock.retailValue);
        console.log('  stock.costValue:', j.stock.costValue);
        console.log('  stock.potentialMargin:', j.stock.potentialMargin);
        console.log('  users.total:', j.users.total);
        console.log('  users.active:', j.users.active);
        console.log('  serverTime:', j.serverTime);
        console.log('  uptime:', j.uptime);
      });
    });
    overviewReq.on('error', e => console.error('[2] error:', e.message));

    // Test summary  
    const summaryReq = http.get({
      hostname: 'localhost', port: 8000, path: '/reports/summary',
      headers: { 'Authorization': 'Bearer ' + token }
    }, summaryRes => {
      let s = '';
      summaryRes.on('data', c => s += c);
      summaryRes.on('end', () => {
        if (summaryRes.statusCode !== 200) {
          console.log('[3] /reports/summary HTTP ' + summaryRes.statusCode + ': ' + s);
          return;
        }
        const j = JSON.parse(s);
        console.log('=== /reports/summary OK ===');
        console.log('  revenue:', j.revenue, 'sales_count:', j.sales_count);
        console.log('  gross_revenue:', j.gross_revenue, 'refunds:', j.refunds);
        console.log('  cost_of_goods:', j.cost_of_goods);
        console.log('  purchases_cost:', j.purchases_cost, 'total_purchases:', j.total_purchases);
        console.log('  low_stock_count:', j.low_stock_count);
        console.log('  total_tax:', j.total_tax, 'total_discount:', j.total_discount);
        console.log('  sales_by_payment count:', j.sales_by_payment.length);
        console.log('  top_products count:', j.top_products.length);
        console.log('  trends count:', j.trends.length);
      });
    });
    summaryReq.on('error', e => console.error('[3] error:', e.message));

    // Test stock-valuation
    const svReq = http.get({
      hostname: 'localhost', port: 8000, path: '/reports/stock-valuation',
      headers: { 'Authorization': 'Bearer ' + token }
    }, svRes => {
      let s = '';
      svRes.on('data', c => s += c);
      svRes.on('end', () => {
        if (svRes.statusCode !== 200) {
          console.log('[4] /reports/stock-valuation HTTP ' + svRes.statusCode + ': ' + s);
          return;
        }
        const j = JSON.parse(s);
        console.log('=== /reports/stock-valuation OK ===');
        console.log('  items:', j.items, 'cost_value:', j.cost_value, 'retail_value:', j.retail_value);
        console.log('  potential_profit:', j.potential_profit);
      });
    });
    svReq.on('error', e => console.error('[4] error:', e.message));

    // Test monthly
    const monthlyReq = http.get({
      hostname: 'localhost', port: 8000, path: '/reports/monthly?months=6',
      headers: { 'Authorization': 'Bearer ' + token }
    }, monthlyRes => {
      let s = '';
      monthlyRes.on('data', c => s += c);
      monthlyRes.on('end', () => {
        if (monthlyRes.statusCode !== 200) {
          console.log('[5] /reports/monthly HTTP ' + monthlyRes.statusCode + ': ' + s);
          return;
        }
        const j = JSON.parse(s);
        console.log('=== /reports/monthly OK ===');
        console.log('  entries:', j.length);
        console.log('  first:', j[0]);
      });
    });
    monthlyReq.on('error', e => console.error('[5] error:', e.message));

    // Test categories
    const catReq = http.get({
      hostname: 'localhost', port: 8000, path: '/reports/categories',
      headers: { 'Authorization': 'Bearer ' + token }
    }, catRes => {
      let s = '';
      catRes.on('data', c => s += c);
      catRes.on('end', () => {
        if (catRes.statusCode !== 200) {
          console.log('[6] /reports/categories HTTP ' + catRes.statusCode + ': ' + s);
          return;
        }
        const j = JSON.parse(s);
        console.log('=== /reports/categories OK ===');
        console.log('  entries:', j.length);
        console.log('  first:', JSON.stringify(j[0]));
      });
    });
    catReq.on('error', e => console.error('[6] error:', e.message));
  });
});
loginReq.write(JSON.stringify({username:'admin', password:'admin123'}));
loginReq.end();
