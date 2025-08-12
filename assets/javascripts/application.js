/**
 * Ponto de entrada principal do JavaScript do plugin.
 * Atua como um roteador para inicializar os controladores corretos
 * com base na página atual.
 */

// Cria o namespace global para o plugin se ele ainda não existir.
// Isso deve ser feito antes de qualquer outra lógica.
window.FotonCashFlow = window.FotonCashFlow || {};

document.addEventListener('DOMContentLoaded', () => {
  const cashFlowPage = document.querySelector('.cash-flow-page');
  if (cashFlowPage) {
    // Agora verificamos se o Controller existe dentro do nosso namespace.
    if (typeof FotonCashFlow.CashFlowPageController !== 'undefined') {
      const controller = new FotonCashFlow.CashFlowPageController(cashFlowPage);
      controller.initialize();
    } else {
      console.error('FOTON CASH FLOW: FotonCashFlow.CashFlowPageController não foi encontrado. Verifique a ordem de carregamento dos scripts em _cash_flow_assets.html.erb.');
    }
  }

  // A lógica para outras páginas (ex: formulários de new/edit)
  // pode ser adicionada aqui, inicializando outros controladores.
});