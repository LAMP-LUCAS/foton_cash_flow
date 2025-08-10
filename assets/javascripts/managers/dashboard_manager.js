/**
 * Gerencia a criação, atualização e lógica dos gráficos do dashboard.
 * Utiliza a biblioteca Chart.js.
 */
export class DashboardManager {
  constructor(controller) {
    this.controller = controller;
    this.charts = {};
    this.initializeCharts();
  }


  /**
   * Encontra os elementos canvas e inicializa os gráficos com dados vazios.
   */
  initializeCharts() {
    if (typeof Chart === 'undefined') {
      console.warn('Chart.js não está carregado. Os gráficos não funcionarão.');
      return;
    }

    // Cores do CSS
    const primaryColor = this.getCssVariable('--primary-color');
    const successColor = this.getCssVariable('--success-color');
    const errorColor = this.getCssVariable('--error-color');
    const currencyFormatter = new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' });

    // Gráfico de Pizza (Despesas por Categoria)
    const pieCtx = document.getElementById('cashFlowPieChart')?.getContext('2d');
    if (pieCtx) {
      this.charts.pie = new Chart(pieCtx, {
        type: 'pie',
        data: { labels: [], datasets: [{ data: [], backgroundColor: ['#4A69A3', '#8B9DC3', '#C7CEE2', '#E1E4F0', '#B9D1EA', '#8EABCC'] }] },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: {
            legend: { position: 'bottom' },
            tooltip: {
              callbacks: {
                label: (context) => `${context.label || ''}: ${currencyFormatter.format(context.parsed || 0)}`
              }
            }
          }
        }
      });
    }

    // Gráfico de Linha (Balanço Acumulado)
    const balanceCtx = document.getElementById('cashFlowBalanceChart')?.getContext('2d');
    if (balanceCtx) {
      this.charts.balance = new Chart(balanceCtx, {
        type: 'line',
        data: { labels: [], datasets: [{ label: 'Balanço', data: [], borderColor: primaryColor, tension: 0.1, fill: true, backgroundColor: primaryColor + '20' }] },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: {
            legend: { display: false },
            tooltip: {
              callbacks: {
                label: (context) => `Balanço: ${currencyFormatter.format(context.parsed.y || 0)}`
              }
            }
          },
          scales: { y: { ticks: { callback: (value) => currencyFormatter.format(value) } } }
        }
      });
    }
    
    // Gráfico de Barras (Receita vs Despesa por Mês)
    const barCtx = document.getElementById('cashFlowBarChart')?.getContext('2d');
    if (barCtx) {
        this.charts.bar = new Chart(barCtx, {
            type: 'bar',
            data: {
                labels: [],
                datasets: [
                    { label: 'Receita', data: [], backgroundColor: successColor },
                    { label: 'Despesa', data: [], backgroundColor: errorColor }
                ]
                ]
            },
            options: {
              responsive: true,
              maintainAspectRatio: false,
              scales: {
                x: { stacked: false },
                y: {
                  stacked: false,
                  ticks: { callback: (value) => currencyFormatter.format(value) }
                }
              },
              plugins: {
                tooltip: {
                  callbacks: {
                    label: (context) => `${context.dataset.label}: ${currencyFormatter.format(context.parsed.y || 0)}`
                  }
                }
              }
            }
        });
    }
  }

  /**
   * Atualiza todos os gráficos com base nas linhas de dados visíveis.
   * @param {Array<HTMLElement>} visibleRows - As linhas filtradas e ordenadas.
   */
  updateCharts(visibleRows) {
    if (Object.keys(this.charts).length === 0) return;

    const dataByCategory = this.aggregateByCategory(visibleRows, 'expense');
    const dataByMonth = this.aggregateByMonth(visibleRows);
    const balanceData = this.calculateBalance(visibleRows);

    if (this.charts.pie) {
      this.charts.pie.data.labels = Object.keys(dataByCategory);
      this.charts.pie.data.datasets[0].data = Object.values(dataByCategory);
      this.charts.pie.update('none');
    }

    if (this.charts.bar) {
      const sortedMonths = Object.keys(dataByMonth).sort();
      this.charts.bar.data.labels = sortedMonths.map(month => this.formatMonthLabel(month));
      this.charts.bar.data.datasets[0].data = sortedMonths.map(month => dataByMonth[month].revenue);
      this.charts.bar.data.datasets[1].data = sortedMonths.map(month => dataByMonth[month].expense);
      this.charts.bar.update('none');
    }

    if (this.charts.balance) {
      this.charts.balance.data.labels = balanceData.labels.map(date => this.formatDateLabel(date));
      this.charts.balance.data.datasets[0].data = balanceData.values;
      this.charts.balance.update('none');
    }
  }

  aggregateByCategory(rows, transactionType) {
    const data = {};
    rows.forEach(row => {
      if (row.dataset.cashFlowTransactionType === transactionType) {
        const category = row.dataset.cashFlowCategory || 'Sem Categoria';
        const amount = parseFloat(row.dataset.cashFlowAmount) || 0;
        data[category] = (data[category] || 0) + amount;
      }
    });
    return data;
  }

  aggregateByMonth(rows) {
    const data = {};
    rows.forEach(row => {
      const date = row.dataset.cashFlowEntryDate;
      if (!date) return;
      const monthKey = date.substring(0, 7); // 'YYYY-MM'
      const type = row.dataset.cashFlowTransactionType;
      const amount = parseFloat(row.dataset.cashFlowAmount) || 0;
      if (!data[monthKey]) data[monthKey] = { revenue: 0, expense: 0 };
      if (type === 'revenue') data[monthKey].revenue += amount;
      else if (type === 'expense') data[monthKey].expense += amount;
    });
    return data;
  }

  calculateBalance(rows) {
    const sortedRows = [...rows].sort((a, b) => new Date(a.dataset.cashFlowEntryDate) - new Date(b.dataset.cashFlowEntryDate));
    const labels = [];
    const values = [];
    let currentBalance = 0;
    sortedRows.forEach(row => {
      const date = row.dataset.cashFlowEntryDate;
      if (!date) return;
      const type = row.dataset.cashFlowTransactionType;
      const amount = parseFloat(row.dataset.cashFlowAmount) || 0;
      currentBalance += (type === 'revenue' ? amount : -amount);
      labels.push(date);
      values.push(currentBalance);
    });
    return { labels, values };
  }

  getCssVariable(name) {
    return getComputedStyle(document.documentElement).getPropertyValue(name).trim();
  }

  formatMonthLabel(monthKey) { // YYYY-MM
    const [year, month] = monthKey.split('-');
    return new Date(year, month - 1).toLocaleString('default', { month: 'short', year: '2-digit' });
  }

  formatDateLabel(dateString) { // YYYY-MM-DD
    return new Date(dateString + 'T00:00:00').toLocaleDateString('pt-BR', { day: '2-digit', month: '2-digit' });
  }
}
