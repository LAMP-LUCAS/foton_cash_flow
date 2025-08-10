import { FilterManager } from '../managers/filter_manager.js';
import { SortingManager } from '../managers/sorting_manager.js';
import { PaginationManager } from '../managers/pagination_manager.js';
import { ModalManager } from '../managers/modal_manager.js';

/**
 * Gerencia o estado e as interações da tabela de lançamentos.
 * Atua como um orquestrador para os módulos de filtro, ordenação, etc.
 */
export class CashFlowTable {
  constructor(tableElement) {
    this.table = tableElement;
    this.tbody = this.table.querySelector('tbody');
    this.rows = Array.from(this.tbody.querySelectorAll('tr.issue-row'));
    
    // Estado da tabela
    this.visibleRows = [...this.rows];
    this.currentPage = 1;
    this.rowsPerPage = 25;
    this.currentSort = { column: null, direction: 'asc' };

    // Módulos de gerenciamento
    this.filters = new FilterManager(this);
    this.sorting = new SortingManager(this);
    this.pagination = new PaginationManager(this);
    this.modals = new ModalManager(this);

    // Inicia a renderização inicial
    this.renderTable();
  }

  /**
   * O método central que atualiza a visualização da tabela.
   * É chamado sempre que um filtro, ordenação ou página é alterado.
   */
  renderTable() {
    // 1. Aplica os filtros para obter as linhas visíveis
    this.visibleRows = this.filters.applyAll(this.rows);

    // 2. Ordena as linhas filtradas
    this.visibleRows = this.sorting.sortRows(this.visibleRows);

    // 3. Renderiza os controles de paginação com base nos resultados
    this.pagination.render();

    // 4. Obtém apenas as linhas para a página atual
    const paginatedRows = this.pagination.getPaginatedRows(this.visibleRows);

    // 5. Atualiza o DOM da tabela com as linhas corretas
    this.updateTableDOM(paginatedRows);
    
    // 6. Atualiza os indicadores visuais (ícone de ordenação, pílulas de filtro)
    this.sorting.updateSortIndicators();
    this.filters.renderActiveFilterPills();
  }
  
  /**
   * Manipula o DOM para exibir as linhas corretas na tabela.
   * @param {Array<HTMLElement>} rowsToDisplay - As linhas a serem exibidas na página atual.
   */
  updateTableDOM(rowsToDisplay) {
    this.tbody.innerHTML = ''; // Limpa a tabela
    if (rowsToDisplay.length > 0) {
      rowsToDisplay.forEach(row => this.tbody.appendChild(row));
    } else {
      const colCount = this.table.querySelector('thead th').length;
      this.tbody.innerHTML = `<tr><td colspan="${colCount}" class="no-data-message">Nenhum lançamento corresponde aos filtros.</td></tr>`;
    }
  }
}