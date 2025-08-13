/*
 * Foton Cash Flow - Lógica dos Gráficos
 * Descrição: Inicializa e gerencia todos os gráficos da página de fluxo de caixa.
 */

document.addEventListener('DOMContentLoaded', () => {
  
  // ==========================================================================
  // 1. CONFIGURAÇÕES GLOBAIS E HELPERS
  // ==========================================================================

  // Opções padrão para todos os gráficos para garantir consistência e responsividade correta.
  const defaultChartOptions = {
    responsive: true,
    maintainAspectRatio: false, // ESSENCIAL: Permite que o CSS controle a proporção.
    plugins: {
      legend: {
        position: 'top',
      },
    },
  };

  // Helper para mesclar opções padrão com opções específicas de um gráfico.
  const mergeOptions = (specificOptions) => {
    // Deep merge para não sobrescrever objetos aninhados como 'plugins'
    return {
      ...defaultChartOptions,
      ...specificOptions,
      plugins: {
        ...defaultChartOptions.plugins,
        ...(specificOptions.plugins || {}),
      },
    };
  };

  // ==========================================================================
  // 2. INICIALIZAÇÃO DOS GRÁFICOS
  // ==========================================================================

  // Gráfico de Barras: Receita vs. Despesa
  const barChartCanvas = document.getElementById('cashFlowBarChart');
  if (barChartCanvas) {
    const data = JSON.parse(barChartCanvas.dataset.chartData);
    new Chart(barChartCanvas, {
      type: 'bar',
      data: {
        labels: data.labels,
        datasets: [
          {
            label: 'Receita',
            data: data.revenue,
            backgroundColor: 'rgba(40, 167, 69, 0.7)',
            borderColor: 'rgba(40, 167, 69, 1)',
            borderWidth: 1,
          },
          {
            label: 'Despesa',
            data: data.expense,
            backgroundColor: 'rgba(220, 53, 69, 0.7)',
            borderColor: 'rgba(220, 53, 69, 1)',
            borderWidth: 1,
          },
        ],
      },
      options: mergeOptions({}),
    });
  }

  // Gráfico de Pizza: Despesas por Categoria
  const pieChartCanvas = document.getElementById('cashFlowPieChart');
  if (pieChartCanvas) {
    const data = JSON.parse(pieChartCanvas.dataset.chartData);
    new Chart(pieChartCanvas, {
      type: 'pie',
      data: {
        labels: data.labels,
        datasets: [{
          label: 'Despesas por Categoria',
          data: data.data,
          // Cores podem ser adicionadas aqui se necessário
        }],
      },
      options: mergeOptions({}),
    });
  }

  // Gráfico de Linha: Saldo Acumulado
  const balanceChartCanvas = document.getElementById('cashFlowBalanceChart');
  if (balanceChartCanvas) {
    const data = JSON.parse(balanceChartCanvas.dataset.chartData);
    new Chart(balanceChartCanvas, {
      type: 'line',
      data: {
        labels: data.labels,
        datasets: [{
          label: 'Saldo Acumulado',
          data: data.data,
          fill: true,
          backgroundColor: 'rgba(63, 81, 181, 0.2)',
          borderColor: 'rgba(63, 81, 181, 1)',
          tension: 0.1,
        }],
      },
      options: mergeOptions({}),
    });
  }

  // Gráfico de Linha: Fluxo Acumulado (Receita vs. Despesa)
  const cumulativeChartCanvas = document.getElementById('cashFlowCumulativeChart');
  if (cumulativeChartCanvas) {
    const data = JSON.parse(cumulativeChartCanvas.dataset.chartData);
    new Chart(cumulativeChartCanvas, {
      type: 'line',
      data: {
        labels: data.labels,
        datasets: [
          {
            label: 'Receita Acumulada',
            data: data.revenue,
            borderColor: 'rgba(40, 167, 69, 1)',
            backgroundColor: 'rgba(40, 167, 69, 0.1)',
            fill: true,
            tension: 0.1,
          },
          {
            label: 'Despesa Acumulada',
            data: data.expense,
            borderColor: 'rgba(220, 53, 69, 1)',
            backgroundColor: 'rgba(220, 53, 69, 0.1)',
            fill: true,
            tension: 0.1,
          },
        ],
      },
      options: mergeOptions({}),
    });
  }

  // ==========================================================================
  // 3. FUNCIONALIDADE DE MAXIMIZAR GRÁFICO
  // ==========================================================================

  const backdrop = document.createElement('div');
  backdrop.className = 'cf-chart-backdrop';
  document.body.appendChild(backdrop);

  const chartCards = document.querySelectorAll('.cf-chart-card');

  const closeMaximizedChart = () => {
    const maximizedCard = document.querySelector('.cf-chart-card.maximized');
    if (maximizedCard) {
      maximizedCard.classList.remove('maximized');
      const canvasId = maximizedCard.querySelector('canvas').id;
      const chartInstance = Chart.getChart(canvasId);
      if (chartInstance) {
        // O atraso ainda é uma boa prática para garantir que a transição CSS comece.
        setTimeout(() => chartInstance.resize(), 50);
      }
    }
    backdrop.classList.remove('show');
    document.body.classList.remove('cf-modal-open');
  };

  chartCards.forEach(card => {
    const closeBtn = document.createElement('button');
    closeBtn.className = 'cf-chart-close-btn';
    closeBtn.innerHTML = '&times;';
    closeBtn.setAttribute('aria-label', 'Fechar gráfico');
    closeBtn.onclick = (e) => {
      e.stopPropagation();
      closeMaximizedChart();
    };
    card.appendChild(closeBtn);

    card.addEventListener('click', (e) => {
      if (e.target === closeBtn || card.classList.contains('maximized')) {
        return;
      }

      closeMaximizedChart(); // Fecha qualquer outro gráfico aberto

      card.classList.add('maximized');
      backdrop.classList.add('show');
      document.body.classList.add('cf-modal-open');

      const canvasId = card.querySelector('canvas').id;
      const chartInstance = Chart.getChart(canvasId);
      if (chartInstance) {
        setTimeout(() => chartInstance.resize(), 50);
      }
    });
  });

  backdrop.addEventListener('click', closeMaximizedChart);
});