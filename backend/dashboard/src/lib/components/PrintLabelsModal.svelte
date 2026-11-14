<script lang="ts">
  import { generateBarcodeSVG, BARCODE_SYMBOLOGIES, type BarcodeSymbology } from '../utils/barcode';
  import { icons } from '../utils/icons';
  import { currencyStore } from '../currency';
  import { t, currentLocale } from '../i18n/store';

  export let show = false;
  export let selectedProducts: any[] = [];
  export let storeName = 'MePharma Pharmacy';
  export let onClose = () => {};

  type LayoutType = 
    | 'thermal_50x32'
    | 'thermal_50x25'
    | 'thermal_40x30'
    | 'a4_44'
    | 'a4_40'
    | 'a4_30'
    | 'a4_24'
    | 'a4_16'
    | 'a4_9';

  let layout: LayoutType = 'a4_40';
  let symbology: BarcodeSymbology = 'CODE128';
  let showStoreName = true;
  let showPrice = true;
  let showExpiry = true;

  // Track quantities per product
  let productQuantities: Record<number, number> = {};

  $: {
    if (selectedProducts && selectedProducts.length > 0) {
      for (const p of selectedProducts) {
        if (productQuantities[p.id] === undefined) {
          productQuantities[p.id] = 1;
        }
      }
    }
  }

  function getPageCapacity(l: LayoutType): number {
    switch (l) {
      case 'a4_44': return 44;
      case 'a4_40': return 40;
      case 'a4_30': return 30;
      case 'a4_24': return 24;
      case 'a4_16': return 16;
      case 'a4_9': return 9;
      default: return 1;
    }
  }

  function updateQuantity(productId: number, delta: number) {
    const current = productQuantities[productId] || 1;
    const updated = Math.max(1, current + delta);
    productQuantities[productId] = updated;
    productQuantities = { ...productQuantities };
  }

  function setQuantity(productId: number, val: number) {
    productQuantities[productId] = Math.max(1, Number(val) || 1);
    productQuantities = { ...productQuantities };
  }

  function fillFullSheet() {
    const capacity = getPageCapacity(layout);
    if (selectedProducts.length === 0) return;
    const perItem = Math.max(1, Math.floor(capacity / selectedProducts.length));
    for (const p of selectedProducts) {
      productQuantities[p.id] = perItem;
    }
    productQuantities = { ...productQuantities };
  }

  function removeProduct(productId: number) {
    selectedProducts = selectedProducts.filter(p => p.id !== productId);
  }

  $: labelItems = selectedProducts.flatMap(p => {
    const count = productQuantities[p.id] || 1;
    const barcodeVal = (p.barcode || p.sku || `MP-${p.id}`).trim();

    // Scale barcode size precisely for each format
    let barcodeHeight = 22;
    let barWidth = 0.95;
    let fontSize = 8.5;

    if (layout === 'a4_44') {
      barcodeHeight = 18;
      barWidth = 0.85;
      fontSize = 7.5;
    } else if (layout === 'a4_40') {
      barcodeHeight = 20;
      barWidth = 0.9;
      fontSize = 8;
    } else if (layout === 'a4_30') {
      barcodeHeight = 22;
      barWidth = 1.1;
      fontSize = 8.5;
    } else if (layout === 'a4_24') {
      barcodeHeight = 28;
      barWidth = 1.2;
      fontSize = 9;
    } else if (layout === 'a4_16') {
      barcodeHeight = 32;
      barWidth = 1.4;
      fontSize = 10;
    } else if (layout === 'a4_9') {
      barcodeHeight = 50;
      barWidth = 1.6;
      fontSize = 12;
    } else if (layout.startsWith('thermal')) {
      barcodeHeight = 30;
      barWidth = 1.2;
      fontSize = 9;
    }

    const svgContent = generateBarcodeSVG(barcodeVal, {
      symbology: symbology,
      height: barcodeHeight,
      barWidth: barWidth,
      includeText: true,
      fontSize: fontSize
    });

    return Array(count).fill({
      product: p,
      barcode: barcodeVal,
      svg: svgContent
    });
  });

  function getPrintCSS(l: LayoutType): string {
    if (l.startsWith('thermal_')) {
      let w = '50mm', h = '32mm';
      if (l === 'thermal_50x25') { w = '50mm'; h = '25mm'; }
      if (l === 'thermal_40x30') { w = '40mm'; h = '30mm'; }
      return `
        @page { size: ${w} ${h}; margin: 0; }
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
          font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
          background: #fff;
          color: #000;
          -webkit-print-color-adjust: exact;
          print-color-adjust: exact;
        }
        .labels-print-container {
          display: block;
          width: ${w};
        }
        .barcode-sticker {
          width: ${w};
          height: ${h};
          padding: 1.5mm 2mm;
          display: flex;
          flex-direction: column;
          justify-content: space-between;
          align-items: center;
          text-align: center;
          page-break-after: always;
          break-after: page;
          overflow: hidden;
          box-sizing: border-box;
        }
        .sticker-store { font-size: 6.5pt; font-weight: 700; text-transform: uppercase; color: #333; }
        .sticker-name { font-size: 7.5pt; font-weight: 700; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; width: 100%; color: #000; }
        .sticker-barcode-svg { display: flex; justify-content: center; align-items: center; width: 100%; }
        .sticker-barcode-svg svg { max-width: 100%; height: auto; }
        .sticker-footer { display: flex; justify-content: space-between; width: 100%; font-size: 6.5pt; font-weight: 600; }
        .sticker-price { font-weight: 800; color: #000; }
        .sticker-exp { color: #555; }
      `;
    }

    // A4 Formats
    let cols = 4;
    let colWidth = '48.5mm';
    let rowHeight = '25.4mm';
    let gap = '1.2mm';
    let nameSize = '7pt';
    let footerSize = '6.5pt';
    let storeSize = '6pt';
    let barcodeMaxH = '13mm';

    if (l === 'a4_40') {
      cols = 4;
      colWidth = '48.5mm';
      rowHeight = '28mm';
      gap = '1.2mm';
      nameSize = '7.5pt';
      footerSize = '6.5pt';
      storeSize = '6pt';
      barcodeMaxH = '15mm';
    } else if (l === 'a4_30') {
      cols = 3;
      colWidth = '65mm';
      rowHeight = '28mm';
      gap = '1.5mm';
      nameSize = '8pt';
      footerSize = '7pt';
      storeSize = '6.5pt';
      barcodeMaxH = '15mm';
    } else if (l === 'a4_24') {
      cols = 3;
      colWidth = '65mm';
      rowHeight = '35mm';
      gap = '1.8mm';
      nameSize = '8.5pt';
      footerSize = '7.5pt';
      storeSize = '7pt';
      barcodeMaxH = '19mm';
    } else if (l === 'a4_16') {
      cols = 2;
      colWidth = '96mm';
      rowHeight = '35mm';
      gap = '2.5mm';
      nameSize = '9.5pt';
      footerSize = '8pt';
      storeSize = '7.5pt';
      barcodeMaxH = '20mm';
    } else if (l === 'a4_9') {
      cols = 3;
      colWidth = '64mm';
      rowHeight = '90mm';
      gap = '2.5mm';
      nameSize = '11pt';
      footerSize = '9pt';
      storeSize = '8.5pt';
      barcodeMaxH = '45mm';
    }

    return `
      @page {
        size: A4 portrait;
        margin: 5mm 4mm;
      }
      * { box-sizing: border-box; margin: 0; padding: 0; }
      body {
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
        background: #fff;
        color: #000;
        -webkit-print-color-adjust: exact;
        print-color-adjust: exact;
      }
      .labels-print-container {
        display: grid;
        grid-template-columns: repeat(${cols}, ${colWidth});
        grid-auto-rows: ${rowHeight};
        gap: ${gap};
        width: 100%;
        max-width: 202mm;
        margin: 0 auto;
      }
      .barcode-sticker {
        width: ${colWidth};
        height: ${rowHeight};
        padding: 1.2mm 1.8mm;
        display: flex;
        flex-direction: column;
        justify-content: space-between;
        align-items: center;
        text-align: center;
        border: 0.5px dashed #d0d2d6;
        page-break-inside: avoid;
        break-inside: avoid;
        overflow: hidden;
        box-sizing: border-box;
      }
      .sticker-store { font-size: ${storeSize}; font-weight: 700; text-transform: uppercase; color: #444; }
      .sticker-name { font-size: ${nameSize}; font-weight: 700; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; width: 100%; color: #000; }
      .sticker-barcode-svg { display: flex; justify-content: center; align-items: center; width: 100%; overflow: hidden; }
      .sticker-barcode-svg svg { max-width: 100%; max-height: ${barcodeMaxH}; height: auto; }
      .sticker-footer { display: flex; justify-content: space-between; width: 100%; font-size: ${footerSize}; font-weight: 600; }
      .sticker-price { font-weight: 800; color: #000; }
      .sticker-exp { color: #555; }
    `;
  }

  function handlePrint() {
    const printElement = document.getElementById('print-labels-container');
    if (!printElement) {
      window.print();
      return;
    }

    // Build isolated print iframe to prevent modal or viewport styling interference
    const iframe = document.createElement('iframe');
    iframe.style.position = 'fixed';
    iframe.style.right = '0';
    iframe.style.bottom = '0';
    iframe.style.width = '0';
    iframe.style.height = '0';
    iframe.style.border = '0';
    document.body.appendChild(iframe);

    const doc = iframe.contentWindow?.document;
    if (!doc) return;

    const styleOpen = '<st' + 'yle>';
    const styleClose = '</st' + 'yle>';
    doc.open();
    doc.write(`
      <!DOCTYPE html>
      <html>
      <head>
        <title>Print Labels</title>
        ${styleOpen}
          ${getPrintCSS(layout)}
        ${styleClose}
      </head>
      <body>
        <div class="labels-print-container">
          ${printElement.innerHTML}
        </div>
      </body>
      </html>
    `);
    doc.close();

    iframe.contentWindow?.focus();
    setTimeout(() => {
      iframe.contentWindow?.print();
      setTimeout(() => {
        if (document.body.contains(iframe)) {
          document.body.removeChild(iframe);
        }
      }, 1500);
    }, 250);
  }
</script>

{#if show}
  <div class="modal-backdrop print-hide animate-fade-in" on:click|self={onClose} role="dialog" aria-modal="true">
    <div class="modal-card vuexy-card modal-xl animate-scale-up">
      <div class="modal-header">
        <div>
          <h3>{$t('print.title')}</h3>
          <p class="sub-text">{$t('print.subtitle')}</p>
        </div>
        <button class="close-btn" on:click={onClose}>{@html icons.x}</button>
      </div>

      <div class="print-studio-grid">
        <!-- Configuration Controls -->
        <div class="config-sidebar">
          <div class="control-section">
            <span class="section-title">{$t('print.template')}</span>
            
            <!-- A4 Sheet Formats -->
            <div class="category-header">
              <span class="category-title">{$t('print.typeA4')}</span>
            </div>
            <div class="layout-selector">
              <label class="layout-card" class:active={layout === 'a4_44'}>
                <input type="radio" bind:group={layout} value="a4_44" />
                <div class="layout-info">
                  <span class="layout-name">{$t('print.a4_44')}</span>
                  <span class="layout-sub">4 cols × 11 rows (48.5 × 25.4 mm)</span>
                </div>
              </label>

              <label class="layout-card" class:active={layout === 'a4_40'}>
                <input type="radio" bind:group={layout} value="a4_40" />
                <div class="layout-info">
                  <span class="layout-name">{$t('print.a4_40')}</span>
                  <span class="layout-sub">4 cols × 10 rows (50 × 28.5 mm)</span>
                </div>
              </label>

              <label class="layout-card" class:active={layout === 'a4_30'}>
                <input type="radio" bind:group={layout} value="a4_30" />
                <div class="layout-info">
                  <span class="layout-name">{$t('print.a4_30')}</span>
                  <span class="layout-sub">3 cols × 10 rows (70 × 29.7 mm)</span>
                </div>
              </label>

              <label class="layout-card" class:active={layout === 'a4_24'}>
                <input type="radio" bind:group={layout} value="a4_24" />
                <div class="layout-info">
                  <span class="layout-name">{$t('print.a4_24')}</span>
                  <span class="layout-sub">3 cols × 8 rows (70 × 37 mm)</span>
                </div>
              </label>

              <label class="layout-card" class:active={layout === 'a4_16'}>
                <input type="radio" bind:group={layout} value="a4_16" />
                <div class="layout-info">
                  <span class="layout-name">{$t('print.a4_16')}</span>
                  <span class="layout-sub">2 cols × 8 rows (105 × 37 mm)</span>
                </div>
              </label>

              <label class="layout-card" class:active={layout === 'a4_9'}>
                <input type="radio" bind:group={layout} value="a4_9" />
                <div class="layout-info">
                  <span class="layout-name">{$t('print.a4_9')}</span>
                  <span class="layout-sub">3 cols × 3 rows (shelf & box cards)</span>
                </div>
              </label>
            </div>

            <!-- Thermal Roll Formats -->
            <div class="category-header mt-2">
              <span class="category-title">{$t('print.typeThermal')}</span>
            </div>
            <div class="layout-selector">
              <label class="layout-card" class:active={layout === 'thermal_50x32'}>
                <input type="radio" bind:group={layout} value="thermal_50x32" />
                <div class="layout-info">
                  <span class="layout-name">{$t('print.thermal50x32')}</span>
                  <span class="layout-sub">50 × 32 mm pharmacy medicine box roll</span>
                </div>
              </label>

              <label class="layout-card" class:active={layout === 'thermal_50x25'}>
                <input type="radio" bind:group={layout} value="thermal_50x25" />
                <div class="layout-info">
                  <span class="layout-name">{$t('print.thermal50x25')}</span>
                  <span class="layout-sub">50 × 25 mm standard sticker roll</span>
                </div>
              </label>

              <label class="layout-card" class:active={layout === 'thermal_40x30'}>
                <input type="radio" bind:group={layout} value="thermal_40x30" />
                <div class="layout-info">
                  <span class="layout-name">{$t('print.thermal40x30')}</span>
                  <span class="layout-sub">40 × 30 mm compact bottle & vial roll</span>
                </div>
              </label>
            </div>
          </div>

          <div class="control-section">
            <span class="section-title">{$t('print.symbology')}</span>
            <select class="form-select" bind:value={symbology}>
              {#each BARCODE_SYMBOLOGIES as s}
                <option value={s.id}>{s.name} ({s.category})</option>
              {/each}
            </select>
          </div>

          <div class="control-section">
            <span class="section-title">{$t('print.elements')}</span>
            <div class="toggles-grid">
              <label class="toggle-checkbox">
                <input type="checkbox" bind:checked={showStoreName} />
                <span>{$t('print.showPharmacy')}</span>
              </label>
              <label class="toggle-checkbox">
                <input type="checkbox" bind:checked={showPrice} />
                <span>{$t('print.showPrice')}</span>
              </label>
              <label class="toggle-checkbox">
                <input type="checkbox" bind:checked={showExpiry} />
                <span>{$t('overview.kpi.expiring')}</span>
              </label>
            </div>
          </div>

          <div class="control-section">
            <div class="section-title-row">
              <span class="section-title">{$t('print.selectedItems')} ({selectedProducts.length})</span>
              {#if layout.startsWith('a4_')}
                <button class="btn-xs-primary" on:click={fillFullSheet}>
                  {$t('print.fillPage')} ({getPageCapacity(layout)})
                </button>
              {/if}
            </div>

            <div class="products-copy-list">
              {#each selectedProducts as p}
                <div class="product-qty-row">
                  <div class="product-info-compact">
                    <span class="p-name-compact">{p.name}</span>
                    <span class="p-barcode-compact">{p.barcode || p.sku || `MP-${p.id}`}</span>
                  </div>
                  <div class="qty-counter">
                    <button class="btn-qty" on:click={() => updateQuantity(p.id, -1)}>-</button>
                    <input 
                      type="number" 
                      class="qty-input" 
                      min="1" 
                      value={productQuantities[p.id] || 1} 
                      on:input={(e) => setQuantity(p.id, parseInt(e.currentTarget.value))}
                    />
                    <button class="btn-qty" on:click={() => updateQuantity(p.id, 1)}>+</button>
                    <button class="btn-remove-p" on:click={() => removeProduct(p.id)} title={$t('btn.delete')}>
                      {@html icons.x}
                    </button>
                  </div>
                </div>
              {/each}
            </div>
          </div>
        </div>

        <!-- Live Preview Stage -->
        <div class="preview-stage">
          <div class="preview-header">
            <div>
              <span class="preview-title">{$t('print.preview')} ({labelItems.length} {$t('print.labelsTotal')})</span>
              {#if layout.startsWith('a4_')}
                <span class="preview-sheet-calc">
                  ({Math.ceil(labelItems.length / getPageCapacity(layout))} {$t('print.a4Sheet')})
                </span>
              {/if}
            </div>
            <span class="preview-badge">{layout.toUpperCase()}</span>
          </div>

          <div class="preview-canvas-wrapper">
            <div id="print-labels-container" class="labels-container layout-{layout}">
              {#each labelItems as item}
                <div class="barcode-sticker layout-{layout}">
                  {#if showStoreName}
                    <div class="sticker-store">{storeName}</div>
                  {/if}
                  <div class="sticker-name">{item.product.name}</div>
                  <div class="sticker-barcode-svg">
                    {@html item.svg}
                  </div>
                  <div class="sticker-footer">
                    {#if showPrice}
                      <span class="sticker-price">{$currencyStore} {item.product.selling_price}</span>
                    {/if}
                    {#if showExpiry && item.product.expiry_date}
                      <span class="sticker-exp">{$currentLocale === 'ar' ? 'انتهاء:' : 'EXP:'} {item.product.expiry_date.split('T')[0]}</span>
                    {/if}
                  </div>
                </div>
              {/each}
            </div>
          </div>
        </div>
      </div>

      <div class="modal-footer">
        <button class="btn btn-secondary" on:click={onClose}>{$t('btn.close')}</button>
        <button class="btn btn-primary" on:click={handlePrint}>
          {@html icons.printer} {$t('print.btnPrint')}
        </button>
      </div>
    </div>
  </div>
{/if}

<style>
  .modal-xl {
    max-width: 1160px;
    width: 96%;
  }

  .print-studio-grid {
    display: grid;
    grid-template-columns: 390px 1fr;
    gap: 1.5rem;
    min-height: 520px;
  }

  .config-sidebar {
    display: flex;
    flex-direction: column;
    gap: 1.25rem;
    border-right: 1px solid var(--border-color);
    padding-right: 1.5rem;
    max-height: 580px;
    overflow-y: auto;
  }

  :global(html[dir="rtl"]) .config-sidebar {
    border-right: none;
    border-left: 1px solid var(--border-color);
    padding-right: 0;
    padding-left: 1.5rem;
  }

  .control-section {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .section-title-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }

  .section-title {
    font-size: 0.8125rem;
    font-weight: 700;
    color: var(--text-heading);
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }

  .category-header {
    margin-top: 4px;
    margin-bottom: 2px;
  }
  .category-title {
    font-size: 0.75rem;
    font-weight: 700;
    color: var(--color-primary);
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }

  .btn-xs-primary {
    background: var(--color-primary-light);
    color: var(--color-primary);
    border: 1px solid var(--color-primary);
    border-radius: 4px;
    font-size: 0.75rem;
    font-weight: 600;
    padding: 2px 8px;
    cursor: pointer;
    transition: all 0.2s;
  }
  .btn-xs-primary:hover {
    background: var(--color-primary);
    color: #fff;
  }

  .layout-selector {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }

  .layout-card {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 8px 10px;
    border-radius: var(--radius-sm);
    border: 1px solid var(--border-color);
    background: var(--bg-card);
    cursor: pointer;
    transition: all var(--transition);
  }
  .layout-card:hover {
    border-color: var(--color-primary);
  }
  .layout-card.active {
    border-color: var(--color-primary);
    background: var(--color-primary-light);
  }
  .layout-info {
    display: flex;
    flex-direction: column;
  }
  .layout-name {
    font-size: 0.8125rem;
    font-weight: 600;
    color: var(--text-heading);
  }
  .layout-sub {
    font-size: 0.6875rem;
    color: var(--text-muted);
  }

  .toggles-grid {
    display: grid;
    grid-template-columns: 1fr;
    gap: 8px;
  }
  .toggle-checkbox {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 0.8125rem;
    color: var(--text-primary);
    cursor: pointer;
  }

  .products-copy-list {
    display: flex;
    flex-direction: column;
    gap: 6px;
    max-height: 160px;
    overflow-y: auto;
  }

  .product-qty-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 6px 8px;
    border-radius: var(--radius-xs);
    background: var(--bg-input);
    border: 1px solid var(--border-color);
  }
  .product-info-compact {
    display: flex;
    flex-direction: column;
    max-width: 170px;
  }
  .p-name-compact {
    font-size: 0.8125rem;
    font-weight: 600;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .p-barcode-compact {
    font-size: 0.6875rem;
    color: var(--text-muted);
    font-family: var(--font-mono);
  }
  .qty-counter {
    display: flex;
    align-items: center;
    gap: 4px;
  }
  .btn-qty {
    width: 22px;
    height: 22px;
    background: var(--bg-card);
    border: 1px solid var(--border-color);
    color: var(--text-primary);
    border-radius: 4px;
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    font-weight: bold;
    font-size: 0.8125rem;
  }
  .qty-input {
    width: 36px;
    text-align: center;
    background: var(--bg-card);
    border: 1px solid var(--border-color);
    color: var(--text-primary);
    font-size: 0.8125rem;
    padding: 2px;
    border-radius: 4px;
  }
  .btn-remove-p {
    background: transparent;
    border: none;
    color: var(--color-danger);
    cursor: pointer;
    padding: 2px 4px;
    display: flex;
    align-items: center;
  }

  .preview-stage {
    display: flex;
    flex-direction: column;
    gap: 10px;
  }
  .preview-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }
  .preview-title {
    font-size: 0.875rem;
    font-weight: 600;
    color: var(--text-heading);
  }
  .preview-sheet-calc {
    font-size: 0.75rem;
    color: var(--text-muted);
    font-weight: 500;
    margin-left: 6px;
  }
  .preview-badge {
    font-size: 0.6875rem;
    font-weight: 700;
    padding: 2px 8px;
    background: var(--color-info-light);
    color: var(--color-info);
    border-radius: var(--radius-pill);
  }

  .preview-canvas-wrapper {
    flex: 1;
    background: #474e5d;
    border-radius: var(--radius-md);
    padding: 1.25rem;
    overflow-y: auto;
    max-height: 480px;
    display: flex;
    justify-content: center;
  }

  /* Preview Container Grids */
  .labels-container {
    display: flex;
    flex-wrap: wrap;
    gap: 10px;
    justify-content: center;
    box-sizing: border-box;
  }

  /* A4 Sheets Preview */
  .labels-container.layout-a4_44 {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    background: #ffffff;
    padding: 10px;
    width: 100%;
    max-width: 580px;
    border-radius: 4px;
    box-shadow: 0 4px 20px rgba(0,0,0,0.3);
    gap: 3px;
  }

  .labels-container.layout-a4_40 {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    background: #ffffff;
    padding: 10px;
    width: 100%;
    max-width: 580px;
    border-radius: 4px;
    box-shadow: 0 4px 20px rgba(0,0,0,0.3);
    gap: 4px;
  }

  .labels-container.layout-a4_30 {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    background: #ffffff;
    padding: 12px;
    width: 100%;
    max-width: 580px;
    border-radius: 4px;
    box-shadow: 0 4px 20px rgba(0,0,0,0.3);
    gap: 4px;
  }

  .labels-container.layout-a4_24 {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    background: #ffffff;
    padding: 12px;
    width: 100%;
    max-width: 580px;
    border-radius: 4px;
    box-shadow: 0 4px 20px rgba(0,0,0,0.3);
    gap: 6px;
  }

  .labels-container.layout-a4_16 {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    background: #ffffff;
    padding: 14px;
    width: 100%;
    max-width: 580px;
    border-radius: 4px;
    box-shadow: 0 4px 20px rgba(0,0,0,0.3);
    gap: 6px;
  }

  .labels-container.layout-a4_9 {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    background: #ffffff;
    padding: 14px;
    width: 100%;
    max-width: 580px;
    border-radius: 4px;
    box-shadow: 0 4px 20px rgba(0,0,0,0.3);
    gap: 8px;
  }

  /* Sticker Base */
  .barcode-sticker {
    background: #ffffff;
    color: #000000;
    border-radius: 2px;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: space-between;
    box-shadow: 0 1px 3px rgba(0,0,0,0.1);
    font-family: var(--font-sans);
    text-align: center;
    box-sizing: border-box;
  }

  /* Sticker Layout Dimension Specs */
  .barcode-sticker.layout-thermal_50x32 {
    width: 180px;
    height: 115px;
    padding: 4px 6px;
  }
  .barcode-sticker.layout-thermal_50x25 {
    width: 180px;
    height: 90px;
    padding: 3px 5px;
  }
  .barcode-sticker.layout-thermal_40x30 {
    width: 145px;
    height: 105px;
    padding: 3px;
  }

  .barcode-sticker.layout-a4_44 {
    height: 56px;
    padding: 2px 3px;
    border: 0.5px dashed #d0d2d6;
    box-shadow: none;
  }
  .barcode-sticker.layout-a4_40 {
    height: 62px;
    padding: 2px 3px;
    border: 0.5px dashed #d0d2d6;
    box-shadow: none;
  }
  .barcode-sticker.layout-a4_30 {
    height: 72px;
    padding: 3px 4px;
    border: 0.5px dashed #d0d2d6;
    box-shadow: none;
  }
  .barcode-sticker.layout-a4_24 {
    height: 86px;
    padding: 3px 5px;
    border: 0.5px dashed #d0d2d6;
    box-shadow: none;
  }
  .barcode-sticker.layout-a4_16 {
    height: 96px;
    padding: 4px 6px;
    border: 0.5px dashed #d0d2d6;
    box-shadow: none;
  }
  .barcode-sticker.layout-a4_9 {
    height: 130px;
    padding: 6px 8px;
    border: 0.5px dashed #d0d2d6;
    box-shadow: none;
  }

  .sticker-store {
    font-size: 7px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.03em;
    color: #444;
  }
  .sticker-name {
    font-size: 8.5px;
    font-weight: 700;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    width: 100%;
    color: #000;
  }
  .barcode-sticker.layout-a4_9 .sticker-name,
  .barcode-sticker.layout-a4_16 .sticker-name {
    font-size: 11px;
  }
  .barcode-sticker.layout-a4_44 .sticker-name {
    font-size: 7.5px;
  }

  .sticker-barcode-svg {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 100%;
    overflow: hidden;
  }
  .sticker-footer {
    display: flex;
    justify-content: space-between;
    width: 100%;
    font-size: 7px;
    font-weight: 600;
  }
  .sticker-price {
    font-weight: 800;
    color: #000;
  }
  .sticker-exp {
    color: #555;
  }

  .modal-footer {
    display: flex;
    justify-content: flex-end;
    gap: 12px;
    padding-top: 1rem;
    border-top: 1px solid var(--border-color);
  }

  .sub-text {
    font-size: 0.8125rem;
    color: var(--text-muted);
  }
</style>
