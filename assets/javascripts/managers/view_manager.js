/**
 * Gerencia a renderização e manipulação do DOM para a tabela de fluxo de caixa.
 * É o único responsável por tocar na UI, garantindo separação de responsabilidades.
 */
export class ViewManager {
  /**
   * @param {string} tableSelector - O seletor CSS para o elemento da tabela.
   */
  constructor(tableSelector) {
    this.tableElement = document.querySelector(tableSelector);
    if (!this.tableElement) {
      console.error(`[ViewManager] Tabela com seletor "${tableSelector}" não encontrada.`);
      return;
    }

    this.tbody = this.tableElement.querySelector('tbody');
    this.activeFiltersBar = document.getElementById('cf-active-filters-bar');

    // Captura todas as linhas de dados uma única vez para performance.
    this.originalRows = this.tbody ? Array.from(this.tbody.querySelectorAll('tr.issue-row')) : [];
  }

  /**
   * Ponto de entrada para iniciar a funcionalidade da tabela.
   */
  initialize() {
    if (!this.tableElement) return;
    console.log('ViewManager initialized.');
    this.renderTable(this.originalRows);
  }

  /**
   * Renderiza as linhas na tabela.
   * @param {HTMLElement[]} rowsToRender - Um array de elementos <tr> para serem exibidos.
   */
  renderTable(rowsToRender) {
    if (!this.tbody) return;

    this.tbody.innerHTML = '';
    rowsToRender.forEach(row => this.tbody.appendChild(row));
  }

  /**
   * Renderiza as pílulas de filtros ativos na barra de filtros.
   * @param {Map} activeFilters - O Map de filtros ativos do FilterManager.
   * @param {Function} onRemove - Callback para quando um filtro é removido.
   * @param {Function} onPillClick - Callback para quando uma pílula é clicada para edição.
   */
  renderActiveFilterPills(activeFilters, onRemove, onPillClick) {
    if (!this.activeFiltersBar) return;

    this.activeFiltersBar.innerHTML = ''; // Limpa a barra
    const fragment = document.createDocumentFragment();

    activeFilters.forEach((filter, column) => {
      const header = this.tableElement.querySelector(`th[data-column="${column}"]`);
      const columnName = header ? header.textContent.trim() : column;

      const pill = document.createElement('div');
      pill.className = 'cf-filter-pill';
      pill.dataset.column = column;
      pill.innerHTML = `
        <span class="pill-column">${columnName}</span>
        <span class="pill-operator">${filter.operatorText}</span>
        <span class="pill-value">${filter.getDisplayValue()}</span>
        <button class="pill-remove-btn" title="${window.I18n.t('label_remove_filter') || 'Remover filtro'}">&times;</button>
      `;

      pill.querySelector('.pill-remove-btn').addEventListener('click', (e) => {
        e.stopPropagation();
        onRemove(column);
      });

      pill.addEventListener('click', () => {
        onPillClick(header);
      });

      fragment.appendChild(pill);
    });

    this.activeFiltersBar.appendChild(fragment);
  }
}