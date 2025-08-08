// plugins/foton_cash_flow/assets/javascripts/cash_flow_main.js

document.addEventListener('DOMContentLoaded', () => {
  // Verifica se estamos na página do fluxo de caixa
  const cashFlowContainer = document.querySelector('.foton-cash-flow, .cash-flow-page');
  if (!cashFlowContainer) {
    return; // Não estamos na página do fluxo de caixa, não inicializar
  }
  
  // Verifica se o template existe
  const template = document.getElementById('filter-modal-template');
  if (!template) {
    console.error('Template do modal de filtros não encontrado');
    return;
  }
  
  // Inicializa o sistema de tabela interativa se a tabela existir
  const tableElement = cashFlowContainer.querySelector('.cf-table-container > .cf-table');
  if (tableElement) {
    new CashFlowTable(tableElement);
  } else {
    console.error('Tabela não encontrada');
  }
});

class CashFlowTable {
   
  constructor(tableElement) {
    this.table = tableElement;
    this.tbody = this.table.querySelector('tbody');
    this.rows = Array.from(this.tbody.querySelectorAll('tr.issue-row'));
    this.visibleRows = [...this.rows];
    this.currentPage = 1;
    this.rowsPerPage = 20;
    this.currentSort = { column: null, direction: 'asc' };
    this.filters = new FilterManager(this);
    this.pagination = new PaginationManager(this);
    this.sorting = new SortingManager(this);
    
    this.init();
  }
  
  init() {
    this.setupColumnHeaders(); // Agora este método existe
    this.filters.init();
    this.pagination.init();
    this.sorting.init();
    this.renderTable();
  }
  
  setupColumnHeaders() {
    const headers = this.table.querySelectorAll('th[data-column]');
    headers.forEach(header => {
      // Adiciona cursor pointer para indicar que é clicável
      header.style.cursor = 'pointer';
      
      // Configura evento de clique para ordenação
      header.addEventListener('click', (e) => {
        // Previne cliques em elementos de filtro dentro do cabeçalho
        if (!e.target.classList.contains('cf-filter-icon')) {
          const column = header.dataset.column;
          this.handleColumnHeaderClick(column, header);
        }
      });
    });
  }
  
  handleColumnHeaderClick(column, headerElement) {
    // Se já estiver ordenando por esta coluna, alterna a direção
    if (this.currentSort.column === column) {
      this.currentSort.direction = this.currentSort.direction === 'asc' ? 'desc' : 'asc';
    } else {
      // Senão, define como nova coluna de ordenação (asc por padrão)
      this.currentSort = { column, direction: 'asc' };
    }
    
    this.renderTable();
  }
  
  renderTable() {
    this.pagination.updateVisibleRows();
    this.pagination.renderPaginationControls();
    this.sorting.updateSortIndicators();
    this.updateRowCountDisplay();
  }
  
  
  updateRowCountDisplay() {
    const countElement = document.querySelector('.cf-entries-count');
    if (countElement) {
      const total = this.rows.length;
      const visible = this.visibleRows.length;
      countElement.textContent = visible === total 
        ? `Exibindo ${visible} lançamentos` 
        : `Exibindo ${visible} de ${total} lançamentos`;
    }
  }
  
  // Métodos auxiliares para manipulação de linhas
  getFilteredRows() {
    return this.filters.applyAll(this.rows);
  }
  
  getSortedRows(rows) {
    return this.sorting.sortRows(rows);
  }
  
  getPaginatedRows(rows) {
    const start = (this.currentPage - 1) * this.rowsPerPage;
    return rows.slice(start, start + this.rowsPerPage);
  }
}

class FilterManager {
  constructor(tableInstance) {
    this.table = tableInstance;
    this.activeFilters = new Map();
    this.currentModal = null;
    this.template = document.getElementById('filter-modal-template');
    
    if (!this.template) {
      console.error('Template do modal de filtros não encontrado');
    }
  }
  
  init() {
    this.setupActiveFiltersContainer();
    this.setupColumnFilters();
  }
  
  setupActiveFiltersContainer() {
    // Cria container para tags de filtros ativos se não existir
    let container = document.querySelector('.cf-active-filters-container');
    if (!container) {
      const filtersBar = document.querySelector('.cf-filters-bar');
      if (filtersBar) {
        container = document.createElement('div');
        container.className = 'cf-active-filters-container';
        container.innerHTML = `
          <div class="cf-active-filters-label">Filtros aplicados:</div>
          <div class="cf-active-filters"></div>
          <button class="cf-clear-all-filters cf-btn cf-btn-outline">Limpar todos</button>
        `;
        filtersBar.appendChild(container);
      }
    }
    this.activeFiltersContainer = container;
    this.bindClearAllButton();
  }
  
  setupColumnFilters() {
    const headers = this.table.table.querySelectorAll('th[data-column]');
    headers.forEach(header => {
      const column = header.dataset.column;
      const filterIcon = header.querySelector('.cf-filter-icon');
      
      if (filterIcon) {
        filterIcon.addEventListener('click', (e) => {
          e.stopPropagation();
          this.showFilterModal(column, header);
        });
      }
    });
  }
  
  showFilterModal(column, headerElement) {
    // Fecha qualquer modal aberto primeiro
    if (this.currentModal) {
      this.currentModal.destroy();
    }
    
    // Cria e mostra o modal de filtro
    const modal = new FilterModal(this, column, headerElement);
    modal.show();
    this.currentModal = modal;
  }
  
  addFilter(column, filter) {
    this.activeFilters.set(column, filter);
    this.updateActiveFiltersDisplay();
    this.table.renderTable();
  }
  
  removeFilter(column) {
    this.activeFilters.delete(column);
    this.updateActiveFiltersDisplay();
    this.table.renderTable();
  }
  
  updateActiveFiltersDisplay() {
    const container = this.activeFiltersContainer?.querySelector('.cf-active-filters');
    if (!container) return;
    
    // Limpa container
    container.innerHTML = '';
    
    // Adiciona tags para cada filtro ativo
    this.activeFilters.forEach((filter, column) => {
      const tag = document.createElement('div');
      tag.className = 'cf-filter-tag';
      tag.dataset.column = column;
      
      const columnHeader = this.table.table.querySelector(`th[data-column="${column}"]`);
      const columnName = columnHeader ? columnHeader.textContent.trim() : column;
      
      tag.innerHTML = `
        <span>${columnName}: ${filter.getDisplayValue()}</span>
        <button class="cf-remove-filter" title="Remover filtro">
          <i class="icon icon-close"></i>
        </button>
      `;
      
      tag.querySelector('.cf-remove-filter').addEventListener('click', () => {
        this.removeFilter(column);
      });
      
      container.appendChild(tag);
    });
  }
  
  bindClearAllButton() {
    const clearAllBtn = this.activeFiltersContainer?.querySelector('.cf-clear-all-filters');
    if (clearAllBtn) {
      clearAllBtn.addEventListener('click', () => {
        this.activeFilters.clear();
        this.updateActiveFiltersDisplay();
        this.table.renderTable();
      });
    }
  }
  
  applyAll(rows) {
    return rows.filter(row => {
      for (const [column, filter] of this.activeFilters) {
        const value = this.getRowValue(row, column);
        if (!filter.matches(value)) {
          return false;
        }
      }
      return true;
    });
  }
  
  getRowValue(row, column) {
    // Converte nome da coluna para o formato data-attribute
    const attrName = column.replace(/_/g, '-');
    return row.dataset[attrName] || '';
  }
}

class FilterModal {
  constructor(filterManager, column, headerElement) {
    this.filterManager = filterManager;
    this.column = column;
    this.headerElement = headerElement;
    this.modal = null;
    this.template = document.getElementById('filter-modal-template');
    
    if (!this.template) {
      console.error('Template do modal de filtros não encontrado');
      return;
    }
  }
  
  show() {
    if (!this.template) {
      console.error('Não é possível mostrar o modal: template não encontrado');
      return;
    }
    
    this.createModal();
    this.positionModal();
    this.bindEvents();
    document.body.appendChild(this.modal);
    document.addEventListener('click', this.handleDocumentClick);
    
    // Foco no primeiro input quando o modal abre
    setTimeout(() => {
      const firstInput = this.modal.querySelector('.cf-filter-input');
      if (firstInput) firstInput.focus();
    }, 100);
  }
  
  createModal() {
    // Clona o template
    const modalContent = this.template.content.cloneNode(true);
    this.modal = document.createElement('div');
    this.modal.className = 'cf-filter-modal-overlay active';
    this.modal.appendChild(modalContent);
    
    // Configura o título
    const titleElement = this.modal.querySelector('.cf-filter-title');
    if (titleElement) {
      titleElement.textContent = this.headerElement.textContent.trim();
    }
    
    // Mostra apenas o grupo de filtro correto
    const dataType = this.headerElement.dataset.type;
    this.modal.querySelectorAll('.cf-filter-group').forEach(group => {
      const types = group.dataset.type.split(' ');
      group.style.display = types.includes(dataType) ? 'block' : 'none';
    });
    
    // Configura valores para filtros de múltipla seleção baseados nos dados da tabela
    if (['status', 'category'].includes(this.column)) {
      this.setupDynamicMultiSelectFilter();
    }
    
    // Configura operadores especiais
    this.setupOperatorHandlers();
  }
  
  setupDynamicMultiSelectFilter() {
    const group = this.modal.querySelector(`.cf-filter-group[data-type="${this.column}"]`);
    if (!group) return;
    
    // Limpa conteúdo existente
    const container = group.querySelector('.cf-filter-checkbox-container');
    if (!container) return;
    container.innerHTML = '';
    
    // Obtém os valores únicos desta coluna dos dados da tabela
    const uniqueValues = new Set();
    this.filterManager.table.rows.forEach(row => {
      const value = this.filterManager.getRowValue(row, this.column);
      if (value) uniqueValues.add(value);
    });
    
    // Ordena os valores alfabeticamente
    const sortedValues = Array.from(uniqueValues).sort();
    
    // Cria checkboxes para cada valor
    sortedValues.forEach(value => {
      const label = document.createElement('label');
      label.className = 'cf-checkbox-label';
      label.innerHTML = `
        <input type="checkbox" class="cf-filter-checkbox" value="${this.escapeHtml(value)}">
        <span>${this.escapeHtml(value)}</span>
      `;
      container.appendChild(label);
    });
  }
  
  setupOperatorHandlers() {
    const operatorSelect = this.modal.querySelector('.cf-filter-operator');
    if (operatorSelect) {
      operatorSelect.addEventListener('change', (e) => this.handleOperatorChange(e.target.value));
      // Inicializa o estado com base no operador padrão
      this.handleOperatorChange(operatorSelect.value);
    }
  }
  
  handleOperatorChange(operator) {
    const isBetween = operator === 'between';
    const isEmptyOp = operator === 'is_empty' || operator === 'is_not_empty';
    
    // Mostra/esconde campos de input
    this.modal.querySelectorAll('.cf-filter-input').forEach(field => {
      field.style.display = isEmptyOp ? 'none' : 'block';
    });
    
    this.modal.querySelectorAll('.between-field').forEach(field => {
      field.style.display = isBetween && !isEmptyOp ? 'block' : 'none';
    });
    
    this.modal.querySelectorAll('.cf-filter-and').forEach(label => {
      label.style.display = isBetween && !isEmptyOp ? 'inline' : 'none';
    });
    
    // Mostra/esconde container de checkboxes para operadores de seleção
    const checkboxContainer = this.modal.querySelector('.cf-filter-checkbox-container');
    if (checkboxContainer) {
      checkboxContainer.style.display = 
        (operator === 'is' || operator === 'is_not') ? 'block' : 'none';
    }
  }
  
  escapeHtml(text) {
    const map = {
      '&': '&amp;',
      '<': '<',
      '>': '>',
      '"': '&quot;',
      "'": '&#039;'
    };
    return text.replace(/[&<>"']/g, m => map[m]);
  }
  
  positionModal() {
    const headerRect = this.headerElement.getBoundingClientRect();
    const modalElement = this.modal.querySelector('.cf-filter-modal');
    
    // Calcula posição preferencial
    let top = headerRect.bottom + window.scrollY + 5;
    let left = headerRect.left + window.scrollX;
    
    // Ajusta posição se sair da tela
    const modalRect = modalElement.getBoundingClientRect();
    
    if (top + modalRect.height > window.scrollY + window.innerHeight) {
      top = headerRect.top + window.scrollY - modalRect.height - 5;
    }
    
    if (left + modalRect.width > window.scrollX + window.innerWidth) {
      left = window.innerWidth - modalRect.width - 20;
    }
    
    // Garante que não saia da tela
    top = Math.max(window.scrollY + 10, top);
    left = Math.max(window.scrollX + 10, left);
    
    modalElement.style.position = 'absolute';
    modalElement.style.top = `${top}px`;
    modalElement.style.left = `${left}px`;
    modalElement.style.zIndex = '10000';
  }
  
  bindEvents() {
    // Botão fechar
    this.modal.querySelector('.cf-close-modal-btn').addEventListener('click', () => this.hide());
    
    // Botão aplicar
    this.modal.querySelector('.cf-apply-filter-btn').addEventListener('click', () => this.applyFilter());
    
    // Botão limpar
    this.modal.querySelector('.cf-clear-filter-btn').addEventListener('click', () => this.clearFilter());
    
    // Fechar com ESC
    this.modal.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') this.hide();
    });
  }
  
  applyFilter() {
    const filter = this.createFilter();
    if (filter && filter.isValid()) {
      this.filterManager.addFilter(this.column, filter);
    }
    this.hide();
  }
  
  clearFilter() {
    this.filterManager.removeFilter(this.column);
    this.hide();
  }
  
  createFilter() {
    const dataType = this.headerElement.dataset.type;
    const operatorSelect = this.modal.querySelector('.cf-filter-operator');
    const operator = operatorSelect ? operatorSelect.value : 'contains';
    
    // Trata operadores especiais
    if (operator === 'is_empty' || operator === 'is_not_empty') {
      return new EmptyFilter(operator);
    }
    
    switch (dataType) {
      case 'string':
      case 'category':
        const input = this.modal.querySelector('.cf-filter-input');
        return new StringFilter(operator, input.value);
      
      case 'number':
      case 'value':
        const value1 = this.modal.querySelector('input[name="filter_value_1"]').value;
        const value2 = this.modal.querySelector('input[name="filter_value_2"]')?.value;
        return new NumberFilter(operator, value1, value2);
      
      case 'date':
        const date1 = this.modal.querySelector('input[name="filter_date_1"]').value;
        const date2 = this.modal.querySelector('input[name="filter_date_2"]')?.value;
        return new DateFilter(operator, date1, date2);
      
      case 'status':
      case 'transaction':
        const checkedValues = Array.from(
          this.modal.querySelectorAll('.cf-filter-checkbox:checked')
        ).map(cb => cb.value);
        return new MultiSelectFilter(operator, checkedValues);
      
      default:
        return null;
    }
  }
  
  handleDocumentClick = (e) => {
    if (!this.modal.contains(e.target) && !this.headerElement.contains(e.target)) {
      this.hide();
    }
  }
  
  hide() {
    if (this.modal && this.modal.parentNode) {
      this.modal.parentNode.removeChild(this.modal);
    }
    document.removeEventListener('click', this.handleDocumentClick);
    this.filterManager.currentModal = null;
  }
  
  destroy() {
    this.hide();
  }
}

class StringFilter {
  constructor(operator, value) {
    this.operator = operator;
    this.value = value ? value.toString().toLowerCase() : '';
  }
  
  isValid() {
    // Filtros de texto são válidos mesmo com valor vazio (para operador "contém")
    return ['contains', 'starts_with', 'ends_with', 'equal'].includes(this.operator) || this.value.trim().length > 0;
  }
  
  matches(rowValue) {
    if (this.operator === 'is_empty') {
      return !rowValue || rowValue.toString().trim() === '';
    }
    
    if (this.operator === 'is_not_empty') {
      return rowValue && rowValue.toString().trim() !== '';
    }
    
    if (!rowValue) return false;
    const lowerRowValue = rowValue.toString().toLowerCase();
    
    switch (this.operator) {
      case 'contains':
        return lowerRowValue.includes(this.value);
      case 'starts_with':
        return lowerRowValue.startsWith(this.value);
      case 'ends_with':
        return lowerRowValue.endsWith(this.value);
      case 'equal':
        return lowerRowValue === this.value;
      default:
        return false;
    }
  }
  
  getDisplayValue() {
    if (this.operator === 'is_empty') return '(vazio)';
    if (this.operator === 'is_not_empty') return '(não vazio)';
    return `"${this.value}"`;
  }
}

class NumberFilter {
  constructor(operator, value1, value2) {
    this.operator = operator;
    this.value1 = value1 !== '' && value1 !== null ? parseFloat(value1) : null;
    this.value2 = value2 !== '' && value2 !== null ? parseFloat(value2) : null;
  }
  
  isValid() {
    if (this.operator === 'is_empty' || this.operator === 'is_not_empty') {
      return true;
    }
    
    if (this.operator === 'between') {
      return this.value1 !== null && this.value2 !== null && !isNaN(this.value1) && !isNaN(this.value2);
    }
    
    return this.value1 !== null && !isNaN(this.value1);
  }
  
  matches(rowValue) {
    if (this.operator === 'is_empty') {
      return rowValue === null || rowValue === '' || isNaN(parseFloat(rowValue));
    }
    
    if (this.operator === 'is_not_empty') {
      return rowValue !== null && rowValue !== '' && !isNaN(parseFloat(rowValue));
    }
    
    if (rowValue === null || rowValue === '' || isNaN(parseFloat(rowValue))) return false;
    const numValue = parseFloat(rowValue);
    
    switch (this.operator) {
      case 'equal':
        return numValue === this.value1;
      case 'greater_than':
        return numValue > this.value1;
      case 'less_than':
        return numValue < this.value1;
      case 'between':
        return numValue >= this.value1 && numValue <= this.value2;
      default:
        return false;
    }
  }
  
  getDisplayValue() {
    if (this.operator === 'is_empty') return '(vazio)';
    if (this.operator === 'is_not_empty') return '(não vazio)';
    if (this.operator === 'between') {
      return `${this.value1} - ${this.value2}`;
    }
    return `${this.operator}: ${this.value1}`;
  }
}

class DateFilter {
  constructor(operator, date1, date2) {
    this.operator = operator;
    this.date1 = date1 ? new Date(date1) : null;
    this.date2 = date2 ? new Date(date2) : null;
  }
  
  isValid() {
    if (this.operator === 'is_empty' || this.operator === 'is_not_empty') {
      return true;
    }
    
    if (this.operator === 'between') {
      return this.date1 instanceof Date && !isNaN(this.date1) && 
             this.date2 instanceof Date && !isNaN(this.date2);
    }
    
    return this.date1 instanceof Date && !isNaN(this.date1);
  }
  
  matches(rowValue) {
    if (this.operator === 'is_empty') {
      return !rowValue || rowValue === '';
    }
    
    if (this.operator === 'is_not_empty') {
      return rowValue && rowValue !== '';
    }
    
    if (!rowValue) return false;
    const dateValue = new Date(rowValue);
    if (isNaN(dateValue)) return false;
    
    switch (this.operator) {
      case 'equal':
        return this.isSameDay(dateValue, this.date1);
      case 'before':
        return dateValue < this.date1;
      case 'after':
        return dateValue > this.date1;
      case 'between':
        return dateValue >= this.date1 && dateValue <= this.date2;
      default:
        return false;
    }
  }
  
  isSameDay(date1, date2) {
    return date1.getFullYear() === date2.getFullYear() &&
           date1.getMonth() === date2.getMonth() &&
           date1.getDate() === date2.getDate();
  }
  
  getDisplayValue() {
    if (this.operator === 'is_empty') return '(vazio)';
    if (this.operator === 'is_not_empty') return '(não vazio)';
    if (this.operator === 'between') {
      return `${this.formatDate(this.date1)} - ${this.formatDate(this.date2)}`;
    }
    return `${this.operator}: ${this.formatDate(this.date1)}`;
  }
  
  formatDate(date) {
    return date ? date.toLocaleDateString() : '';
  }
}

class MultiSelectFilter {
  constructor(operator, values) {
    this.operator = operator;
    this.values = values || [];
  }
  
  isValid() {
    if (this.operator === 'is_empty' || this.operator === 'is_not_empty') {
      return true;
    }
    
    return this.values.length > 0;
  }
  
  matches(rowValue) {
    if (this.operator === 'is_empty') {
      return !rowValue || rowValue.toString().trim() === '';
    }
    
    if (this.operator === 'is_not_empty') {
      return rowValue && rowValue.toString().trim() !== '';
    }
    
    if (!rowValue) return false;
    
    switch (this.operator) {
      case 'is':
        return this.values.includes(rowValue.toString());
      case 'is_not':
        return !this.values.includes(rowValue.toString());
      case 'contains':
        return this.values.some(val => rowValue.toString().includes(val));
      default:
        return false;
    }
  }
  
  getDisplayValue() {
    if (this.operator === 'is_empty') return '(vazio)';
    if (this.operator === 'is_not_empty') return '(não vazio)';
    return this.values.join(', ');
  }
}

class EmptyFilter {
  constructor(operator) {
    this.operator = operator;
  }
  
  isValid() {
    return ['is_empty', 'is_not_empty'].includes(this.operator);
  }
  
  matches(rowValue) {
    const isEmpty = !rowValue || rowValue.toString().trim() === '';
    
    switch (this.operator) {
      case 'is_empty':
        return isEmpty;
      case 'is_not_empty':
        return !isEmpty;
      default:
        return false;
    }
  }
  
  getDisplayValue() {
    return this.operator === 'is_empty' ? '(vazio)' : '(não vazio)';
  }
}

class SortingManager {
  constructor(tableInstance) {
    this.table = tableInstance;
  }
  
  init() {
    const headers = this.table.table.querySelectorAll('th[data-column]');
    headers.forEach(header => {
      header.style.cursor = 'pointer';
      // Adiciona o indicador de ordenação se não existir
      if (!header.querySelector('.cf-sort-indicator')) {
        const indicator = document.createElement('span');
        indicator.className = 'cf-sort-indicator';
        header.appendChild(indicator);
      }
      header.addEventListener('click', () => this.handleHeaderClick(header));
    });
  }
  
  handleHeaderClick(header) {
    const column = header.dataset.column;
    
    // Se já estiver ordenando por esta coluna, inverte a direção
    if (this.table.currentSort.column === column) {
      this.table.currentSort.direction = 
        this.table.currentSort.direction === 'asc' ? 'desc' : 'asc';
    } else {
      // Senão, define como nova coluna de ordenação (asc por padrão)
      this.table.currentSort = { column, direction: 'asc' };
    }
    
    this.table.renderTable();
  }
  
  sortRows(rows) {
    if (!this.table.currentSort.column) return rows;
    
    const { column, direction } = this.table.currentSort;
    const attrName = column.replace(/_/g, '-');
    
    return [...rows].sort((a, b) => {
      const aValue = a.dataset[attrName] || '';
      const bValue = b.dataset[attrName] || '';
      
      // Lógica de comparação baseada no tipo de dado
      const header = this.table.table.querySelector(`th[data-column="${column}"]`);
      const dataType = header ? header.dataset.type : 'string';
      
      let comparison = 0;
      
      switch (dataType) {
        case 'number':
        case 'value':
          comparison = parseFloat(aValue) - parseFloat(bValue);
          break;
        case 'date':
          comparison = new Date(aValue) - new Date(bValue);
          break;
        default:
          comparison = aValue.localeCompare(bValue);
      }
      
      return direction === 'asc' ? comparison : -comparison;
    });
  }
  
  updateSortIndicators() {
    // Resetar todos os indicadores
    const allHeaders = this.table.table.querySelectorAll('th[data-column]');
    allHeaders.forEach(header => {
      const indicator = header.querySelector('.cf-sort-indicator');
      if (indicator) {
        indicator.className = 'cf-sort-indicator';
      }
    });
    
    // Atualizar o indicador da coluna ordenada
    if (this.table.currentSort.column) {
      const activeHeader = this.table.table.querySelector(`th[data-column="${this.table.currentSort.column}"]`);
      if (activeHeader) {
        const indicator = activeHeader.querySelector('.cf-sort-indicator');
        if (indicator) {
          indicator.className = `cf-sort-indicator ${this.table.currentSort.direction}`;
        }
      }
    }
  }
}

class PaginationManager {
  constructor(tableInstance) {
    this.table = tableInstance;
    this.paginationContainer = null;
  }
  
  init() {
    this.createPaginationContainer();
    this.updateVisibleRows();
  }
  
  createPaginationContainer() {
    // Verifica se já existe um container de paginação
    this.paginationContainer = document.querySelector('.cf-pagination-container');
    
    if (!this.paginationContainer) {
      // Cria container se não existir
      this.paginationContainer = document.createElement('div');
      this.paginationContainer.className = 'cf-pagination-container';
      
      // Adiciona antes da tabela ou depois, dependendo do layout
      const tableContainer = this.table.table.closest('.cf-table-container');
      if (tableContainer) {
        tableContainer.appendChild(this.paginationContainer);
      }
    }
    
    this.renderPaginationControls();
  }
  
  renderPaginationControls() {
    const totalPages = this.getTotalPages();
    
    if (totalPages <= 1) {
      this.paginationContainer.innerHTML = '';
      return;
    }
    
    let paginationHTML = `
      <div class="cf-pagination">
        <button class="cf-pagination-btn prev ${this.table.currentPage <= 1 ? 'disabled' : ''}">
          <i class="icon icon-prev"></i> Anterior
        </button>
        <div class="cf-pagination-pages">
    `;
    
    // Mostra até 5 páginas com elipses conforme necessário
    const maxPagesToShow = 5;
    let startPage = Math.max(1, this.table.currentPage - Math.floor(maxPagesToShow / 2));
    let endPage = Math.min(totalPages, startPage + maxPagesToShow - 1);
    
    if (endPage - startPage + 1 < maxPagesToShow) {
      startPage = Math.max(1, endPage - maxPagesToShow + 1);
    }
    
    // Botão para primeira página com elipse
    if (startPage > 1) {
      paginationHTML += `<button class="cf-pagination-page" data-page="1">1</button>`;
      if (startPage > 2) {
        paginationHTML += `<span class="cf-pagination-ellipsis">...</span>`;
      }
    }
    
    // Páginas intermediárias
    for (let page = startPage; page <= endPage; page++) {
      paginationHTML += `<button class="cf-pagination-page ${page === this.table.currentPage ? 'active' : ''}" data-page="${page}">${page}</button>`;
    }
    
    // Botão para última página com elipse
    if (endPage < totalPages) {
      if (endPage < totalPages - 1) {
        paginationHTML += `<span class="cf-pagination-ellipsis">...</span>`;
      }
      paginationHTML += `<button class="cf-pagination-page" data-page="${totalPages}">${totalPages}</button>`;
    }
    
    paginationHTML += `
        </div>
        <button class="cf-pagination-btn next ${this.table.currentPage >= totalPages ? 'disabled' : ''}">
          Próxima <i class="icon icon-next"></i>
        </button>
      </div>
    `;
    
    this.paginationContainer.innerHTML = paginationHTML;
    this.bindPaginationEvents();
  }
  
  bindPaginationEvents() {
    // Botão anterior
    this.paginationContainer.querySelector('.prev:not(.disabled)')?.addEventListener('click', () => {
      if (this.table.currentPage > 1) {
        this.table.currentPage--;
        this.table.renderTable();
      }
    });
    
    // Botão próximo
    this.paginationContainer.querySelector('.next:not(.disabled)')?.addEventListener('click', () => {
      if (this.table.currentPage < this.getTotalPages()) {
        this.table.currentPage++;
        this.table.renderTable();
      }
    });
    
    // Botões de página
    this.paginationContainer.querySelectorAll('.cf-pagination-page').forEach(button => {
      button.addEventListener('click', () => {
        this.table.currentPage = parseInt(button.dataset.page);
        this.table.renderTable();
      });
    });
  }
  
  getTotalPages() {
    const totalRows = this.table.visibleRows.length;
    return Math.ceil(totalRows / this.table.rowsPerPage);
  }
  
  updateVisibleRows() {
    // Primeiro aplica todos os filtros
    let filteredRows = this.table.filters.applyAll(this.table.rows);
    
    // Depois ordena
    filteredRows = this.table.sorting.sortRows(filteredRows);
    
    // Atualiza o total de linhas visíveis
    this.table.visibleRows = filteredRows;
    
    // Aplica paginação
    const paginatedRows = this.getPaginatedRows(filteredRows);
    
    // Atualiza a tabela
    this.updateTableRows(paginatedRows);
  }
  
  getPaginatedRows(rows) {
    const start = (this.table.currentPage - 1) * this.table.rowsPerPage;
    return rows.slice(start, start + this.table.rowsPerPage);
  }
  
  updateTableRows(rows) {
    // Limpa o tbody
    this.table.tbody.innerHTML = '';
    
    // Adiciona as linhas paginadas
    if (rows.length > 0) {
      rows.forEach(row => this.table.tbody.appendChild(row));
    } else {
      // Mensagem quando não há resultados
      const noDataRow = document.createElement('tr');
      noDataRow.className = 'no-data-row';
      noDataRow.innerHTML = `
        <td colspan="${this.table.table.querySelectorAll('th').length}" class="no-data-message">
          Nenhum lançamento corresponde aos filtros aplicados
        </td>
      `;
      this.table.tbody.appendChild(noDataRow);
    }
  }
}