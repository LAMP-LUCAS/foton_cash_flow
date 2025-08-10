//= require ./vendor/chart.umd.min.js
//
//= require ./controllers/cash_flow_page_controller.js
//
// A diretiva `//= require` acima é processada pelo Sprockets (Asset Pipeline do Rails).
// Ela garante que o conteúdo de `cash_flow_page_controller.js` seja incluído
// neste arquivo ANTES que ele seja enviado para o navegador.

/**
 * Ponto de entrada principal do JavaScript do plugin.
 * Atua como um roteador para inicializar os controladores corretos
 * com base na página atual.
 */
document.addEventListener('DOMContentLoaded', () => {
  const cashFlowPage = document.querySelector('.cash-flow-page');
  if (cashFlowPage) {
    const controller = new CashFlowPageController(cashFlowPage);
    controller.initialize();
  }

  // A lógica para outras páginas (ex: formulários de new/edit)
  // pode ser adicionada aqui, inicializando outros controladores.
});