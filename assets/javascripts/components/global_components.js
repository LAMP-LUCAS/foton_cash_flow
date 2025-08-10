/**
 * Configura componentes globais que não pertencem à tabela, como o menu de ações.
 * @param {HTMLElement} container - O elemento principal da página.
 */
export function setupGlobalComponents(container) {
  const toggleBtn = container.querySelector('#actions-menu-btn');
  const menu = container.querySelector('#actions-dropdown-menu');

  if (toggleBtn && menu) {
    toggleBtn.addEventListener('click', (event) => {
      event.stopPropagation();
      menu.classList.toggle('show');
    });

    // Fecha o menu se o usuário clicar fora dele
    document.addEventListener('click', () => {
      if (menu.classList.contains('show')) {
        menu.classList.remove('show');
      }
    });
  }
}