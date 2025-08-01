// ========== MENU CASCATA DE FILTROS (Notion-like) ==========
document.addEventListener('DOMContentLoaded', function() {
  const addFilterBtn = document.getElementById('add-filter-btn');
  const filtersDropdown = document.getElementById('filters-dropdown');
  const closeFiltersBtn = document.getElementById('close-filters-dropdown');
  const clearAllBtn = document.getElementById('clear-all-filters');
  const filtersForm = document.getElementById('cf-filters-form');

  // Abrir menu cascata
  if (addFilterBtn && filtersDropdown) {
    addFilterBtn.addEventListener('click', function() {
      filtersDropdown.classList.toggle('active');
      if (filtersDropdown.classList.contains('active')) {
        filtersDropdown.style.display = 'block';
      } else {
        filtersDropdown.style.display = 'none';
      }
    });
  }
  // Fechar menu cascata
  if (closeFiltersBtn && filtersDropdown) {
    closeFiltersBtn.addEventListener('click', function() {
      filtersDropdown.classList.remove('active');
      filtersDropdown.style.display = 'none';
    });
  }
  // Fechar ao clicar fora
  document.addEventListener('mousedown', function(e) {
    if (filtersDropdown && !filtersDropdown.contains(e.target) && !addFilterBtn.contains(e.target)) {
      filtersDropdown.classList.remove('active');
      filtersDropdown.style.display = 'none';
    }
  });
  // Remover filtro individual
  document.querySelectorAll('.cf-remove-filter').forEach(btn => {
    btn.addEventListener('click', function() {
      const filter = this.dataset.filter;
      const url = new URL(window.location);
      url.searchParams.delete(`query[${filter}]`);
      window.location = url.toString();
    });
  });
  // Limpar todos os filtros
  if (clearAllBtn) {
    clearAllBtn.addEventListener('click', function() {
      const url = new URL(window.location);
      Array.from(url.searchParams.keys()).forEach(key => {
        if (key.startsWith('query[')) url.searchParams.delete(key);
      });
      window.location = url.toString();
    });
  }
  // Submeter filtros do menu cascata
  if (filtersForm) {
    filtersForm.addEventListener('submit', function(e) {
      // Permite submit normal (GET)
      filtersDropdown.classList.remove('active');
      filtersDropdown.style.display = 'none';
    });
  }
});
// ========== FIM MENU CASCATA ==========
// cash_flow_main.js
// Unificação de lógica de filtros e utilidades gerais do fluxo de caixa

document.addEventListener('DOMContentLoaded', function() {
  // Remover filtros individuais
  document.querySelectorAll('.remove-filter').forEach(button => {
    button.addEventListener('click', function(e) {
      e.preventDefault();
      const filterName = this.dataset.filter;
      const url = new URL(window.location);
      url.searchParams.delete(`query[${filterName}]`);
      window.location = url.toString();
    });
  });

  // Botão "Limpar" dentro dos filtros
  document.querySelectorAll('.clear-filter').forEach(button => {
    button.addEventListener('click', function() {
      const form = this.closest('.dropdown-form');
      form.querySelectorAll('input, select').forEach(field => {
        if (field.type !== 'submit') field.value = '';
      });
      form.closest('form').submit();
    });
  });

  // Atualizar contador de filtros ativos
  function updateActiveFiltersCount() {
    const count = document.querySelectorAll('.filter-tag').length;
    const counter = document.querySelector('.active-filters-count');
    if (counter) {
      counter.textContent = count;
      counter.style.display = count > 0 ? 'block' : 'none';
    }
  }
  updateActiveFiltersCount();

  // Tooltips (se estiver usando Bootstrap)
  if (typeof bootstrap !== 'undefined') {
    const tooltips = [].slice.call(document.querySelectorAll('[data-toggle="tooltip"]'));
    tooltips.map(tooltip => new bootstrap.Tooltip(tooltip));
  }

  // Atualizar nome do arquivo no formulário de importação
  const fileInput = document.getElementById('csv_file');
  if (fileInput) {
    fileInput.addEventListener('change', function() {
      const fileName = this.files[0] ? this.files[0].name : 'Nenhum arquivo selecionado';
      document.getElementById('file-name').textContent = fileName;
    });
  }
});
