/**
 * Gerencia a lógica e a renderização da paginação.
 */
export class PaginationManager {
    constructor(tableInstance) {
        this.table = tableInstance;
        this.container = document.getElementById('cf-pagination-container');
    }

    render() {
        const totalPages = Math.ceil(this.table.visibleRows.length / this.table.rowsPerPage);
        this.table.currentPage = Math.min(this.table.currentPage, totalPages) || 1;

        if (totalPages <= 1) {
            this.container.innerHTML = '';
            return;
        }

        let paginationHTML = `<div class="cf-pagination">`;
        paginationHTML += `<button class="cf-pagination-btn prev" ${this.table.currentPage === 1 ? 'disabled' : ''}>Anterior</button>`;
        paginationHTML += `<span class="cf-pagination-info">Página ${this.table.currentPage} de ${totalPages}</span>`;
        paginationHTML += `<button class="cf-pagination-btn next" ${this.table.currentPage === totalPages ? 'disabled' : ''}>Próxima</button>`;
        paginationHTML += `</div>`;
        
        this.container.innerHTML = paginationHTML;
        this.bindEvents();
    }

    bindEvents() {
        this.container.querySelector('.prev')?.addEventListener('click', () => {
            this.table.currentPage--;
            this.table.renderTable();
        });
        this.container.querySelector('.next')?.addEventListener('click', () => {
            this.table.currentPage++;
            this.table.renderTable();
        });
    }

    getPaginatedRows(rows) {
        const start = (this.table.currentPage - 1) * this.table.rowsPerPage;
        return rows.slice(start, start + this.table.rowsPerPage);
    }
}