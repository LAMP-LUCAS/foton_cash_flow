/**
 * Controlador para a página principal do Fluxo de Caixa.
 *
 * Responsável por inicializar e coordenar todos os "managers" (FilterManager, ViewManager, etc.)
 * que compõem a funcionalidade da página. Ele orquestra o fluxo de dados: quando um filtro
 * é aplicado, ele pega os dados, aplica os filtros e comanda os outros managers para
 * atualizarem suas respectivas partes da UI (tabela, gráficos, etc.).
 */

// Garante que o namespace global exista.
window.FotonCashFlow = window.FotonCashFlow || {};
window.FotonCashFlow.Controllers = window.FotonCashFlow.Controllers || {};

class CashFlowPageController {
  /**
   * @param {HTMLElement} element - O elemento DOM principal da página do fluxo de caixa (ex: .cash-flow-page).
   */
  constructor(element) {
    this.pageElement = element;
    this.sortState = {
      column: 'entry_date', // Coluna padrão para ordenação
      direction: 'desc'     // Direção padrão
    };
    console.log("CashFlowPageController: Instância criada para o elemento:", this.pageElement);
  }

  /**
   * Inicializa todos os componentes e managers da página.
   */
  initialize() {
    console.log("CashFlowPageController: Inicializando componentes da página...");

    // 1. Instancia os managers.
    // O ViewManager precisa do SELETOR da tabela, não do elemento.
    // Os outros managers precisam da instância do CONTROLLER para poderem notificá-lo de mudanças.
    this.viewManager = new FotonCashFlow.ViewManager('.cf-table-wrapper');
    this.filterManager = new FotonCashFlow.FilterManager(this);
    this.dashboardManager = new FotonCashFlow.DashboardManager(this);
    this.chartManager = new FotonCashFlow.Managers.ChartManager(this.pageElement, this.dashboardManager);

    // Verifica se a view principal foi encontrada. Se não, a página não tem o que mostrar.
    if (!this.viewManager.isInitialized()) {
      console.error('CashFlowPageController: ViewManager não pôde ser inicializado. Abortando.');
      return;
    }

    // 2. Adiciona os listeners para ordenação nos cabeçalhos da tabela.
    this._initializeSorters();
    this._initializePillFilters(); // Adiciona listeners de clique nas pílulas da tabela.
    this.viewManager.init(); // Garante que a estilização inicial da view (ex: cores) seja aplicada.
    this.filterManager.initialize();
    this.chartManager.init(); // Inicializa a funcionalidade de maximizar/minimizar.

    // 3. Renderiza o estado inicial da página (com a ordenação padrão).
    this.onStateChange();

    console.log("CashFlowPageController: Inicialização concluída.");
  }

  /**
   * Adiciona os event listeners aos cabeçalhos da tabela para ordenação.
   * @private
   */
  _initializeSorters() {
    const sortIcons = this.viewManager.tableElement.querySelectorAll('.cf-sort-icon');
    sortIcons.forEach(icon => {
      icon.addEventListener('click', (e) => {
        const header = e.target.closest('th');
        this.handleSort(header.dataset.column);
      });
    });
  }

  /**
   * Adiciona um listener de clique ao corpo da tabela para filtrar ao clicar em uma pílula.
   * Usa delegação de eventos para eficiência.
   * @private
   */
  _initializePillFilters() {
    const tableBody = this.viewManager.tableBody;
    if (!tableBody) return;

    tableBody.addEventListener('click', (event) => {
      const pill = event.target.closest('.status-tag, .transaction-tag, .category-tag');
      if (!pill) return;

      event.preventDefault();

      const cell = pill.closest('td[data-column]');
      const row = pill.closest('tr.issue-row');
      if (!cell || !row) return;

      const column = cell.dataset.column;
      const valueToFilter = row.dataset[column];
      const displayValue = pill.innerText.trim();

      if (!column || valueToFilter === undefined) return;

      // Cria uma instância de filtro compatível com o FilterManager
      const filterInstance = {
        operator: 'is',
        value: displayValue, // O que o usuário vê na barra de filtros
        matches: (rowValue) => {
          return rowValue ? rowValue === valueToFilter : false;
        }
      };

      this.filterManager.setFilter(column, filterInstance);
    });
  }

  /**
   * Lida com o clique em um cabeçalho para ordenar a tabela.
   * @param {string} column - O nome da coluna a ser ordenada.
   */
  handleSort(column) {
    if (this.sortState.column === column) {
      // Se já está ordenando por esta coluna, inverte a direção
      this.sortState.direction = this.sortState.direction === 'asc' ? 'desc' : 'asc';
    } else {
      // Se é uma nova coluna, define a ordenação padrão
      this.sortState.column = column;
      this.sortState.direction = 'desc'; // Padrão para novas colunas (ex: data mais recente primeiro)
    }

    // Dispara a re-renderização da página com a nova ordenação
    this.onStateChange();
  }

  /**
   * Chamado pelos managers sempre que o estado da aplicação muda (ex: um filtro é adicionado/removido).
   * Este método re-orquestra a renderização de toda a página.
   */
  onStateChange() {
    console.log("CashFlowPageController: Estado alterado. Re-renderizando a view.");

    // 1. Pega todas as linhas de dados originais que estão no DOM.
    const allRows = this.viewManager.getOriginalRows();

    // 2. Aplica os filtros ativos para obter apenas as linhas visíveis.
    const filteredRows = this.filterManager.applyAll(allRows);

    // 3. Aplica a ordenação sobre as linhas filtradas.
    const sortedRows = this.applySort(filteredRows);

    // 4. Comanda o ViewManager para renderizar a tabela com as linhas filtradas e ordenadas.
    this.viewManager.renderTable(sortedRows);

    // 5. Comanda o DashboardManager para atualizar os gráficos com base nas linhas filtradas (a ordenação não afeta os totais).
    this.dashboardManager.updateCharts(filteredRows);

    // 6. Comanda o ViewManager para renderizar as "pílulas" de filtros ativos.
    //    As funções de callback permitem que a pílula interaja de volta com o FilterManager.
    this.viewManager.renderActiveFilterPills(
      this.filterManager.activeFilters,
      (column) => this.filterManager.removeFilter(column), // O que fazer ao remover
      (header) => this.filterManager.showFilterPopup(header), // O que fazer ao clicar
      () => this.filterManager.clearAllFilters() // O que fazer para limpar tudo
    );

    // 7. Comanda o ViewManager para atualizar os indicadores visuais de ordenação.
    this.viewManager.updateSortIndicators(this.sortState.column, this.sortState.direction);
  }

  /**
   * Ordena um array de elementos <tr> com base no estado de ordenação atual.
   * @param {HTMLElement[]} rows - As linhas a serem ordenadas.
   * @returns {HTMLElement[]} - As linhas ordenadas.
   */
  applySort(rows) {
    const { column, direction } = this.sortState;

    // Busca o tipo de dado do cabeçalho da coluna para uma ordenação mais inteligente.
    const header = this.viewManager.tableElement.querySelector(`th[data-column="${column}"]`);
    const dataType = header ? header.dataset.type : 'string';

    /**
     * Converte uma string de data (seja 'YYYY-MM-DD' ou 'DD/MM/AAAA') para um objeto Date.
     * @param {string} dateString - A string da data.
     * @returns {Date|null} - O objeto Date ou null se for inválida.
     */
    const parseDate = (dateString) => {
      if (!dateString) return null;

      // Verifica o formato DD/MM/AAAA
      const dmyMatch = dateString.match(/^(\d{2})\/(\d{2})\/(\d{4})$/);
      if (dmyMatch) {
        // Rearranja para YYYY-MM-DD para que o construtor do Date funcione de forma confiável.
        const isoDateString = `${dmyMatch[3]}-${dmyMatch[2]}-${dmyMatch[1]}`;
        const date = new Date(isoDateString);
        return isNaN(date) ? null : date;
      }

      // Tenta parsear diretamente (para formatos como YYYY-MM-DD)
      const date = new Date(dateString);
      return isNaN(date) ? null : date;
    };

    return rows.sort((a, b) => {
      const valA = a.dataset[column] || '';
      const valB = b.dataset[column] || '';

      // Trata valores nulos ou vazios, colocando-os no final da ordenação.
      if (!valA && !valB) return 0;
      if (!valA) return 1;
      if (!valB) return -1;

      let comparison = 0;

      switch (dataType) {
        case 'date':
          const dateA = parseDate(valA);
          const dateB = parseDate(valB);
          if (dateA === null && dateB === null) comparison = 0;
          else if (dateA === null) comparison = 1; // Nulos no final
          else if (dateB === null) comparison = -1; // Nulos no final
          else comparison = dateA - dateB;
          break;

        case 'value': // Para a coluna 'Valor'
        case 'number':
          const numA = parseFloat(valA);
          const numB = parseFloat(valB);
          if (isNaN(numA) && isNaN(numB)) comparison = 0;
          else if (isNaN(numA)) comparison = 1; // NaN no final
          else if (isNaN(numB)) comparison = -1; // NaN no final
          else comparison = numA - numB;
          break;

        default: // 'string'
          // localeCompare com a opção 'numeric' lida bem com strings que contêm números.
          comparison = valA.localeCompare(valB, undefined, { numeric: true, sensitivity: 'base' });
          break;
      }

      return direction === 'asc' ? comparison : -comparison;
    });
  }
}

// Anexa a classe ao namespace correto para que o application.js possa encontrá-la.
window.FotonCashFlow.Controllers.CashFlowPageController = CashFlowPageController;