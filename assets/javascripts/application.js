// plugins/foton_cash_flow/assets/javascripts/application.js

document.addEventListener('DOMContentLoaded', function() {
  // Verificação inicial via AJAX
  if (document.querySelector('#new_cash_flow_entry')) {
    Rails.ajax({
      url: window.location.pathname,
      type: 'GET',
      dataType: 'json',
      headers: { 'X-Requested-With': 'XMLHttpRequest' },
      success: function(response) {
        if (response.modal) {
          document.body.insertAdjacentHTML('beforeend', response.modal);
          $('#no-projects-modal').modal('show');
        }
      }
    });
  }

  // Atualização do projeto selecionado
  const projectSelect = document.querySelector('#selected_project');
  if (projectSelect) {
    projectSelect.addEventListener('change', function() {
      const projectId = this.value;
      // Atualiza o formulário com o novo projeto
      document.querySelector('#issue_project_id').value = projectId;
    });
  }
});