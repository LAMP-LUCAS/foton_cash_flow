/**
 * Gerencia a exibição de modais, como o de confirmação de exclusão.
 */
export class ModalManager {
    constructor(tableInstance) {
        this.table = tableInstance;
        this.initDeleteModal();
    }

    initDeleteModal() {
        const modal = document.getElementById('confirm-delete-modal');
        if (!modal) return;

        const confirmBtn = modal.querySelector('#confirm-delete-btn');
        const closeBtns = modal.querySelectorAll('[data-dismiss="modal"]');

        this.table.tbody.addEventListener('click', (e) => {
            const deleteLink = e.target.closest('a.icon-del');
            if (deleteLink) {
                e.preventDefault();
                confirmBtn.href = deleteLink.href;
                modal.classList.add('show');
            }
        });

        const closeModal = () => modal.classList.remove('show');
        closeBtns.forEach(btn => btn.addEventListener('click', closeModal));
        modal.addEventListener('click', (e) => {
            if (e.target === modal) closeModal();
        });
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape' && modal.classList.contains('show')) {
                closeModal();
            }
        });
    }
}