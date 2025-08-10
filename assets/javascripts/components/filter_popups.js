import { StringFilter } from '../filters/string_filter.js';
import { NumberFilter } from '../filters/number_filter.js';
import { MultiSelectFilter } from '../filters/multi_select_filter.js';

/**
 * Gerencia a criação e o ciclo de vida dos popups de filtro.
 */
export class FilterPopup {
    constructor(manager, headerElement) {
        this.manager = manager;
        this.header = headerElement;
        this.column = headerElement.dataset.column;
        this.type = headerElement.dataset.type;
        this.popup = null;
        this.template = document.getElementById('filter-popup-template');
    }

    show() {
        const content = this.template.content.cloneNode(true);
        this.popup = content.querySelector('.cf-filter-popup');
        
        this.configurePopupContent();
        
        document.body.appendChild(this.popup);
        this.positionPopup();
        this.bindEvents();
    }
    
    configurePopupContent() {
        this.popup.querySelectorAll('.cf-filter-group').forEach(group => {
            group.style.display = group.dataset.type.includes(this.type) ? 'block' : 'none';
        });

        // Preenche valores de filtros de seleção (Status, Categoria)
        if (['status', 'category', 'transaction'].includes(this.type)) {
            this.populateSelectOptions();
        }
        
        // Preenche o popup com o filtro ativo, se houver
        const activeFilter = this.manager.activeFilters.get(this.column);
        if (activeFilter) {
            activeFilter.populatePopup(this.popup);
        }
    }

    populateSelectOptions() {
        const container = this.popup.querySelector('.cf-filter-checkbox-container');
        const uniqueValues = new Set();
        this.manager.table.rows.forEach(row => {
            const value = row.dataset[this.column.replace(/_/g, '-')];
            if (value) uniqueValues.add(value);
        });

        container.innerHTML = '';
        Array.from(uniqueValues).sort().forEach(value => {
            const label = document.createElement('label');
            label.className = 'cf-checkbox-label';
            label.innerHTML = `
                <input type="checkbox" class="cf-filter-checkbox" value="${value}">
                <span>${value}</span>
            `;
            container.appendChild(label);
        });
    }

    positionPopup() {
        const rect = this.header.getBoundingClientRect();
        this.popup.style.position = 'absolute';
        this.popup.style.top = `${rect.bottom + window.scrollY + 5}px`;
        this.popup.style.left = `${rect.left + window.scrollX}px`;
        this.popup.style.zIndex = '1010';
    }

    bindEvents() {
        this.popup.querySelector('.cf-apply-filter-btn').addEventListener('click', () => {
            const filter = this.createFilterInstance();
            if (filter) {
                this.manager.setFilter(this.column, filter);
            }
            this.destroy();
        });

        this.popup.querySelector('.cf-clear-filter-btn').addEventListener('click', () => {
            this.manager.removeFilter(this.column);
            this.destroy();
        });
        
        setTimeout(() => document.addEventListener('click', this.handleOutsideClick, { once: true }), 0);
    }
    
    createFilterInstance() {
        const group = this.popup.querySelector(`.cf-filter-group[data-type*="${this.type}"]`);
        const operatorSelect = group.querySelector('.cf-filter-operator');
        const operator = operatorSelect.value;
        const operatorText = operatorSelect.options[operatorSelect.selectedIndex].text;

        switch (this.type) {
            case 'string':
            case 'category':
                const value = group.querySelector('.cf-filter-input').value;
                return new StringFilter(operator, value, operatorText);
            case 'number':
            case 'value':
                const v1 = group.querySelector('input[name="filter_value_1"]').value;
                const v2 = group.querySelector('input[name="filter_value_2"]').value;
                return new NumberFilter(operator, v1, v2, operatorText);
            case 'status':
            case 'transaction':
                const values = Array.from(group.querySelectorAll('.cf-filter-checkbox:checked')).map(cb => cb.value);
                return new MultiSelectFilter('is', values, 'é'); // Simplificado para 'is'
            default:
                return null;
        }
    }

    handleOutsideClick = (e) => {
        if (!this.popup.contains(e.target) && !this.header.contains(e.target)) {
            this.destroy();
        } else {
            // Se o clique foi dentro, re-adiciona o listener
            document.addEventListener('click', this.handleOutsideClick, { once: true });
        }
    }

    destroy() {
        document.removeEventListener('click', this.handleOutsideClick);
        if (this.popup && this.popup.parentNode) {
            this.popup.parentNode.removeChild(this.popup);
        }
        this.manager.currentPopup = null;
    }
}