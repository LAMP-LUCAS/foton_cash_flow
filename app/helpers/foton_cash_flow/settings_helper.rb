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
          tracker: finance_tracker, role: role, old_status: status_new, new_status: status_in_progress
        )
        WorkflowTransition.find_or_create_by!(
          tracker: finance_tracker, role: role, old_status: status_new, new_status: status_rejected
        )

        # Transições a partir de 'Em Andamento'
        WorkflowTransition.find_or_create_by!(
          tracker: finance_tracker, role: role, old_status: status_in_progress, new_status: status_feedback
        )
        WorkflowTransition.find_or_create_by!(
          tracker: finance_tracker, role: role, old_status: status_in_progress, new_status: status_resolved
        )
        WorkflowTransition.find_or_create_by!(
          tracker: finance_tracker, role: role, old_status: status_in_progress, new_status: status_rejected
        )

        # Transições a partir de 'Feedback'
        WorkflowTransition.find_or_create_by!(
          tracker: finance_tracker, role: role, old_status: status_feedback, new_status: status_in_progress
        )
        WorkflowTransition.find_or_create_by!(
          tracker: finance_tracker, role: role, old_status: status_feedback, new_status: status_resolved
        )
        WorkflowTransition.find_or_create_by!(
          tracker: finance_tracker, role: role, old_status: status_feedback, new_status: status_rejected
        )

        # Transições de Reabertura (de status finalizados para 'Em Andamento')
        WorkflowTransition.find_or_create_by!(
          tracker: finance_tracker, role: role, old_status: status_resolved, new_status: status_in_progress
        )
        WorkflowTransition.find_or_create_by!(
          tracker: finance_tracker, role: role, old_status: status_rejected, new_status: status_in_progress
        )
      end
      Rails.logger.info "[DEBUG][SETTINGS_HELPER] Fluxo de trabalho do Tracker '#{finance_tracker.name}' configurado manualmente."


      # 3. Assegurar Custom Fields
      # ------------------------------------------------------------------
      EXPECTED_CUSTOM_FIELD_ATTRIBUTES.each do |cf_name, attrs|
        key = CUSTOM_FIELD_NAMES.key(cf_name)

        custom_field = IssueCustomField.find_or_initialize_by(name: cf_name) do |cf|
          cf.field_format = attrs[:field_format]
          cf.is_required = attrs[:is_required]
          cf.min_length = attrs[:min_length] if attrs[:min_length].present?
          cf.position = attrs[:position] if attrs[:position].present?
          cf.is_filter = attrs[:is_filter] if attrs[:is_filter].present?
          cf.editable = true # Por padrão, os campos são editáveis
          cf.visible = true  # Por padrão, os campos são visíveis
        end

        # Atualiza atributos que podem mudar ou que não são definidos na inicialização
        custom_field.field_format = attrs[:field_format]
        custom_field.is_required = attrs[:is_required]
        custom_field.min_length = attrs[:min_length] if attrs[:min_length].present?
        custom_field.position = attrs[:position] if attrs[:position].present?
        custom_field.is_filter = attrs[:is_filter] if attrs[:is_filter].present?


        if attrs[:field_format] == 'list'
          case key
          when :category
            categories_from_settings_raw = Setting.plugin_foton_cash_flow['categories']

            # Normaliza as categorias das configurações: garante que seja um array de strings.
            actual_categories_from_settings = if categories_from_settings_raw.is_a?(Array)
                                                categories_from_settings_raw.map do |c|
                                                  c.is_a?(Hash) && c.key?('name') ? c['name'] : c.to_s
                                                end.compact.presence
                                              else
                                                nil
                                              end

            # Usa categorias das settings se presentes, caso contrário, usa as padrão.
            final_possible_values = actual_categories_from_settings || DEFAULT_CATEGORIES.dup

            # Garante que possible_values nunca seja um array completamente vazio para campos de lista (validação Redmine)
            # Redmine exige que possible_values seja um array de strings.
            custom_field.possible_values = final_possible_values.map(&:to_s).any? ? final_possible_values.map(&:to_s) : [""]
            Rails.logger.info "[DEBUG][SETTINGS_HELPER] Custom Field '#{cf_name}' (Key: #{key}) carregado com categorias: #{custom_field.possible_values.inspect}"
          else
            # Para outros campos de lista, usa os valores possíveis definidos em EXPECTED_CUSTOM_FIELD_ATTRIBUTES
            # Garante que os valores sejam strings e que não seja um array vazio real para o Redmine
            custom_field.possible_values = (attrs[:possible_values] || []).map(&:to_s).any? ? (attrs[:possible_values] || []).map(&:to_s) : [""]
            Rails.logger.info "[DEBUG][SETTINGS_HELPER] Custom Field '#{cf_name}' (Key: #{key}) é um tipo lista, usando valores de atributos esperados ou padrão vazio."
          end

          # Define default_value para campos de lista obrigatórios se ainda não tiver um
          if custom_field.is_required && custom_field.possible_values.any? && custom_field.default_value.blank?
            custom_field.default_value = custom_field.possible_values.first
          end
        end

        if custom_field.save
          Rails.logger.info "[DEBUG][SETTINGS_HELPER] Custom Field '#{cf_name}' (ID: #{custom_field.id}, Key: #{key}) ensured."
          Setting.plugin_foton_cash_flow["#{key}_custom_field_id"] = custom_field.id
        else
          Rails.logger.error "[ERROR][SETTINGS_HELPER] Failed to save Custom Field '#{cf_name}': #{custom_field.errors.full_messages.join(', ')}"
          return false
        end

        # Associar o Custom Field ao Tracker Financeiro
        unless finance_tracker.custom_fields.include?(custom_field)
          finance_tracker.custom_fields << custom_field
          # Não precisa finance_tracker.save aqui se os custom_fields forem associados diretamente.
          # A associação já salva implicitamente ao adicionar ao `has_many`.
          # Mas se ocorrer um erro de validação no tracker por causa do CF, pode falhar silenciosamente.
          # É mais seguro, se o tracker_custom_field estiver envolvido, salvar o Tracker.
          # Por simplicidade, assumimos que adicionar ao array é suficiente para a relação.
        end
      end

      # Não é necessário chamar Setting.plugin_foton_cash_flow.save explicitamente,
      # pois as atribuições individuais já persistem as configurações.
      Rails.logger.info "[DEBUG][SETTINGS_HELPER] foton_cash_flow plugin settings updated."

      true # Indica sucesso
    rescue => e
      Rails.logger.error "[ERROR][SETTINGS_HELPER] Erro durante a sincronização de dependências: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      false # Indica falha
    end

    # Método para obter um CF ID de forma fácil em qualquer lugar
    def self.cf_id(key)
      Setting.plugin_foton_cash_flow["#{key}_custom_field_id"]&.to_i
    end

    def self.finance_tracker_id
      Setting.plugin_foton_cash_flow['finance_tracker_id']&.to_i
    end

    # Método para obter os valores possíveis de um Custom Field
    def self.custom_field_possible_values(key)
      cf_id_val = cf_id(key)
      return [] unless cf_id_val.present?
      CustomField.find_by(id: cf_id_val)&.possible_values || []
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error "[SETTINGS_HELPER] Custom Field com ID #{cf_id_val} não encontrado para a chave #{key}: #{e.message}"
      []
    end

    # Método para obter a lista de objetos CustomField relevantes para os formulários
    def self.cash_flow_custom_fields_for_form
      cf_ids = CUSTOM_FIELD_NAMES.keys.map { |key| cf_id(key) }.compact
      CustomField.where(id: cf_ids).compact.sort_by(&:position)
    end

    # Método para verificar se todas as dependências essenciais estão configuradas
    def self.all_dependencies_met?
      internal_finance_project_id.present? &&
      finance_tracker_id.present? &&
      cf_id(:entry_date).present? &&
      cf_id(:amount).present? &&
      cf_id(:transaction_type).present? &&
      cf_id(:category).present?
    end

    # Método para obter o ID do projeto financeiro interno, se configurado
    def self.internal_finance_project_id
      Setting.plugin_foton_cash_flow['internal_finance_project_id']&.to_i
    end

    # Novo método para obter os atributos esperados de um CF pelo nome do CF
    def self.expected_custom_field_attributes_for(cf_name)
      EXPECTED_CUSTOM_FIELD_ATTRIBUTES[cf_name.to_s] || {} # Retorna um hash vazio se não encontrado
    end

  end
end

# Fim do arquivo settings_helper.rb
