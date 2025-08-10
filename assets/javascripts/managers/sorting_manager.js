/**
 * Gerencia a lógica de ordenação da tabela.
 */
export class SortingManager {
  constructor(tableInstance) {
    this.table = tableInstance;
    this.init();
  }
  
  init() {
    this.table.table.querySelectorAll('th[data-column]').forEach(header => {
      header.addEventListener('click', (e) => {
        if (!e.target.classList.contains('cf-filter-icon')) {
          this.handleHeaderClick(header);
        }
      });
    });
  }
  
  handleHeaderClick(header) {
    const column = header.dataset.column;
    if (this.table.currentSort.column === column) {
      this.table.currentSort.direction = this.table.currentSort.direction === 'asc' ? 'desc' : 'asc';
    } else {
      this.table.currentSort = { column, direction: 'asc' };
    }
    this.table.renderTable();
  }
  
  sortRows(rows) {
    const { column, direction } = this.table.currentSort;
    if (!column) return rows;

    const header = this.table.table.querySelector(`th[data-column="${column}"]`);
    const dataType = header ? header.dataset.type : 'string';

    return [...rows].sort((a, b) => {
      const aValue = a.dataset[column.replace(/_/g, '-')];
      const bValue = b.dataset[column.replace(/_/g, '-')];
      
      let comparison = 0;
      switch (dataType) {
        case 'number':
        case 'value':
          comparison = parseFloat(aValue || 0) - parseFloat(bValue || 0);
          break;
        case 'date':
          comparison = new Date(aValue) - new Date(bValue);
          break;
        default:
          comparison = (aValue || '').localeCompare(bValue || '', undefined, {numeric: true});
      }
      
      return direction === 'asc' ? comparison : -comparison;
    });
  }
  
  updateSortIndicators() {
    this.table.table.querySelectorAll('th[data-column]').forEach(header => {
      const indicator = header.querySelector('.cf-sort-indicator');
      if (indicator) {
        indicator.className = 'cf-sort-indicator';
        if (header.dataset.column === this.table.currentSort.column) {
          indicator.classList.add(this.table.currentSort.direction);
        }
      }
    });
  }
}