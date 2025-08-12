// Garante que o namespace global exista.
window.FotonCashFlow = window.FotonCashFlow || {};

/**
 * Gerencia o estado dos filtros e a interação com o FilterPopup.
 */
class FilterManager {
  constructor(controller) {
    this.controller = controller;
    this.activeFilters = new Map();
    this.currentPopup = null;
  }

  /**
   * Inicializa o FilterManager, adicionando listeners aos ícones de filtro na tabela.
   * Este método é chamado pelo CashFlowPageController.
   */
  initialize() {
    const tableElement = this.controller.viewManager.tableElement;
    if (!tableElement) return;
    
    console.log("[FilterManager] Procurando por ícones de filtro...");
    const filterIcons = tableElement.querySelectorAll('.cf-filter-icon');
    console.log(`[FilterManager] ${filterIcons.length} ícones de filtro encontrados.`);

    filterIcons.forEach(icon => {
      icon.addEventListener('click', (e) => {
        console.log("[FilterManager] Ícone de filtro clicado!", e.target);
        const header = e.target.closest('th');
        if (header) {
          console.log("[FilterManager] Cabeçalho correspondente encontrado. Abrindo popup para a coluna:", header.dataset.column);
          this.showFilterPopup(header);
        }
      });
    });
    // console.log(`[FilterManager] ${filterIcons.length} filter icons initialized.`);
  }

  /**
   * Mostra o popup de filtro para uma coluna específica.
   * @param {HTMLElement} headerElement - O elemento <th> da coluna.
   */
  showFilterPopup(headerElement) {
    console.log("[FilterManager] O método showFilterPopup foi chamado.");
    if (this.currentPopup) {
      this.currentPopup.destroy();
    }
    // Garante que a classe FilterPopup está disponível no namespace
    if (typeof FotonCashFlow.FilterPopup === 'undefined') {
        console.error("[FilterManager] FotonCashFlow.FilterPopup não foi encontrado.");
        return;
    }
    this.currentPopup = new FotonCashFlow.FilterPopup(this, headerElement);
    this.currentPopup.show();
  }

  /**
   * Define ou atualiza um filtro para uma coluna.
   * @param {string} column - O nome da coluna (ex: 'status').
   * @param {object} filterInstance - O objeto de filtro com operador, valor e método 'matches'.
   */
  setFilter(column, filterInstance) {
    this.activeFilters.set(column, filterInstance);
    this.controller.onStateChange(); // Notifica o controller para re-renderizar
  }

  /**
   * Remove um filtro de uma coluna.
   * @param {string} column - O nome da coluna.
   */
  removeFilter(column) {
    this.activeFilters.delete(column);
    this.controller.onStateChange(); // Notifica o controller para re-renderizar
  }

  /**
   * Remove todos os filtros ativos.
   */
  clearAllFilters() {
    this.activeFilters.clear();
    this.controller.onStateChange();
  }

  /**
   * Aplica todos os filtros ativos a um array de linhas.
   * @param {HTMLElement[]} allRows - Todas as linhas <tr> originais.
   * @returns {HTMLElement[]} - As linhas que passam em todos os filtros.
   */
  applyAll(allRows) {
    if (this.activeFilters.size === 0) {
      return allRows;
    }

    return allRows.filter(row => {
      for (const [column, filter] of this.activeFilters.entries()) {
        const rowValue = row.dataset[column];
        if (!filter.matches(rowValue)) {
          return false; // Se uma linha falhar em qualquer filtro, ela é excluída.
        }
      }
      return true; // Se a linha passar em todos os filtros, ela é incluída.
    });
  }
}

window.FotonCashFlow.FilterManager = FilterManager;
