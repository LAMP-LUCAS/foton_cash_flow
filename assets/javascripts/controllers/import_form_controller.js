// Garante que o namespace global e o de controllers existam.
window.FotonCashFlow = window.FotonCashFlow || {};
window.FotonCashFlow.Controllers = window.FotonCashFlow.Controllers || {};

/**
 * Controlador para a página de importação de lançamentos.
 * Gerencia o formulário, o modal de conciliação e as chamadas AJAX.
 */
class ImportFormController {
  constructor(container) {
    this.container = container;
    this.dataKey = null; // Armazena a chave do arquivo cacheado
    this.i18n = JSON.parse(this.container.dataset.i18n || '{}');

    this._bindElements();
    this._bindEvents();
  }

  /**
   * Encontra e armazena referências para os elementos do DOM.
   * @private
   */
  _bindElements() {
    this.importForm = this.container.querySelector('#import-form');
    this.fileInput = this.container.querySelector('#csv_file');
    this.fileNameSpan = this.container.querySelector('#file-name');
    this.submitBtn = this.container.querySelector('#import-submit-btn');

    // Elementos do Modal
    this.modal = document.getElementById('reconciliation-modal');
    this.modalBody = document.getElementById('reconciliation-body');
    this.spinner = this.modal.querySelector('.cf-spinner');
    this.finalizeBtn = document.getElementById('finalize-import-btn');
    this.cancelBtn = document.getElementById('cancel-reconciliation-btn');
    this.closeBtn = this.modal.querySelector('.cf-modal-close-btn');
  }

  /**
   * Adiciona os event listeners aos elementos.
   * @private
   */
  _bindEvents() {
    // MUDANÇA: Em vez de ouvir o 'submit' do formulário, ouvimos o 'click' do botão.
    // Isso nos dá controle total e evita conflitos com outros scripts do Redmine.
    this.submitBtn.addEventListener('click', this._handleFormSubmit.bind(this));
    this.fileInput.addEventListener('change', this._handleFileChange.bind(this));
    this.finalizeBtn.addEventListener('click', this._handleFinalizeImport.bind(this));
    this.cancelBtn.addEventListener('click', this._hideModal.bind(this));
    this.closeBtn.addEventListener('click', this._hideModal.bind(this));
  }

  /**
   * Lida com a mudança do input de arquivo para exibir o nome.
   * @private
   */
  _handleFileChange(e) {
    const noFileText = this.fileNameSpan.dataset.noFileSelected;
    this.fileNameSpan.textContent = e.target.files[0] ? e.target.files[0].name : noFileText;
  }

  /**
   * Intercepta o envio do formulário para a pré-análise.
   * @private
   */
  async _handleFormSubmit(e) {
    // O preventDefault() não é estritamente necessário para um botão type="button",
    // mas é uma boa prática para garantir que nada inesperado aconteça.
    e.preventDefault(); 
    if (!this.fileInput.files[0]) {
      alert(this.importForm.dataset.noFileError);
      return;
    }

    this._setLoading(true);
    const formData = new FormData(this.importForm);

    try {
      const response = await fetch(this.importForm.action, {
        method: 'POST',
        body: formData,
        headers: {
          'X-CSRF-Token': document.querySelector("meta[name=csrf-token]").content,
          'Accept': 'application/json'
        }
      });

      const result = await response.json();

      if (result.redirect_url) {
        window.location.href = result.redirect_url;
      } else if (result.conflicts && result.conflicts.length > 0) {
        console.log('[FOTON_CASH_FLOW] Conflitos recebidos:', result.conflicts);
        this.dataKey = result.data_key;
        this._renderConflicts(result.conflicts);
        this._setLoading(false, { showModal: true });
      } else {
        this._setLoading(false);
        alert(result.error || this.t('unexpected_response'));
      }
    } catch (error) {
      this._setLoading(false);
      console.error('Erro na requisição de pré-análise:', error);
      alert(this.t('communication_error'));
    }
  }

  /**
   * Coleta as resoluções e envia para a finalização da importação.
   * @private
   */
  // async _handleFinalizeImport() {
  //   this._setLoading(true, { keepModalOpen: true }); // Mostra o spinner no modal

  //   // **CORREÇÃO CRÍTICA:** Coleta as resoluções no formato hierárquico que o backend espera.
  //   // Ex: { "category": { "Categoria Antiga": "Nova Categoria" } }
  //   const resolutions = Array.from(this.modalBody.querySelectorAll('[name^="resolution_"]'))
  //     .reduce((acc, select) => {
  //       const columnKey = select.dataset.columnKey;
  //       const invalidValue = select.dataset.invalidValue;
  //       if (columnKey && invalidValue) {
  //         // Garante que o objeto para a coluna exista
  //         acc[columnKey] = acc[columnKey] || {};
  //         acc[columnKey][invalidValue] = select.value;
  //       }
  //       return acc;
  //     }, {});
  //   console.log('[FOTON_CASH_FLOW] Enviando resoluções:', resolutions);

  //   // Agora que os dados foram coletados, pode mostrar o spinner com segurança.
  //   this._setLoading(true, { keepModalOpen: true }); 

  //   try {
  //     const response = await fetch(this.finalizeBtn.dataset.finalizeUrl, {
  //       method: 'POST',
  //       body: JSON.stringify({ data_key: this.dataKey, resolutions: resolutions }),
  //       headers: {
  //         'Content-Type': 'application/json',
  //         'X-CSRF-Token': document.querySelector("meta[name=csrf-token]").content,
  //         'Accept': 'application/json'
  //       }
  //     });
  //     const result = await response.json();

  //     if (result.redirect_url) {
  //       window.location.href = result.redirect_url;
  //     } else {
  //       this._setLoading(false, { showModal: true }); 
  //       this._renderConflicts(result.conflicts || []); // Re-renderiza os conflitos se houver
  //       alert(result.error || this.t('finalization_error'));
  //     }
  //   } catch (error) {
  //     this._setLoading(false, { showModal: true }); // Mantenha o modal aberto
  //     console.error('Erro ao finalizar:', error);
  //     alert(this.t('communication_error'));
  //   }
  // }

  async _handleFinalizeImport() {
    console.log('%c[FOTON_CASH_FLOW_DEBUG] 1. A função _handleFinalizeImport foi iniciada.', 'color: blue; font-weight: bold;');

    const resolutions = {};
    // Busca todos os elementos <select> dentro do corpo do modal que são para resolução de conflitos.
    const selectElements = this.modalBody.querySelectorAll('[name^="resolution_"]');

    console.log(`[FOTON_CASH_FLOW_DEBUG] 2. Foram encontrados ${selectElements.length} elementos <select> no modal.`);

    // Se nenhum <select> for encontrado, é um sinal claro de que o DOM não está pronto ou o seletor está errado.
    if (selectElements.length === 0) {
        alert('Erro de Depuração (Passo 2): Nenhum controle de resolução (<select>) foi encontrado no modal. A coleta de dados falhará. Verifique o console para mais detalhes.');
    }

    // Itera sobre cada <select> encontrado.
    selectElements.forEach((select, index) => {
        const columnKey = select.dataset.columnKey;
        const invalidValue = select.dataset.invalidValue;
        const selectedValue = select.value;

        // Loga os detalhes de cada <select> para depuração.
        console.log(`%c[FOTON_CASH_FLOW_DEBUG] 3. Processando <select> #${index}:`, 'color: green;');
        console.log(`    - data-column-key: ${columnKey}`);
        console.log(`    - data-invalid-value: ${invalidValue}`);
        console.log(`    - valor selecionado: ${selectedValue}`);

        if (columnKey && invalidValue) {
            if (!resolutions[columnKey]) {
                resolutions[columnKey] = {};
            }
            resolutions[columnKey][invalidValue] = selectedValue;
            console.log(`    - ✅ Adicionado ao objeto resolutions.`);
        } else {
            console.log(`    - ❌ IGNORADO: data-column-key ou data-invalid-value está faltando.`);
        }
    });

    console.log('%c[FOTON_CASH_FLOW_DEBUG] 4. Objeto final de resoluções ANTES do envio:', 'color: blue; font-weight: bold;', resolutions);
    
    // Mostra o spinner somente após a coleta dos dados.
    this._setLoading(true, { keepModalOpen: true });

    try {
      const response = await fetch(this.finalizeBtn.dataset.finalizeUrl, {
        method: 'POST',
        body: JSON.stringify({ data_key: this.dataKey, resolutions: resolutions }),
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector("meta[name=csrf-token]").content,
          'Accept': 'application/json'
        }
      });
      const result = await response.json();

      if (result.redirect_url) {
        window.location.href = result.redirect_url;
      } else {
        this._setLoading(false);
        alert(result.error || this.t('finalization_error'));
      }
    } catch (error) {
      this._setLoading(false);
      console.error('Erro ao finalizar:', error);
      alert(this.t('communication_error'));
    }
  }

  /**
   * Renderiza os conflitos no corpo do modal de forma segura.
   * @param {Array} conflicts - A lista de conflitos retornada pelo backend.
   * @private
   */
  _renderConflicts(conflicts) {
    this.modalBody.innerHTML = ''; // Limpa o corpo do modal

    const groupedConflicts = conflicts.reduce((acc, conflict) => {
      const key = `${conflict.column_name}|${conflict.error_type}`;
      if (!acc[key]) {
        acc[key] = { title: conflict.column_name, type: conflict.error_type, items: [] };
      }
      acc[key].items.push(conflict);
      return acc;
    }, {});

    for (const key in groupedConflicts) {
      const group = groupedConflicts[key];
      const groupDiv = this._createElement('div', { className: 'conflict-group' });
      
      const groupTitle = this._createElement('h4');
      groupTitle.textContent = this.t('conflict_title', { column: group.title });
      groupDiv.appendChild(groupTitle);

      group.items.forEach(item => {
        const itemDiv = this._buildConflictItem(item);
        groupDiv.appendChild(itemDiv);
      });
      this.modalBody.appendChild(groupDiv);
    }
  }

  /**
   * Constrói o HTML para um único item de conflito.
   * @param {object} item - O objeto de conflito.
   * @returns {HTMLElement} - O elemento div do item.
   * @private
   */
  _buildConflictItem(item) {
    console.log('[FOTON_CASH_FLOW] Renderizando item de conflito:', item);
    const itemDiv = this._createElement('div', { className: 'conflict-item' });

    // Adiciona a linha de dados brutos para dar contexto ao usuário.
    if (item.raw_row) {
      const rawDataContainer = this._createElement('div', { className: 'conflict-raw-data' });
      rawDataContainer.textContent = Array.isArray(item.raw_row) ? item.raw_row.join(' | ') : item.raw_row;
      itemDiv.appendChild(rawDataContainer);
    }

    itemDiv.appendChild(this._createElement('span', { textContent: this.t('line_label', { number: item.row_number }) }));
    
    const valueSpan = this._createElement('span', { className: 'value' });
    valueSpan.textContent = item.invalid_value || '';
    itemDiv.appendChild(valueSpan);

    itemDiv.appendChild(this._createElement('span', { textContent: this.t('arrow') }));

    const resolutionDiv = this._createElement('div', { className: 'resolution-control' });
    if (item.error_type === 'value_not_in_list') {
      const select = this._createElement('select', { className: 'cf-input' });
      select.name = `resolution_${item.id}`;
      // **CORREÇÃO:** Adiciona data-attributes com a chave canônica (e.g., 'category') para que a coleta de resoluções funcione.
      select.dataset.columnKey = item.column_key;
      select.dataset.invalidValue = item.invalid_value;
      
      const createOption = this._createElement('option', { value: 'create_new' });
      createOption.textContent = this.t('create_new_option', { value: item.invalid_value });
      select.appendChild(createOption);

      item.resolution_options.forEach(opt => select.appendChild(this._createElement('option', { value: opt, textContent: opt })));
      resolutionDiv.appendChild(select);
    } else {
      // **MELHORIA:** Exibe a mensagem de erro específica vinda do backend.
      const errorMessageSpan = this._createElement('span', { className: 'conflict-error-message' });
      errorMessageSpan.textContent = item.message || this.t('action_needed');
      resolutionDiv.appendChild(errorMessageSpan);
    }
    itemDiv.appendChild(resolutionDiv);
    return itemDiv;
  }

  /**
   * Helper simples de tradução que usa as strings passadas pelo data-attribute.
   * @param {string} key - A chave da tradução.
   * @param {object} interpolations - Substituições para a string.
   */
  t(key, interpolations = {}) {
    let text = this.i18n[key] || key;
    Object.keys(interpolations).forEach(k => text = text.replace(`%{${k}}`, interpolations[k]));
    return text;
  }

  _setLoading(isLoading, options = {}) {
    this.submitBtn.disabled = isLoading;
    this.finalizeBtn.disabled = isLoading;

    if (isLoading) {
      this.modalBody.innerHTML = ''; // Limpa o conteúdo para mostrar o spinner
      this.spinner.style.display = 'block';
      if (!options.keepModalOpen) {
        this._showModal();
      }
    } else {
      this.spinner.style.display = 'none';
      if (!options.showModal) {
        this._hideModal();
      }
    }
  }

  _showModal() { this.modal.style.display = 'flex'; }
  _hideModal() { this.modal.style.display = 'none'; }

  /**
   * Helper para criar elementos DOM de forma segura.
   * @param {string} tag - A tag do elemento (ex: 'div').
   * @param {object} options - Opções como className, textContent, etc.
   * @returns {HTMLElement}
   * @private
   */
  _createElement(tag, options = {}) {
    const el = document.createElement(tag);
    Object.keys(options).forEach(key => {
      el[key] = options[key];
    });
    return el;
  }
}

window.FotonCashFlow.Controllers.ImportFormController = ImportFormController;
