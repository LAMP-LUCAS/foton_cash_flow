// Garante que o namespace global exista.
window.FotonCashFlow = window.FotonCashFlow || {};
window.FotonCashFlow.Managers = window.FotonCashFlow.Managers || {};

/**
 * Gerencia a inicialização e interatividade de todos os gráficos na página de fluxo de caixa.
 */
class ChartManager {
  /**
   * @param {HTMLElement} container - O elemento DOM que contém os gráficos.
   * @param {DashboardManager} dashboardManager - A instância do manager que controla os gráficos.
   */
  constructor(container, dashboardManager) {
    this.container = container;
    this.backdrop = null;
    this.dashboardManager = dashboardManager;
    this.closeMaximizedChart = this.closeMaximizedChart.bind(this); // Bind para uso em event listeners
  }

  /**
   * Ponto de entrada principal. Encontra todos os gráficos e configura suas funcionalidades.
   */
  init() {
    console.log('[ChartManager] Initializing maximize/minimize functionality...');
    this._setupMaximizeFunctionality();
    console.log('[ChartManager] Maximize/minimize functionality initialized.');
  }

  // ==========================================================================
  // 1. FUNCIONALIDADE DE MAXIMIZAR/MINIMIZAR
  // ==========================================================================

  /**
   * Configura os listeners e elementos para a funcionalidade de maximizar/minimizar.
   */
  _setupMaximizeFunctionality() {
    this._createBackdrop();
    const chartCards = this.container.querySelectorAll('.cf-chart-card');

    chartCards.forEach(card => {
      // Se os botões já existem, não faz nada.
      if (card.querySelector('.cf-chart-actions')) return;

      // 1. Cria o contêiner para os botões de ação.
      const actionsContainer = document.createElement('div');
      actionsContainer.className = 'cf-chart-actions';

      // 2. Cria o botão de maximizar.
      const maximizeBtn = document.createElement('button');
      maximizeBtn.className = 'cf-chart-maximize-btn icon icon-maximize';
      maximizeBtn.setAttribute('aria-label', 'Maximizar gráfico');

      // 3. Cria o botão de fechar.
      const closeBtn = document.createElement('button');
      closeBtn.className = 'cf-chart-close-btn icon icon-close';
      closeBtn.setAttribute('aria-label', 'Fechar gráfico');

      // 4. Adiciona os botões ao contêiner e o contêiner ao card.
      actionsContainer.appendChild(maximizeBtn);
      actionsContainer.appendChild(closeBtn);
      card.appendChild(actionsContainer);

      // 5. Usa delegação de eventos no contêiner para lidar com os cliques.
      actionsContainer.addEventListener('click', (e) => {
        const targetMaximize = e.target.closest('.cf-chart-maximize-btn');
        const targetClose = e.target.closest('.cf-chart-close-btn');

        if (targetMaximize) {
          this._maximizeChart(card);
        } else if (targetClose) {
          this.closeMaximizedChart();
        }
      });
    });
  }

  _createBackdrop() {
    this.backdrop = document.querySelector('.cf-chart-backdrop');
    if (!this.backdrop) {
      this.backdrop = document.createElement('div');
      this.backdrop.className = 'cf-chart-backdrop';
      document.body.appendChild(this.backdrop);
    }
    this.backdrop.removeEventListener('click', this.closeMaximizedChart);
    this.backdrop.addEventListener('click', this.closeMaximizedChart);
  }

  _maximizeChart(card) {
    this.closeMaximizedChart();
    card.classList.add('is-transitioning'); // Desativa aspect-ratio ANTES da animação começar
    card.classList.add('maximized');
    this.backdrop.classList.add('show');
    document.body.classList.add('cf-modal-open');

    const canvas = card.querySelector('canvas');
    if (!canvas) return;
    const canvasId = canvas.id;

    // 1. Destruir o gráfico ANTES da animação começar.
    this.dashboardManager.destroyChart(canvasId);

    // Após a animação de maximização, removemos a classe de transição
    // e redimensionamos o gráfico para preencher o novo espaço.
    card.addEventListener('transitionend', () => {
      card.classList.remove('is-transitioning');
      // 2. Recriar o gráfico DEPOIS que a animação terminou.
      this.dashboardManager.recreateChart(canvasId);
    }, { once: true });
  }

  closeMaximizedChart() {
    const maximizedCard = document.querySelector('.cf-chart-card.maximized');
    if (maximizedCard) {
      const canvasId = maximizedCard.querySelector('canvas').id;

      maximizedCard.classList.add('is-transitioning'); // Desativa aspect-ratio ANTES da animação

      // 1. Destruir o gráfico ANTES da animação de minimização.
      this.dashboardManager.destroyChart(canvasId);

      // Após a animação de minimização terminar...
      maximizedCard.addEventListener('transitionend', () => {
        // 2. Removemos a classe de controle, reativando o aspect-ratio para o ajuste final.
        maximizedCard.classList.remove('is-transitioning');

        // 3. Recriamos o gráfico no seu container agora estável e de tamanho correto.
        this.dashboardManager.recreateChart(canvasId);
      }, { once: true });

      // Inicia a transição de minimização.
      maximizedCard.classList.remove('maximized');
    }

    if (this.backdrop) {
      this.backdrop.classList.remove('show');
    }
    document.body.classList.remove('cf-modal-open');
  }
}

window.FotonCashFlow.Managers.ChartManager = ChartManager;
