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

    // Verifica se a view principal foi encontrada. Se não, a página não tem o que mostrar.
    if (!this.viewManager.isInitialized()) {
      console.error('CashFlowPageController: ViewManager não pôde ser inicializado. Abortando.');
      return;
    }

    // 2. Adiciona os listeners para ordenação nos cabeçalhos da tabela.
    this._initializeSorters();
    this.filterManager.initialize(); // <-- ADICIONA ESTA LINHA

    // 3. Renderiza o estado inicial da página (com a ordenação padrão).
    this.onStateChange();

    // 4. Inicializa os gráficos com os dados iniciais.
    this.dashboardManager.init();
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
    const dataAttribute = column; // Simplificado para buscar o data-attribute diretamente

    return rows.sort((a, b) => {
      const valA = a.dataset[dataAttribute] || '';
      const valB = b.dataset[dataAttribute] || '';

      // Tenta converter para número para uma ordenação numérica/data correta
      const numA = parseFloat(valA);
      const numB = parseFloat(valB);

      const comparison = isNaN(numA) || isNaN(numB) ? valA.localeCompare(valB) : numA - numB;

      return direction === 'asc' ? comparison : -comparison;
    });
  }
}

// Anexa a classe ao namespace global para que o application.js possa encontrá-la.
window.FotonCashFlow.CashFlowPageController = CashFlowPageController;