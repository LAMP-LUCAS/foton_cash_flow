/**
 * Ponto de entrada principal do JavaScript do plugin.
 * Atua como um roteador para inicializar os controladores corretos
 * com base na página atual.
 */

// Cria o namespace global para o plugin se ele ainda não existir.
// Isso deve ser feito antes de qualquer outra lógica.
window.FotonCashFlow = window.FotonCashFlow || { Controllers: {} };

document.addEventListener('DOMContentLoaded', () => {
  // Inicializa o controller da página principal do fluxo de caixa
  const cashFlowPage = document.querySelector('.cash-flow-page');
  if (cashFlowPage) {
    // Agora verificamos se o Controller existe dentro do nosso namespace.
    if (typeof FotonCashFlow.Controllers.CashFlowPageController !== 'undefined') {
      const controller = new FotonCashFlow.Controllers.CashFlowPageController(cashFlowPage);
      controller.initialize();
    } else {
      console.error('FOTON CASH FLOW: FotonCashFlow.CashFlowPageController não foi encontrado. Verifique a ordem de carregamento dos scripts em _cash_flow_assets.html.erb.');
    }
  }

  // Inicializa o controller da página de importação
  const importFormContainer = document.querySelector('.cf-form-container');
  if (importFormContainer) {
    if (typeof FotonCashFlow.Controllers.ImportFormController !== 'undefined') {
      new FotonCashFlow.Controllers.ImportFormController(importFormContainer);
    } else {
      console.error('FOTON CASH FLOW: FotonCashFlow.ImportFormController não foi encontrado. Verifique a ordem de carregamento dos scripts.');
    }
  }
});

