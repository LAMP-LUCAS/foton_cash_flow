// Garante que o namespace global exista.
window.FotonCashFlow = window.FotonCashFlow || {};

/**
 * Gerencia a renderização e atualização dos gráficos do dashboard.
 */
class DashboardManager {
  constructor(controller) {
    this.controller = controller;
    this.charts = {}; // Armazena as instâncias dos gráficos
    this.lastData = null; // Armazena os últimos dados processados para recriação

    this.colors = this.getCssColors();
  }

  init() {
    if (typeof Chart === 'undefined') {
      console.error("[DashboardManager] Chart.js não foi encontrado. Verifique o carregamento da biblioteca.");
      return;
    }
    console.log("[DashboardManager] Inicializando gráficos com dados da página.");
    // Pega as linhas originais da tabela para a renderização inicial
    const initialRows = this.controller.viewManager.getOriginalRows();
    this.updateCharts(initialRows);
  }

  /**
   * Atualiza todos os gráficos com base nas linhas visíveis na tabela.
   * @param {HTMLElement[]} visibleRows - As linhas <tr> que estão sendo exibidas.
   */
  updateCharts(visibleRows) {
    console.log(`[DashboardManager] Atualizando gráficos com ${visibleRows.length} linhas.`);

    // Destrói gráficos antigos para evitar memory leaks e problemas de renderização
    Object.values(this.charts).forEach(chart => chart.destroy());
    this.charts = {};

    // Extrai os dados das linhas visíveis
    const data = this.extractDataFromRows(visibleRows);

    // ATUALIZAÇÃO: Primeiro atualiza os cards do sumário
    this.updateSummaryCards(data.totals);

    // Armazena os dados para poder recriar gráficos individualmente mais tarde
    this.lastData = data;

    // Renderiza os gráficos com os novos dados
    // (Passamos 'data' em vez de 'data.chartData' para manter a estrutura)
    this.renderRevenueExpenseChart(data);
    this.renderExpenseByCategoryChart(data);
    this.renderCumulativeBalanceChart(data);
    this.renderCumulativeFlowChart(data);
  }

  /**
   * Extrai e processa os dados das linhas do DOM para os gráficos.
   * @param {HTMLElement[]} rows - As linhas da tabela.
   * @returns {object} - Um objeto com os dados processados.
   */
  extractDataFromRows(rows) {
    const revenueByMonth = {};
    const expenseByMonth = {};
    const expenseByCategory = {};
    let totalRevenue = 0;
    let totalExpense = 0;
    const transactions = [];

    const uncategorizedLabel = this.t('foton_cash_flow.general.uncategorized');

    rows.forEach(row => {
      const transactionType = row.dataset.transactionType;
      const amount = parseFloat(row.dataset.amount) || 0;
      const date = new Date(row.dataset.entryDate);
      // O nome original é usado para consistência na geração de cores.
      const categoryRaw = row.dataset.category || 'uncategorized';
      const categoryTranslated = row.dataset.categoryTranslated || categoryRaw;
      const monthYear = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`;

      transactions.push({ date, amount, type: transactionType });

      if (transactionType === 'revenue') {
        revenueByMonth[monthYear] = (revenueByMonth[monthYear] || 0) + amount;
        totalRevenue += amount;
      } else if (transactionType === 'expense') {
        expenseByMonth[monthYear] = (expenseByMonth[monthYear] || 0) + amount;
        totalExpense += amount;
        if (!expenseByCategory[categoryRaw]) {
          expenseByCategory[categoryRaw] = { total: 0, label: categoryTranslated };
        }
        expenseByCategory[categoryRaw].total += amount;
      }
    });

    // Ordena transações por data para cálculos cumulativos
    transactions.sort((a, b) => a.date - b.date);

    let cumulativeBalance = 0;
    let cumulativeRevenue = 0;
    let cumulativeExpense = 0;
    const balanceData = [];
    const cumulativeRevenueData = [];
    const cumulativeExpenseData = [];
    const cumulativeLabels = [];

    transactions.forEach(t => {
      cumulativeBalance += (t.type === 'revenue' ? t.amount : -t.amount);
      cumulativeRevenue += (t.type === 'revenue' ? t.amount : 0);
      cumulativeExpense += (t.type === 'expense' ? t.amount : 0);
      
      balanceData.push(cumulativeBalance);
      cumulativeRevenueData.push(cumulativeRevenue);
      cumulativeExpenseData.push(cumulativeExpense);
      cumulativeLabels.push(t.date.toLocaleDateString((typeof I18n !== 'undefined' ? I18n.locale : 'en'), { day: '2-digit', month: '2-digit' }));
    });

    const allMonths = [...new Set([...Object.keys(revenueByMonth), ...Object.keys(expenseByMonth)])].sort();

    return {
      totals: {
        revenue: totalRevenue,
        expense: totalExpense,
        balance: totalRevenue - totalExpense,
      },
      labels: allMonths,
      revenueData: allMonths.map(month => revenueByMonth[month] || 0),
      expenseData: allMonths.map(month => expenseByMonth[month] || 0),
      pieChart: {
        // Usamos os nomes originais para gerar as cores e os traduzidos para exibir no gráfico.
        rawLabels: Object.keys(expenseByCategory).sort(),
        translatedLabels: Object.keys(expenseByCategory).sort().map(key => expenseByCategory[key].label),
        data: Object.keys(expenseByCategory).sort().map(key => expenseByCategory[key].total),
      },
      cumulative: {
        labels: cumulativeLabels,
        balance: balanceData,
        revenue: cumulativeRevenueData,
        expense: cumulativeExpenseData,
      }
    };
  }

  /**
   * Lê as cores principais a partir das variáveis CSS para consistência visual.
   */
  getCssColors() {
    const style = getComputedStyle(document.documentElement);
    return {
      primary: style.getPropertyValue('--primary-color')?.trim() || '#4A69A3',
      success: style.getPropertyValue('--success-color')?.trim() || '#28a745',
      error: style.getPropertyValue('--error-color')?.trim() || '#dc3545',
    };
  }

  /**
   * Formata um número como moeda BRL.
   * @param {number} value - O valor a ser formatado.
   */
  formatCurrency(value) {
    const locale = (typeof I18n !== 'undefined' ? I18n.locale : 'en');
    return new Intl.NumberFormat(locale, { style: 'currency', currency: 'BRL' }).format(value);
  }

  /**
   * Wrapper seguro para o I18n do Redmine para evitar race conditions.
   * @param {string} key - A chave de tradução.
   */
  t(key) {
    return (typeof I18n !== 'undefined' && I18n.t) ? I18n.t(key) : key;
  }

  /**
   * Atualiza os cards de sumário com os totais calculados.
   * @param {object} totals - Objeto com { revenue, expense, balance }.
   */
  updateSummaryCards(totals) {
    const revenueEl = document.getElementById('cf-summary-revenue');
    const expenseEl = document.getElementById('cf-summary-expense');
    const balanceEl = document.getElementById('cf-summary-balance');

    if (revenueEl) {
      revenueEl.textContent = this.formatCurrency(totals.revenue);
    }
    if (expenseEl) {
      expenseEl.textContent = this.formatCurrency(totals.expense);
    }
    if (balanceEl) {
      balanceEl.textContent = this.formatCurrency(totals.balance);
      balanceEl.className = `cf-card-value ${totals.balance >= 0 ? 'cf-success' : 'cf-danger'}`;
    }
  }

  renderRevenueExpenseChart(data) {
    const ctx = document.getElementById('cashFlowBarChart');
    if (!ctx) return;

    // CORREÇÃO: Usamos o ID do canvas como a chave para consistência.
    this.charts[ctx.id] = new Chart(ctx, {
      type: 'bar',
      data: {
        labels: data.labels,
        datasets: [{
          label: this.t('foton_cash_flow.dashboard.revenue'),
          data: data.revenueData,
          backgroundColor: this.colors.success,
        }, {
          label: this.t('foton_cash_flow.dashboard.expense'),
          data: data.expenseData,
          backgroundColor: this.colors.error,
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          tooltip: {
            callbacks: { label: (context) => `${context.dataset.label}: ${this.formatCurrency(context.parsed.y)}` }
          }
        },
        scales: { y: { ticks: { callback: (value) => this.formatCurrency(value) } } }
      }
    });
  }

  renderExpenseByCategoryChart(data) {
    const ctx = document.getElementById('cashFlowPieChart');
    if (!ctx) return;

    let getCategoryColor;
    // **CORREÇÃO CRÍTICA**: Atribui a função de forma segura, com um fallback.
    if (window.FotonCashFlow && window.FotonCashFlow.Utils && typeof window.FotonCashFlow.Utils.getCategoryColor === 'function') {
      getCategoryColor = window.FotonCashFlow.Utils.getCategoryColor;
    } else {
      console.warn("[DashboardManager] Utilitário de cores não encontrado. Usando cores padrão para o gráfico de pizza.");
      // Função de fallback que retorna uma cor cinza padrão para evitar erros.
      getCategoryColor = () => '#cccccc';
    }

    // **CORREÇÃO DE LÓGICA**: Usa os nomes de categoria *originais* para gerar cores consistentes.
    const backgroundColors = data.pieChart.rawLabels.map(rawLabel => getCategoryColor(rawLabel));

    // CORREÇÃO: Usamos o ID do canvas como a chave.
    this.charts[ctx.id] = new Chart(ctx, {
      type: 'pie',
      data: {
        labels: data.pieChart.translatedLabels,
        datasets: [{
          data: data.pieChart.data,
          // Usa as cores geradas dinamicamente para consistência
          backgroundColor: backgroundColors,
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { position: 'right' },
          tooltip: { callbacks: { label: (context) => `${context.label}: ${this.formatCurrency(context.parsed)}` } }
        }
      }
    });
  }

  renderCumulativeBalanceChart(data) {
    const ctx = document.getElementById('cashFlowBalanceChart');
    if (!ctx || !data.cumulative) return;

    // CORREÇÃO: Usamos o ID do canvas como a chave.
    this.charts[ctx.id] = new Chart(ctx, {
      type: 'line',
      data: {
        labels: data.cumulative.labels,
        datasets: [{
          label: this.t('foton_cash_flow.dashboard.balance'),
          data: data.cumulative.balance,
          borderColor: this.colors.primary,
          backgroundColor: this.colors.primary + '40', // Adiciona transparência
          fill: true,
          tension: 0.1
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
          tooltip: { callbacks: { label: (context) => `${context.dataset.label}: ${this.formatCurrency(context.parsed.y)}` } }
        },
        scales: { y: { ticks: { callback: (value) => this.formatCurrency(value) } } }
      }
    });
  }

  renderCumulativeFlowChart(data) {
    const ctx = document.getElementById('cashFlowCumulativeChart');
    if (!ctx || !data.cumulative) return;

    // CORREÇÃO: Usamos o ID do canvas como a chave.
    this.charts[ctx.id] = new Chart(ctx, {
      type: 'line',
      data: {
        labels: data.cumulative.labels,
        datasets: [{
          label: this.t('foton_cash_flow.dashboard.revenue'),
          data: data.cumulative.revenue,
          borderColor: this.colors.success,
          backgroundColor: this.colors.success + '40',
          fill: true,
          tension: 0.1
        }, {
          label: this.t('foton_cash_flow.dashboard.expense'),
          data: data.cumulative.expense,
          borderColor: this.colors.error,
          backgroundColor: this.colors.error + '40',
          fill: true,
          tension: 0.1
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { position: 'top' },
          tooltip: { callbacks: { label: (context) => `${context.dataset.label}: ${this.formatCurrency(context.parsed.y)}` } }
        },
        scales: { y: { ticks: { callback: (value) => this.formatCurrency(value) } } }
      }
    });
  }

  /**
   * Destrói uma instância de gráfico específica pelo ID do seu canvas.
   * @param {string} chartId - O ID do elemento <canvas>.
   */
  destroyChart(chartId) {
    if (this.charts[chartId]) {
      console.log(`[DashboardManager] Destruindo gráfico: ${chartId}`);
      this.charts[chartId].destroy();
      delete this.charts[chartId];
    }
  }

  /**
   * Recria um gráfico específico usando os últimos dados disponíveis.
   * @param {string} chartId - O ID do elemento <canvas>.
   */
  recreateChart(chartId) {
    if (!this.lastData) {
      console.error("[DashboardManager] Não há dados para recriar o gráfico.");
      return;
    }
    console.log(`[DashboardManager] Recriando gráfico: ${chartId}`);

    switch (chartId) {
      case 'cashFlowBarChart':
        return this.renderRevenueExpenseChart(this.lastData);
      case 'cashFlowPieChart':
        return this.renderExpenseByCategoryChart(this.lastData);
      case 'cashFlowBalanceChart':
        return this.renderCumulativeBalanceChart(this.lastData);
      case 'cashFlowCumulativeChart':
        return this.renderCumulativeFlowChart(this.lastData);
    }
  }
}

window.FotonCashFlow.DashboardManager = DashboardManager;