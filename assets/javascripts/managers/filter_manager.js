import { FilterPopup } from '../components/filter_popup.js';

/**
 * Gerencia toda a lógica de filtragem, incluindo a interface (popups e pílulas).
 */
export class FilterManager {
    constructor(tableInstance) {
        this.controller = tableInstance; // Renomeado para clareza
        this.activeFilters = new Map(); // Estrutura: { 'columnName' => filterInstance }
        this.currentPopup = null;

        this.init();
    }

    init() {
        this.controller.viewManager.tableElement.querySelectorAll('th[data-column]').forEach(header => {
            const filterIcon = header.querySelector('.cf-filter-icon');
            if (filterIcon) {
                filterIcon.addEventListener('click', (e) => {
                    e.stopPropagation();
                    this.showFilterPopup(header);
                });
            }
        });
    }

    showFilterPopup(headerElement) {
        if (this.currentPopup) {
            this.currentPopup.destroy();
        }
        this.currentPopup = new FilterPopup(this, headerElement);
        this.currentPopup.show();
    }

    setFilter(column, filterInstance) {
        this.activeFilters.set(column, filterInstance);
        this.controller.onStateChange(); // Notifica o controlador que o estado mudou
    }

    removeFilter(column) {
        this.activeFilters.delete(column);
        if (this.currentPopup && this.currentPopup.column === column) {
            this.currentPopup.destroy(); // Fecha o popup se ele estiver aberto para o filtro removido
        }
        this.controller.onStateChange(); // Notifica o controlador
    }

    applyAll(rows) {
        if (this.activeFilters.size === 0) return rows;

        return rows.filter(row => {
            for (const [column, filter] of this.activeFilters.entries()) {
                const rowValue = row.dataset[column.replace(/_/g, '-')];
                if (!filter.matches(rowValue)) {
                    return false;
                }
            }
            return true;
        });
    }
}