// cash_flow_dashboard.js
// Gráficos do dashboard BI do fluxo de caixa

document.addEventListener('DOMContentLoaded', function() {
  if (typeof Chart === 'undefined') return;

  // Função auxiliar para obter as cores do CSS
  function getCssVariable(name) {
    return getComputedStyle(document.documentElement).getPropertyValue(name).trim();
  }

  const primaryColor = getCssVariable('--primary-color');
  const successColor = getCssVariable('--success-color');
  const errorColor = getCssVariable('--error-color');
  const borderColor = getCssVariable('--border-color');

  // ==================== GRÁFICO DE BARRAS (Receita x Despesa) ====================
  const barChartElement = document.getElementById('cashFlowBarChart');
  if (barChartElement && window.cashFlowBarData) {
    new Chart(barChartElement, {
      type: 'bar',
      data: {
        labels: window.cashFlowBarData.labels,
        datasets: [{
          label: 'Receita',
          backgroundColor: successColor,
          borderColor: successColor,
          data: window.cashFlowBarData.revenue,
        }, {
          label: 'Despesa',
          backgroundColor: errorColor,
          borderColor: errorColor,
          data: window.cashFlowBarData.expense,
        }]
      },
      options: {
        responsive: true,
        plugins: {
          legend: {
            display: true,
            position: 'top',
          },
          title: {
            display: false, // O título será no HTML
          },
        },
        scales: {
          x: {
            stacked: false,
          },
          y: {
            stacked: false,
            beginAtZero: true,
          }
        }
      }
    });
  }

  // ==================== GRÁFICO DE PIZZA (Despesas por Categoria) ====================
  const pieChartElement = document.getElementById('cashFlowPieChart');
  if (pieChartElement && window.cashFlowPieData) {
    const pieColors = ['#4A69A3', '#8B9DC3', '#C7CEE2', '#E1E4F0', '#B9D1EA', '#8EABCC', '#5B84A6', '#41658A']; // Cores baseadas no primaryColor
    new Chart(pieChartElement, {
      type: 'pie',
      data: {
        labels: window.cashFlowPieData.labels,
        datasets: [{
          data: window.cashFlowPieData.data,
          backgroundColor: pieColors,
          hoverBackgroundColor: pieColors,
        }]
      },
      options: {
        responsive: true,
        plugins: {
          legend: {
            position: 'right', // Posição da legenda
          },
          title: {
            display: false,
          },
          tooltip: {
            callbacks: {
              label: function(context) {
                let label = context.label || '';
                if (label) {
                  label += ': ';
                }
                if (context.parsed !== null) {
                  label += new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(context.parsed);
                }
                return label;
              }
            }
          }
        }
      }
    });
  }

  // ==================== NOVO: GRÁFICO DE LINHA (Balanço Acumulado) ====================
  const balanceChartElement = document.getElementById('cashFlowBalanceChart');
  if (balanceChartElement && window.cashFlowBalanceData) {
    new Chart(balanceChartElement, {
      type: 'line',
      data: {
        labels: window.cashFlowBalanceData.labels,
        datasets: [{
          label: 'Balanço Acumulado',
          data: window.cashFlowBalanceData.data,
          borderColor: primaryColor,
          backgroundColor: primaryColor + '40', // Cor com transparência
          fill: true,
          tension: 0.3,
          pointBackgroundColor: primaryColor,
        }]
      },
      options: {
        responsive: true,
        plugins: {
          legend: {
            display: false,
          },
          title: {
            display: false,
          },
          tooltip: {
            callbacks: {
              label: function(context) {
                return `Balanço: ${new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(context.parsed.y)}`;
              }
            }
          }
        },
        scales: {
          x: {
            grid: {
              color: borderColor,
            },
          },
          y: {
            beginAtZero: true,
            grid: {
              color: borderColor,
            },
            ticks: {
              callback: function(value, index, ticks) {
                return new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(value);
              }
            }
          }
        }
      }
    });
  }

  // ==================== NOVO: GRÁFICO DE LINHA (Fluxo Acumulado) ====================
  const cumulativeChartElement = document.getElementById('cashFlowCumulativeChart');
  if (cumulativeChartElement && window.cashFlowCumulativeData) {
    new Chart(cumulativeChartElement, {
      type: 'line',
      data: {
        labels: window.cashFlowCumulativeData.labels,
        datasets: [{
          label: 'Receita Acumulada',
          data: window.cashFlowCumulativeData.revenue,
          borderColor: successColor,
          backgroundColor: successColor + '40',
          fill: true,
          tension: 0.3,
          pointBackgroundColor: successColor,
        }, {
          label: 'Despesa Acumulada',
          data: window.cashFlowCumulativeData.expense,
          borderColor: errorColor,
          backgroundColor: errorColor + '40',
          fill: true,
          tension: 0.3,
          pointBackgroundColor: errorColor,
        }]
      },
      options: {
        responsive: true,
        plugins: {
          legend: {
            display: true,
            position: 'top',
          },
          title: {
            display: false,
          },
          tooltip: {
            callbacks: {
              label: function(context) {
                return `${context.dataset.label}: ${new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(context.parsed.y)}`;
              }
            }
          }
        },
        scales: {
          x: {
            grid: {
              color: borderColor,
            },
          },
          y: {
            beginAtZero: true,
            grid: {
              color: borderColor,
            },
            ticks: {
              callback: function(value, index, ticks) {
                return new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(value);
              }
            }
          }
        }
      }
    });
  }

});