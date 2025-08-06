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
    DEFAULT_CATEGORIES = ['Arquitetos', 'Engenheiros', 'Construtoras', 'Empresas'].freeze

    # Atributos esperados para os Custom Fields, incluindo valores possíveis
    # Esta constante centraliza as definições para validação e criação.
    EXPECTED_CUSTOM_FIELD_ATTRIBUTES = {
      CUSTOM_FIELD_NAMES[:entry_date] => {
        field_format: 'date', is_required: true, position: 1
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
      finance_project.is_public = false # Geralmente projetos financeiros não são públicos
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
        cf = CustomField.find_or_initialize_by(name: name)
        attributes = EXPECTED_CUSTOM_FIELD_ATTRIBUTES[name]
        
        cf.field_format = attributes[:field_format]
        cf.is_required = attributes[:is_required]
        cf.position = attributes[:position]

        if attributes[:field_format] == 'list'
          cf.possible_values = attributes[:possible_values]
        end

        # Associar o CF ao Tracker financeiro
        cf.trackers << finance_tracker unless cf.trackers.include?(finance_tracker)

        cf.save!
        Rails.logger.info "[DEBUG][SETTINGS_HELPER] Custom Field '#{cf.name}' (ID: #{cf.id}) criado/assegurado."

        # Salvar o ID do CF nas configurações do plugin para fácil acesso
        Setting.plugin_foton_cash_flow["cf_#{key}_id"] = cf.id
      end

      # 4. Assegurar a Role 'Fluxo de Caixa'
      # ------------------------------------------------------------------
      cash_flow_role = Role.find_or_create_by!(name: 'Fluxo de Caixa') do |role|
        role.permissions = [:view_cash_flow, :add_cash_flow_entries, :edit_cash_flow_entries, :delete_cash_flow_entries, :manage_cash_flow_settings]
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
        { required: true, possible_values: ['Arquitetos', 'Engenheiros', 'Construtoras', 'Empresas'] }
      else
        {}
      end
    end



    # -----------------------------------------------------------------
    # MÉTODOS DE AJUDA
    # -----------------------------------------------------------------
    
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
    
    def self.cf_id(key)
      Setting.plugin_foton_cash_flow["cf_#{key}_id"]
    end
    
    def self.finance_tracker_id
      Setting.plugin_foton_cash_flow['finance_tracker_id']
    end

    def self.internal_finance_project_id
      Setting.plugin_foton_cash_flow['internal_finance_project_id']
    end

    def self.all_dependencies_met?
      Rails.logger.info "[DEBUG][SETTINGS_HELPER] Verificando se todas as dependências foram atendidas."
      
      expected_dependencies = [:entry_date, :amount, :transaction_type, :category]
      dependencies_met = expected_dependencies.all? do |key|
        cf_id = Setting.plugin_foton_cash_flow["cf_#{key}_id"]
        cf_id.present? && CustomField.exists?(id: cf_id)
      end

      dependencies_met &= Setting.plugin_foton_cash_flow['finance_tracker_id'].present? && Tracker.exists?(id: Setting.plugin_foton_cash_flow['finance_tracker_id'])
      dependencies_met &= Setting.plugin_foton_cash_flow['internal_finance_project_id'].present? && Project.exists?(id: Setting.plugin_foton_cash_flow['internal_finance_project_id'])

      Rails.logger.info "[DEBUG][SETTINGS_HELPER] Dependências atendidas: #{dependencies_met}"
      dependencies_met
    end
  end
end