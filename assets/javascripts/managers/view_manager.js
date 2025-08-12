// Garante que o namespace global exista.
window.FotonCashFlow = window.FotonCashFlow || {};

/**
 * Gerencia a manipulação do DOM para a tabela e outros elementos da view.
 */
class ViewManager {
  constructor(tableWrapperSelector) {
    this.container = document.querySelector(tableWrapperSelector);
    if (!this.container) {
      console.error(`[ViewManager] Contêiner '${tableWrapperSelector}' não encontrado.`);
      return;
    }
    this.tableElement = this.container.querySelector('table.cf-table');
    this.tableBody = this.tableElement ? this.tableElement.querySelector('tbody') : null;
    this.originalRows = this.tableBody ? Array.from(this.tableBody.querySelectorAll('tr.issue-row')) : [];
    this.activeFiltersBar = document.getElementById('cf-active-filters-bar');
  }

  isInitialized() {
    return !!this.container;
  }

  getOriginalRows() {
    return this.originalRows;
  }

  /**
   * Limpa a tabela e renderiza apenas as linhas fornecidas.
   * @param {HTMLElement[]} rowsToRender - As linhas <tr> que devem ser exibidas.
   */
  renderTable(rowsToRender) {
    if (!this.tableBody) return;
    
    this.tableBody.innerHTML = ''; // Limpa o corpo da tabela
    if (rowsToRender.length === 0) {
      this.tableBody.innerHTML = `<tr><td colspan="8" class="nodata">${I18n.t('text_no_data_with_filters')}</td></tr>`;
    } else {
      rowsToRender.forEach(row => this.tableBody.appendChild(row));
    }
  }

  /**
   * Renderiza as "pílulas" que mostram os filtros ativos.
   * @param {Map} activeFilters - O Map de filtros ativos do FilterManager.
   * @param {Function} onRemove - Callback para quando uma pílula é removida.
   * @param {Function} onClick - Callback para quando uma pílula é clicada (para re-edição).
   * @param {Function} onClearAll - Callback para o botão de limpar todos os filtros.
   */
  renderActiveFilterPills(activeFilters, onRemove, onClick, onClearAll) {
    if (!this.activeFiltersBar) return;

    this.activeFiltersBar.innerHTML = '';
    if (activeFilters.size === 0) return;

    activeFilters.forEach((filter, column) => {
      const pill = document.createElement('div');
      pill.className = 'cf-filter-pill';
      pill.dataset.column = column;

      const header = this.tableElement.querySelector(`th[data-column="${column}"]`);
      const columnName = header ? header.innerText.trim() : column;

      pill.innerHTML = `
        <span class="pill-label">${columnName}: ${filter.value}</span>
        <span class="pill-remove-btn icon icon-close"></span>
      `;

      pill.querySelector('.pill-remove-btn').addEventListener('click', (e) => {
        e.stopPropagation();
        onRemove(column);
      });

      pill.addEventListener('click', () => {
        onClick(header);
      });

      this.activeFiltersBar.appendChild(pill);
    });

    // Adiciona o botão "Limpar todos" se houver filtros
    if (onClearAll) {
      const clearAllBtn = document.createElement('button');
      clearAllBtn.className = 'cf-clear-all-btn';
      clearAllBtn.textContent = (typeof I18n !== 'undefined' && I18n.t) ? I18n.t('label_clear_all_filters') : 'Clear all';
      clearAllBtn.addEventListener('click', onClearAll);
      this.activeFiltersBar.appendChild(clearAllBtn);
    }
  }

  /**
   * Atualiza os indicadores visuais de ordenação nas colunas do cabeçalho.
   * @param {string} column - A coluna que está sendo ordenada.
   * @param {string} direction - A direção da ordenação ('asc' ou 'desc').
   */
  updateSortIndicators(column, direction) {
    const headers = this.tableElement.querySelectorAll('th[data-sortable="true"]');
    headers.forEach(header => {
      header.classList.remove('sorted', 'asc', 'desc');
      const icon = header.querySelector('.cf-sort-icon');
      if (icon) {
        // Remove apenas as classes de direção, mantendo as classes base.
        icon.classList.remove('icon-sort-asc', 'icon-sort-desc');
      }

      const isSortedColumn = header.dataset.column === column;
      if (isSortedColumn) {
        header.classList.add('sorted', direction);
        if (icon) icon.classList.add(`icon-sort-${direction}`);
      }
  });
}
}

window.FotonCashFlow.ViewManager = ViewManager;