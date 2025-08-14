/*
 * Foton Cash Flow - JavaScript para a Página de Configurações
 * Descrição: Lida com a adição dinâmica de categorias e inicialização de componentes.
*/

function addNewCategory(button) {
  const container = document.getElementById('cf-categories-list');
  if (!container) return;

  const index = container.children.length;
  const deleteButtonText = button.dataset.deleteText || 'Delete';

  const newItem = document.createElement('div');
  newItem.className = 'cf-category-item';
  newItem.innerHTML = `
    <input type="text" name="settings[categories][]" id="category_${index}" />
    <a href="#" class="icon icon-del delete-category-btn" title="${deleteButtonText}"></a>
  `;

  container.appendChild(newItem);
  newItem.querySelector('input').focus();
}

document.addEventListener('DOMContentLoaded', function() {
  // Inicializa Select2 se o jQuery estiver disponível
  if (typeof jQuery !== 'undefined' && typeof jQuery.fn.select2 !== 'undefined') {
    jQuery('.cf-select2').select2({ width: '100%' });
  }

  // Delegação de eventos para adicionar e remover categorias
  document.body.addEventListener('click', function(event) {
    if (event.target.matches('.cf-add-category-btn')) {
      event.preventDefault();
      addNewCategory(event.target);
    } else if (event.target.matches('.delete-category-btn')) {
      event.preventDefault();
      event.target.closest('.cf-category-item').remove();
    }
  });
});