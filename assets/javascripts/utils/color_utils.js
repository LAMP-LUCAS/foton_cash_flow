// Garante que o namespace global e o sub-namespace de utilitários existam.
window.FotonCashFlow = window.FotonCashFlow || {};
window.FotonCashFlow.Utils = window.FotonCashFlow.Utils || {};

(function(Utils) {
  'use strict';

  // Paleta de cores consistentes para as categorias
  const CATEGORY_COLORS = [
    '#4e79a7', '#f28e2c', '#e15759', '#76b7b2', '#59a14f',
    '#edc949', '#af7aa1', '#ff9da7', '#9c755f', '#bab0ab'
  ];

  // Gera um hash numérico simples e determinístico a partir de uma string.
  function simpleHash(str) {
    let hash = 0;
    if (!str || str.length === 0) return hash;
    for (let i = 0; i < str.length; i++) {
      const char = str.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash |= 0; // Converte para um inteiro de 32bit
    }
    return Math.abs(hash);
  }

  Utils.getCategoryColor = function(categoryName) {
    if (!categoryName) return '#cccccc'; // Cor padrão para "sem categoria"
    const index = simpleHash(categoryName) % CATEGORY_COLORS.length;
    return CATEGORY_COLORS[index];
  };

})(window.FotonCashFlow.Utils);

