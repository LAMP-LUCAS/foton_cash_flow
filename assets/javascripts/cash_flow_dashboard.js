// cash_flow_dashboard.js
// Gráficos do dashboard BI do fluxo de caixa

document.addEventListener('DOMContentLoaded', function() {
  if (typeof Chart === 'undefined') return;
  var ctx1 = document.getElementById('cashFlowBarChart');
  if (ctx1) {
    new Chart(ctx1, {
      type: 'bar',
      data: window.cashFlowBarData,
      options: {
        responsive: true,
        plugins: { legend: { display: false } },
        scales: { y: { beginAtZero: true } }
      }
    });
  }
  var ctx2 = document.getElementById('cashFlowPieChart');
  if (ctx2) {
    new Chart(ctx2, {
      type: 'pie',
      data: window.cashFlowPieData,
      options: { responsive: true }
    });
  }
});
