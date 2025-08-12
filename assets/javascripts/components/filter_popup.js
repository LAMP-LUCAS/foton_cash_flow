// Garante que o namespace global exista.
window.FotonCashFlow = window.FotonCashFlow || {};

/**
 * Representa o popup de filtro que aparece ao clicar no ícone de uma coluna.
 * Esta é uma implementação básica para demonstrar a arquitetura.
 */
class FilterPopup {
  constructor(filterManager, headerElement) {
    this.filterManager = filterManager;
    this.headerElement = headerElement;
    this.column = headerElement.dataset.column;
    this.columnType = headerElement.dataset.type;
    this.popupElement = null;

    this.handleDocumentClick = this.handleDocumentClick.bind(this);
    this.handleApply = this.handleApply.bind(this);
  }

  /**
   * Cria o HTML do popup e o exibe na posição correta.
   */
  show() {
    console.log('[FilterPopup] show() called.');
    const template = document.getElementById('filter-popup-template');
    if (!template) {
      console.error('[FilterPopup] Template #filter-popup-template not found!');
      return;
    }
    console.log('[FilterPopup] Template found.');

    // Clona o conteúdo do template para criar o popup
    this.popupElement = template.content.cloneNode(true).firstElementChild;
    console.log('[FilterPopup] Popup element cloned:', this.popupElement);

    document.body.appendChild(this.popupElement);
    console.log('[FilterPopup] Popup appended to body.');

    // Configura o conteúdo dinâmico do popup
    this._setupPopupContent();
    console.log('[FilterPopup] Popup content configured.');

    // Posiciona o popup
    const headerRect = this.headerElement.getBoundingClientRect();
    this.popupElement.style.top = `${headerRect.bottom + window.scrollY}px`;
    this.popupElement.style.left = `${headerRect.left + window.scrollX}px`;
    console.log(`[FilterPopup] Popup positioned at top: ${this.popupElement.style.top}, left: ${this.popupElement.style.left}`);

    // **A CORREÇÃO CRÍTICA:** Torna o elemento visível.
    // O template está oculto por padrão, então a cópia precisa ser exibida.
    this.popupElement.style.display = 'block';
    console.log('[FilterPopup] Popup display set to "block". It should be visible now.');

    // Adiciona listeners
    const applyBtn = this.popupElement.querySelector('.cf-apply-filter-btn');
    if (applyBtn) {
      applyBtn.addEventListener('click', this.handleApply);
    }
    setTimeout(() => document.addEventListener('click', this.handleDocumentClick), 0); // Adiciona listener para fechar ao clicar fora
  }

  /**
   * Configura o conteúdo do popup clonado, como título e o grupo de filtro correto.
   */
  _setupPopupContent() {
    // Define o título do popup (apenas a parte dinâmica)
    const columnNameElement = this.popupElement.querySelector('.cf-popup-column-name');
    const headerText = this.headerElement.querySelector('.column-title').innerText.trim();
    if (columnNameElement) {
      columnNameElement.textContent = headerText;
    }

    // Esconde todos os grupos de filtro
    this.popupElement.querySelectorAll('.cf-filter-group').forEach(group => {
      group.style.display = 'none';
    });

    // Encontra e mostra o grupo de filtro correto para o tipo da coluna
    const groupToShow = this.popupElement.querySelector(`.cf-filter-group[data-type*="${this.columnType}"]`);
    if (groupToShow) {
      groupToShow.style.display = 'block';

      // Se for uma lista, popula com os checkboxes dinamicamente
      if (this.columnType === 'list') {
        this._populateListFilter(groupToShow);
      }
    }
  }

  /**
   * Popula o container de checkboxes para filtros de lista.
   * @param {HTMLElement} filterGroup - O elemento do grupo de filtro.
   */
  _populateListFilter(filterGroup) {
    const container = filterGroup.querySelector('.cf-filter-checkbox-container');
    const noOptionsMsg = filterGroup.querySelector('.cf-filter-no-options');
    const uniqueValues = this._getUniqueValuesForListColumn();

    container.innerHTML = ''; // Limpa o conteúdo

    if (uniqueValues.length === 0) {
      noOptionsMsg.style.display = 'block';
      return;
    }

    noOptionsMsg.style.display = 'none';

    uniqueValues.forEach(value => {
      // Tenta traduzir o valor. Ex: 'Vendas' -> 'foton_cash_flow.cf_options.vendas'
      const translationKey = `foton_cash_flow.cf_options.${value.toString().parameterize().replace(/-/g, '_')}`;
      const translatedValue = this.t(translationKey, { defaultValue: value });
      
      const label = document.createElement('label');
      label.className = 'cf-filter-checklist-item';
      label.innerHTML = `<input type="checkbox" name="list_filter_value" value="${value}"><span>${translatedValue}</span>`;
      container.appendChild(label);
    });
  }

  /** Extrai valores únicos de uma coluna do tipo 'list' da tabela */
  _getUniqueValuesForListColumn() {
    const viewManager = this.filterManager.controller.viewManager;
    if (!viewManager) return [];

    // O nome do atributo de dados é o nome da coluna em camelCase.
    // Ex: 'transaction-type' no HTML -> 'transactionType' no dataset
    const dataAttribute = this.column.replace(/-([a-z])/g, g => g[1].toUpperCase());
    const allRows = viewManager.getOriginalRows();
    const values = new Set();

    allRows.forEach(row => {
      const value = row.dataset[dataAttribute];
      if (value) {
        values.add(value);
      }
    });

    return Array.from(values).sort();
  }

  /**
   * Lida com o clique no botão "Aplicar".
   */
  handleApply() {
    switch (this.columnType) {
      case 'date':
        this._applyDateFilter();
        break;
      case 'list':
        this._applyListFilter();
        break;
      case 'string':
      default:
        this._applyStringFilter();
        break;
    }
    this.destroy();
  }

  _applyStringFilter() {
    const operator = this.popupElement.querySelector('.cf-filter-operator').value;
    const value = this.popupElement.querySelector('.cf-filter-input').value;

    if (value || ['is_empty', 'is_not_empty'].includes(operator)) {
      const filterInstance = {
        operator: operator,
        value: value,
        matches: (rowValue) => {
          const hasValue = rowValue !== null && rowValue !== undefined && rowValue !== '';
          if (operator === 'is_empty') return !hasValue;
          if (operator === 'is_not_empty') return hasValue;
          if (!hasValue) return false;

          const lowerRowValue = rowValue.toLowerCase();
          const lowerFilterValue = value.toLowerCase();
          switch (operator) {
            case 'is': return lowerRowValue === lowerFilterValue;
            case 'is_not': return lowerRowValue !== lowerFilterValue;
            case 'contains': return lowerRowValue.includes(lowerFilterValue);
            case 'not_contains': return !lowerRowValue.includes(lowerFilterValue);
            default: return false;
          }
        }
      };
      this.filterManager.setFilter(this.column, filterInstance);
    } else {
      this.filterManager.removeFilter(this.column);
    }
  }

  _applyDateFilter() {
    const startDate = this.popupElement.querySelector('.cf-filter-value-start').value;
    const endDate = this.popupElement.querySelector('.cf-filter-value-end').value;

    if (startDate || endDate) {
      const filterInstance = {
        operator: 'between',
        value: `${startDate || '...'} - ${endDate || '...'}`,
        matches: (rowValue) => {
          if (!rowValue) return false; // YYYY-MM-DD format
          const afterStart = startDate ? rowValue >= startDate : true;
          const beforeEnd = endDate ? rowValue <= endDate : true;
          return afterStart && beforeEnd;
        }
      };
      this.filterManager.setFilter(this.column, filterInstance);
    } else {
      this.filterManager.removeFilter(this.column);
    }
  }

  _applyListFilter() {
    const checkedBoxes = this.popupElement.querySelectorAll('input[name="list_filter_value"]:checked');
    const selectedValues = Array.from(checkedBoxes).map(cb => cb.value);

    if (selectedValues.length > 0) {
      const filterInstance = {
        operator: 'is',
        value: selectedValues.join(', '),
        matches: (rowValue) => {
          return rowValue ? selectedValues.includes(rowValue) : false;
        }
      };
      this.filterManager.setFilter(this.column, filterInstance);
    } else {
      this.filterManager.removeFilter(this.column);
    }
  }

  /**
   * Fecha e remove o popup se o clique for fora dele.
   */
  handleDocumentClick(event) {
    if (this.popupElement && !this.popupElement.contains(event.target) && !this.headerElement.contains(event.target)) {
      this.destroy();
    }
  }

  /**
   * Remove o popup do DOM e limpa os listeners.
   */
  destroy() {
    if (this.popupElement) {
      document.removeEventListener('click', this.handleDocumentClick);
      this.popupElement.remove();
      this.popupElement = null;
      this.filterManager.currentPopup = null;
    }
  }

  /**
   * Wrapper seguro para o I18n do Redmine para evitar race conditions.
   * @param {string} key - A chave de tradução.
   * @param {object} options - Opções para a tradução (ex: defaultValue).
   */
  t(key, options = {}) {
    if (typeof I18n !== 'undefined' && I18n.t) {
      return I18n.t(key, options);
    }
    return options.defaultValue || key;
  }
}

// Adiciona um polyfill simples para parameterize se não existir
if (!String.prototype.parameterize) {
  String.prototype.parameterize = function() {
    return this.trim().toLowerCase().replace(/[^a-z0-9 -]/g, '').replace(/\s+/g, '-').replace(/-+/g, '-');
  };
}

window.FotonCashFlow.FilterPopup = FilterPopup;