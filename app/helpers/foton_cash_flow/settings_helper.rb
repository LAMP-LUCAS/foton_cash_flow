# ./app/helpers/foton_cash_flow/settings_helper.rb

module FotonCashFlow
  module SettingsHelper
    # Nomes dos Custom Fields que seu plugin espera
    CUSTOM_FIELD_NAMES = {
      entry_date: 'Data do Lançamento',
      amount: 'Valor',
      transaction_type: 'Tipo de Transação',
      category: 'Categoria'
    }.freeze

    # Nome do Tracker financeiro
    FINANCE_TRACKER_NAME = 'Financeiro'.freeze

    # Identificador do projeto financeiro padrão
    FINANCE_PROJECT_IDENTIFIER = 'financeiro'.freeze
    FINANCE_PROJECT_NAME = 'Financeiro'.freeze

    # Lista de categorias padrão para o campo 'Categoria'.
    # Esta lista será usada se o usuário não tiver configurado categorias personalizadas
    # e pode ser modificada futuramente nas configurações do plugin.
    DEFAULT_CATEGORIES = [
                        '# Custos Diretos',
                          'Mão de Obra Direta',
                          'Materiais de Construção',
                          'Serviços de Terceiros e Subempreiteiros',
                          'Equipamentos e Máquinas',
                        '# Custos Indiretos',
                          'Mão de Obra Indireta',
                          'Despesas de Escritório',
                          'Despesas Administrativas',
                          'Marketing e Vendas',
                        '# Custos de Obras',
                          'Canteiro de Obras',
                          'Mobilização e Desmobilização',
                          'Licenças e Alvarás',
                        '# Custos Financeiros e de Capital',
                          'Juros e Encargos Financeiros',
                          'Seguros',
                        '# Impostos e Tributos',
                          'Impostos Diretos',
                          'Impostos Indiretos',
                          '---------------------',
                        '# Receita de Prestação de Serviços',
                          'Projetos e Consultoria',
                          'Gestão de Obras',
                          'Serviços de Engenharia',
                          'Serviços de Construção',
                        '# Receita de Venda de Produtos',
                          'Venda de Imóveis',
                          'Venda de Materiais',
                          'Licenças de Software e Produtos Digitais',
                        '# Receita de Royalties e Licenciamento',
                          'Licenciamento de Projetos',
                          'Royalties',
                        '# Receita de Investimentos',
                          'Rendimentos Financeiros',
                          'Aluguel de Equipamentos',
                          'Participação em Projetos',

    ].freeze

    # Atributos esperados para os Custom Fields, incluindo valores possíveis
    # Esta constante centraliza as definições para validação e criação.
    EXPECTED_CUSTOM_FIELD_ATTRIBUTES = {
      CUSTOM_FIELD_NAMES[:entry_date] => {
        field_format: 'date', is_required: false, position: 1
      },
      CUSTOM_FIELD_NAMES[:amount] => {
        field_format: 'float', is_required: true, position: 2
      },
      CUSTOM_FIELD_NAMES[:transaction_type] => {
        field_format: 'list',
        possible_values: ['revenue', 'expense'],
        is_required: true,
        is_filter: true,
        position: 3
      },
      CUSTOM_FIELD_NAMES[:category] => {
        field_format: 'list',
        possible_values: DEFAULT_CATEGORIES.dup,
        is_required: false,
        is_filter: true,
        position: 4
      }
    }.freeze

    # Nomes dos status de tarefa padrão que queremos para o workflow do Financeiro
    STATUS_FILTERS = ['Nova', 'Em Andamento', 'Feedback', 'Resolvida', 'Rejeitada'].freeze
    STATUS_NEW, STATUS_IN_PROGRESS, STATUS_FEEDBACK, STATUS_RESOLVED, STATUS_REJECTED = STATUS_FILTERS

    # Método para carregar IDs dos custom fields nas settings do plugin.
    # Garante que os custom fields esperados existam e estejam configurados corretamente.
    def self.load_custom_field_ids_into_settings
      Rails.logger.info "[DEBUG][SETTINGS_HELPER] Iniciando load_custom_field_ids_into_settings"

      # 1. Assegurar Projeto 'Financeiro'
      # ------------------------------------------------------------------
      finance_project = Project.find_or_initialize_by(identifier: FINANCE_PROJECT_IDENTIFIER)
      finance_project.name = FINANCE_PROJECT_NAME
      finance_project.is_public = false

      # Lógica para habilitar o módulo do seu plugin no projeto
      # Verifique o nome do módulo no seu arquivo init.rb para ter certeza
      unless finance_project.enabled_module_names.include?('foton_cash_flow')
        finance_project.enabled_module_names << 'foton_cash_flow'
      end

      finance_project.save!
      Rails.logger.info "[DEBUG][SETTINGS_HELPER] Projeto '#{finance_project.name}' criado/assegurado."
      Setting.plugin_foton_cash_flow['internal_finance_project_id'] = finance_project.id
      Rails.logger.info "[DEBUG][SETTINGS_HELPER] Projeto '#{finance_project.name}' (ID: #{finance_project.id}) assegurado."

      # 2. Assegurar Tracker 'Financeiro'
      # ------------------------------------------------------------------
      finance_tracker = Tracker.find_or_initialize_by(name: FINANCE_TRACKER_NAME)
      if finance_tracker.new_record?
        finance_tracker.name = FINANCE_TRACKER_NAME
        finance_tracker.default_status = IssueStatus.first # Define um status padrão temporário
        finance_tracker.description = "Tracker para gestão de lançamentos financeiros do plugin Foton Cash Flow."
        #finance_tracker.is_in_chlog = false
        finance_tracker.is_in_roadmap = false
        finance_tracker.position = Tracker.maximum(:position).to_i + 1
      end
      finance_tracker.save!
      Rails.logger.info "[DEBUG][SETTINGS_HELPER] Tracker '#{finance_tracker.name}' criado."
      Setting.plugin_foton_cash_flow['finance_tracker_id'] = finance_tracker.id
      Rails.logger.info "[DEBUG][SETTINGS_HELPER] Tracker '#{finance_tracker.name}' (ID: #{finance_tracker.id}) assegurado."

      # 2.1. Associar Tracker ao Projeto
      # ------------------------------------------------------------------
      unless finance_project.trackers.include?(finance_tracker)
        finance_project.trackers << finance_tracker
        finance_project.save!
        Rails.logger.info "[DEBUG][SETTINGS_HELPER] Tracker '#{finance_tracker.name}' associado ao Projeto '#{finance_project.name}'."
      end

      # 2.2. Definir fluxo de trabalho para 'Financeiro' (NOVA ESTRATÉGIA)
      # ------------------------------------------------------------------
      Rails.logger.info "[DEBUG][SETTINGS_HELPER] Definindo fluxo de trabalho para Tracker '#{finance_tracker.name}'."

      # Obter os IssueStatus. Criá-los se não existirem (embora geralmente existam no Redmine padrão)
      status_new = IssueStatus.find_or_create_by!(name: STATUS_NEW) do |s|
        s.is_default = true unless IssueStatus.exists?(is_default: true) # Apenas um padrão
        s.position = IssueStatus.maximum(:position).to_i + 1
      end
      status_in_progress = IssueStatus.find_or_create_by!(name: STATUS_IN_PROGRESS) do |s|
        s.is_closed = false
        s.position = IssueStatus.maximum(:position).to_i + 1
      end
      status_feedback = IssueStatus.find_or_create_by!(name: STATUS_FEEDBACK) do |s|
        s.is_closed = false
        s.position = IssueStatus.maximum(:position).to_i + 1
      end
      status_resolved = IssueStatus.find_or_create_by!(name: STATUS_RESOLVED) do |s|
        s.is_closed = true
        s.position = IssueStatus.maximum(:position).to_i + 1
      end
      status_rejected = IssueStatus.find_or_create_by!(name: STATUS_REJECTED) do |s|
        s.is_closed = true
        s.position = IssueStatus.maximum(:position).to_i + 1
      end

      # Definir o status padrão do tracker (se não estiver definido ou for um temporário)
      if finance_tracker.default_status.nil? || finance_tracker.default_status != status_new
        finance_tracker.default_status = status_new
        finance_tracker.save!
      end

      # Limpar regras de fluxo de trabalho existentes para evitar duplicação ou conflitos
      # CORREÇÃO: Destrua as WorkflowRules e WorkflowTransitions diretamente relacionadas ao tracker.
      WorkflowRule.where(tracker_id: finance_tracker.id).destroy_all
      WorkflowTransition.where(tracker_id: finance_tracker.id).destroy_all


      # Obter todas as roles (papéis) para aplicar o workflow
      roles = Role.all

      roles.each do |role|
        Rails.logger.info "[DEBUG][SETTINGS_HELPER] Configurando fluxo de trabalho para o papel: #{role.name}"

        # Transições a partir de 'Nova'
        WorkflowTransition.find_or_create_by!(
          tracker: finance_tracker,
          role: role,
          old_status: status_new,
          new_status: status_in_progress
        )
        WorkflowTransition.find_or_create_by!(
          tracker: finance_tracker,
          role: role,
          old_status: status_new,
          new_status: status_rejected
        )
        # Transições a partir de 'Em Andamento'
        WorkflowTransition.find_or_create_by!(
          tracker: finance_tracker,
          role: role,
          old_status: status_in_progress,
          new_status: status_feedback
        )
        WorkflowTransition.find_or_create_by!(
          tracker: finance_tracker,
          role: role,
          old_status: status_in_progress,
          new_status: status_resolved
        )
        WorkflowTransition.find_or_create_by!(
          tracker: finance_tracker,
          role: role,
          old_status: status_in_progress,
          new_status: status_rejected
        )
        # Transições a partir de 'Feedback'
        WorkflowTransition.find_or_create_by!(
          tracker: finance_tracker,
          role: role,
          old_status: status_feedback,
          new_status: status_in_progress
        )
        WorkflowTransition.find_or_create_by!(
          tracker: finance_tracker,
          role: role,
          old_status: status_feedback,
          new_status: status_resolved
        )
        WorkflowTransition.find_or_create_by!(
          tracker: finance_tracker,
          role: role,
          old_status: status_feedback,
          new_status: status_rejected
        )
        # Transições de Reabertura (de status finalizados para 'Em Andamento')
        WorkflowTransition.find_or_create_by!(
          tracker: finance_tracker,
          role: role,
          old_status: status_resolved,
          new_status: status_in_progress
        )
        WorkflowTransition.find_or_create_by!(
          tracker: finance_tracker,
          role: role,
          old_status: status_rejected,
          new_status: status_in_progress
        )
      end

      # 3. Assegurar Custom Fields
      # ------------------------------------------------------------------
      Rails.logger.info "[DEBUG][SETTINGS_HELPER] Iniciando verificação dos custom fields."

      CUSTOM_FIELD_NAMES.each do |key, name|
        cf = IssueCustomField.find_or_initialize_by(name: name)
        attributes = EXPECTED_CUSTOM_FIELD_ATTRIBUTES[name]
        
        cf.field_format = attributes[:field_format]
        cf.is_required = attributes[:is_required]
        cf.position = attributes[:position]
        cf.is_filter = attributes[:is_filter] if attributes[:is_filter] # Linha importante para campos de filtro
        
        if attributes[:field_format] == 'list'
          possible_values = attributes[:possible_values]
          
          if key == :category
            configured_categories = Setting.plugin_foton_cash_flow['categories']
            
            if configured_categories.present?
              if configured_categories.is_a?(Array)
                possible_values = configured_categories.map do |c|
                  c.is_a?(Hash) ? c['name'] : c
                end
              else
                possible_values = configured_categories.split(',').map(&:strip).reject(&:blank?)
              end
            else
              possible_values = DEFAULT_CATEGORIES.dup
            end

          elsif key == :entry_date
            cf.is_required = true
          end
          
          # Garantia final para evitar que a lista de valores seja vazia
          cf.possible_values = possible_values.presence || DEFAULT_CATEGORIES.dup
        end        
        
        begin
          cf.save!
          
          unless cf.trackers.include?(finance_tracker)
            cf.trackers << finance_tracker
            cf.save!
            Rails.logger.info "[DEBUG][SETTINGS_HELPER] Custom Field '#{cf.name}' associado ao Tracker '#{finance_tracker.name}'."
          end
          
          Rails.logger.info "[DEBUG][SETTINGS_HELPER] Custom Field '#{cf.name}' (ID: #{cf.id}) criado/assegurado."
          Setting.plugin_foton_cash_flow["cf_#{key}_id"] = cf.id
        rescue ActiveRecord::RecordInvalid => e
          Rails.logger.error "[FOTON_CASH_FLOW] Erro ao salvar Custom Field '#{name}': #{e.message}"
          raise e
        end
      end

      # 4. Assegurar a Role 'Fluxo de Caixa'
      # ------------------------------------------------------------------
      cash_flow_role = Role.find_or_initialize_by(name: 'Fluxo de Caixa')
      permissions = [
        :view_cash_flow,
        :add_cash_flow_entries,
        :edit_cash_flow_entries,
        :delete_cash_flow_entries,
        :manage_cash_flow_settings,
        :edit_cash_flow_entry_date # NOVA PERMISSÃO
      ]
      
      if cash_flow_role.new_record?
        cash_flow_role.permissions = permissions
        cash_flow_role.save!
      else
        # Adiciona a nova permissão se não existir
        current_permissions = cash_flow_role.permissions
        unless current_permissions.include?(:edit_cash_flow_entry_date)
          cash_flow_role.permissions = current_permissions + [:edit_cash_flow_entry_date]
          cash_flow_role.save!
        end
      end
      
      Rails.logger.info "[DEBUG][SETTINGS_HELPER] Role 'Fluxo de Caixa' (ID: #{cash_flow_role.id}) criada/assegurada."
      Setting.plugin_foton_cash_flow['cash_flow_role_id'] = cash_flow_role.id

      Rails.logger.info "[DEBUG][SETTINGS_HELPER] load_custom_field_ids_into_settings concluído."
    end
    
    def self.expected_custom_field_attributes_for(field_key)
      # Implementação que retorna os atributos esperados para cada campo
      case field_key
      when :entry_date
        { required: true, format: :date }
      when :amount
        { required: true, format: :currency }
      when :transaction_type
        { required: true, possible_values: ['expense', 'revenue'] }
      when :category
        { required: true, possible_values: ['Custos Fixos', 'Custos Variáveis', 'Receitas Fixas', 'Receitas Variáveis','Impostos e Tributos'] }
      else
        {}
      end
    end

    # -----------------------------------------------------------------
    # MÉTODOS DE AJUDA
    # -----------------------------------------------------------------
    
    # Método para obter o ID do Custom Field de forma segura
    def self.cf_id(key)
      name = CUSTOM_FIELD_NAMES[key]
      custom_field = IssueCustomField.find_by(name: name)
      
      if custom_field
        Rails.logger.debug "[DEBUG][SETTINGS_HELPER] cf_id(#{key}) - Custom Field '#{name}' encontrado com ID: #{custom_field.id}"
        custom_field.id
      else
        Rails.logger.warn "[ALERTA][SETTINGS_HELPER] cf_id(#{key}) - Custom Field '#{name}' não encontrado. Verifique a configuração do plugin. Retornando nil."
        nil
      end
    end
    
    # Método para obter o ID do Tracker de forma segura
    def self.finance_tracker_id
      tracker = Tracker.find_by(name: FINANCE_TRACKER_NAME)
      
      if tracker
        Rails.logger.debug "[DEBUG][SETTINGS_HELPER] finance_tracker_id - Tracker '#{FINANCE_TRACKER_NAME}' encontrado com ID: #{tracker.id}"
        tracker.id
      else
        Rails.logger.warn "[ALERTA][SETTINGS_HELPER] finance_tracker_id - Tracker '#{FINANCE_TRACKER_NAME}' não encontrado. Verifique a configuração do plugin. Retornando nil."
        nil
      end
    end

    # Método para obter o ID do Projeto de forma segura
    def self.internal_finance_project_id
      project = Project.find_by(identifier: FINANCE_PROJECT_IDENTIFIER)
      
      if project
        Rails.logger.debug "[DEBUG][SETTINGS_HELPER] internal_finance_project_id - Projeto '#{FINANCE_PROJECT_NAME}' encontrado com ID: #{project.id}"
        project.id
      else
        Rails.logger.warn "[ALERTA][SETTINGS_HELPER] internal_finance_project_id - Projeto '#{FINANCE_PROJECT_NAME}' não encontrado. Verifique a configuração do plugin. Retornando nil."
        nil
      end
    end

    def self.all_dependencies_met?
      Rails.logger.info "[DEBUG][SETTINGS_HELPER] Verificando se todas as dependências foram atendidas."
      
      dependencies_met = true
      
      # Verificação do Projeto
      if internal_finance_project_id.nil?
        Rails.logger.error "[FOTON_CASH_FLOW][ERRO] Projeto Financeiro não encontrado."
        dependencies_met = false
      end

      # Verificação do Tracker
      if finance_tracker_id.nil?
        Rails.logger.error "[FOTON_CASH_FLOW][ERRO] Tracker Financeiro não encontrado."
        dependencies_met = false
      end

      # Verificação dos Custom Fields
      CUSTOM_FIELD_NAMES.each do |key, name|
        if cf_id(key).nil?
          Rails.logger.error "[FOTON_CASH_FLOW][ERRO] Custom Field '#{name}' não encontrado."
          dependencies_met = false
        end
      end
      
      Rails.logger.info "[DEBUG][SETTINGS_HELPER] Dependências atendidas: #{dependencies_met}"
      dependencies_met
    end

    # Método para converter uma string de moeda no formato BR para BigDecimal de forma robusta
    def self.parse_currency_to_decimal(value_str)
      return BigDecimal('0.0') if value_str.blank?
      
      # Remove caracteres não numéricos exceto vírgula, ponto e sinal negativo
      sanitized_str = value_str.to_s.gsub(/[^\d,\-\.]/, '')
      
      # Se houver vírgula e ponto, mantém apenas o último como separador decimal
      if sanitized_str.count(',') > 0 && sanitized_str.count('.') > 0
        if sanitized_str.rindex(',') > sanitized_str.rindex('.')
          sanitized_str.gsub!('.', '') # Remove pontos (milhares)
        else
          sanitized_str.gsub!(',', '') # Remove vírgulas (milhares)
        end
      end
      
      # Substitui a vírgula por ponto se for o separador decimal
      sanitized_str.gsub!(',', '.') if sanitized_str.count(',') == 1
      
      # Converte para BigDecimal
      BigDecimal(sanitized_str)
    rescue => e
      Rails.logger.error "[FOTON_CASH_FLOW] Erro ao converter valor: #{value_str} - #{e.message}"
      BigDecimal('0.0')
    end

    # Novo método de log para diagnóstico
    def self.check_plugin_dependencies_log(parameters = nil)
      Rails.logger.info "--- [DIAGNÓSTICO DO PLUGIN FOTON CASH FLOW] ---"
      
      # Log dos parâmetros recebidos (se fornecido)
      if parameters
        Rails.logger.info "--- Parâmetros Recebidos ---"
        Rails.logger.info "  - Tracker ID: #{parameters.dig('issue', 'tracker_id')}"
        Rails.logger.info "  - Custom Field Values: #{parameters.dig('issue', 'custom_field_values').inspect}"
      end
      
      # Log do Banco de Dados
      Rails.logger.info "--- Configuração do Banco de Dados ---"
      
      project = Project.find_by(identifier: FINANCE_PROJECT_IDENTIFIER)
      project_status = project.present? ? "ENCONTRADO (ID: #{project.id})" : "NÃO ENCONTRADO"
      Rails.logger.info "  - Projeto Financeiro (Identificador: '#{FINANCE_PROJECT_IDENTIFIER}'): #{project_status}"

      tracker = Tracker.find_by(name: FINANCE_TRACKER_NAME)
      tracker_status = tracker.present? ? "ENCONTRADO (ID: #{tracker.id})" : "NÃO ENCONTRADO"
      Rails.logger.info "  - Tracker Financeiro (Nome: '#{FINANCE_TRACKER_NAME}'): #{tracker_status}"

      Rails.logger.info "--- Custom Fields e seus IDs ---"
      CUSTOM_FIELD_NAMES.each do |key, name|
        cf = IssueCustomField.find_by(name: name)
        cf_status = cf.present? ? "OK (ID: #{cf.id}, Posição: #{cf.position})" : "FALHA - Não encontrado"
        Rails.logger.info "  - Campo '#{name}': #{cf_status}"
      end
      
      Rails.logger.info "--- FIM DO DIAGNÓSTICO ---"
    end
    
  end
end