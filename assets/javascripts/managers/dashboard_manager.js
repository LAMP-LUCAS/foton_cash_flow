// Garante que o namespace global exista.
window.FotonCashFlow = window.FotonCashFlow || {};

/**
 * Gerencia a renderização e atualização dos gráficos do dashboard.
 */
class DashboardManager {
  constructor(controller) {
    this.controller = controller;
    this.charts = {}; // Armazena as instâncias dos gráficos
    // A inicialização agora é chamada pelo controller após a primeira renderização.

    // Cores dinâmicas baseadas nas variáveis CSS do tema
    this.colors = this.getCssColors();
    this.pieColors = ['#4A69A3', '#8B9DC3', '#C7CEE2', '#E1E4F0', '#B9D1EA', '#8EABCC', '#5B84A6', '#41658A'];
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

    // Renderiza os gráficos com os novos dados
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
    const transactions = [];

    rows.forEach(row => {
      const transactionType = row.dataset.transactionType;
      const amount = parseFloat(row.dataset.amount) || 0;
      // Use the pre-translated category name from the data attribute if available.
      // Fallback to the raw category name, and then to the generic "Uncategorized" string.
      const category = row.dataset.categoryTranslated || row.dataset.category || this.t('foton_cash_flow.general.uncategorized');
      const date = new Date(row.dataset.entryDate);
      const monthYear = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`;

      transactions.push({ date, amount, type: transactionType });

      if (transactionType === 'revenue') {
        revenueByMonth[monthYear] = (revenueByMonth[monthYear] || 0) + amount;
      } else if (transactionType === 'expense') {
        expenseByMonth[monthYear] = (expenseByMonth[monthYear] || 0) + amount;
        expenseByCategory[category] = (expenseByCategory[category] || 0) + amount;
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
      labels: allMonths,
      revenueData: allMonths.map(month => revenueByMonth[month] || 0),
      expenseData: allMonths.map(month => expenseByMonth[month] || 0),
      categoryLabels: Object.keys(expenseByCategory).sort(),
      categoryData: Object.keys(expenseByCategory).sort().map(key => expenseByCategory[key]),
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

  renderRevenueExpenseChart(data) {
    const ctx = document.getElementById('cashFlowBarChart');
    if (!ctx) return;

    this.charts.barChart = new Chart(ctx, {
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
        // maintainAspectRatio: false, // Trecho que defini a adaptação do gráfico ao tamanho do canvas ou expandir-se indefinidamente
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

    this.charts.pieChart = new Chart(ctx, {
      type: 'pie',
      data: {
        labels: data.categoryLabels,
        datasets: [{
          data: data.categoryData,
          // Adicionar mais cores se necessário
          backgroundColor: this.pieColors,
        }]
      },
      options: {
        responsive: true,
        // maintainAspectRatio: false, // Trecho que defini a adaptação do gráfico ao tamanho do canvas ou expandir-se indefinidamente
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

    this.charts.balanceChart = new Chart(ctx, {
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
        // maintainAspectRatio: false, // Trecho que defini a adaptação do gráfico ao tamanho do canvas ou expandir-se indefinidamente
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

    this.charts.cumulativeChart = new Chart(ctx, {
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
        // maintainAspectRatio: false, // Trecho que defini a adaptação do gráfico ao tamanho do canvas ou expandir-se indefinidamente
        plugins: {
          legend: { position: 'top' },
          tooltip: { callbacks: { label: (context) => `${context.dataset.label}: ${this.formatCurrency(context.parsed.y)}` } }
        },
        scales: { y: { ticks: { callback: (value) => this.formatCurrency(value) } } }
      }
    });
  }
}

window.FotonCashFlow.DashboardManager = DashboardManager;