# ./app/controllers/foton_cash_flow/diagnostics_controller.rb

module FotonCashFlow
  class DiagnosticsController < ApplicationController
    before_action :require_admin
    before_action :authorize_cash_flow_settings_management # Nova permissão

    layout 'admin' # Ou 'base' se preferir o layout padrão do Redmine

    def index
      @diagnostic_results = check_dependencies_status
      Rails.logger.info "[DIAGNOSTICS] Diagnostic Results: #{@diagnostic_results.inspect}" # Adicionado para logar os resultados completos
    end

    def run_sync
      result = sync_dependencies_now

      if result[:success]
        flash[:notice] = l(:notice_cash_flow_sync_success)
        Rails.logger.info "[DIAGNOSTICS] Sync successful."
      else
        flash[:error] = l(:error_cash_flow_sync_failure, message: result[:message])
        Rails.logger.error "[DIAGNOSTICS] Sync failed: #{result[:message]}"
      end

      # --- Lógica de redirecionamento ---
      # Redireciona para a página de entradas do fluxo de caixa
      # se o parâmetro `redirect_to_entries` estiver presente e for true.
      if params[:redirect_to_entries] == 'true'
        # O `redirect_back` é a melhor opção para voltar à página anterior
        # de forma segura e robusta.
        redirect_back(fallback_location: project_cash_flow_entries_path(project_id: params[:project_id]), notice: flash[:notice], error: flash[:error])
      else
        # Comportamento padrão: redireciona para a página de diagnósticos.
        redirect_to foton_cash_flow_diagnostics_path
      end
      # -------------------------------------------
    end

    private

    # Método para verificar o status das dependências necessárias para o funcionamento do módulo
    #
    # Realiza verificações em 3 áreas principais:
    # 1. Projeto financeiro padrão
    # 2. Tracker financeiro (tipo de tarefa)
    # 3. Campos personalizados (custom fields)
    #
    # Retorna um hash estruturado com:
    # - Status individual de cada componente
    # - Problemas detectados
    # - Status geral de todas as dependências
    def check_dependencies_status
      Rails.logger.info "[DIAGNOSTICS][check_dependencies_status] Iniciando verificação de dependências."

      results = {
        project_present: false,
        project_id: nil,
        tracker_present: false,
        tracker_id: nil,
        tracker_associated_with_project: false,
        tracker_workflow_configured: false,
        custom_fields: {},
        missing_custom_fields: [],
        incorrectly_configured_fields: [],
        all_dependencies_met: false # Será definido no final
      }

      # 1. VERIFICAR PROJETO FINANCEIRO
      # ------------------------------------------------------------------
      finance_project = Project.find_by(identifier: FotonCashFlow::SettingsHelper::FINANCE_PROJECT_IDENTIFIER)
      if finance_project
        results[:project_present] = true
        results[:project_id] = finance_project.id
        Rails.logger.info "[DIAGNOSTICS] Projeto '#{FotonCashFlow::SettingsHelper::FINANCE_PROJECT_NAME}' encontrado (ID: #{finance_project.id})."
      else
        Rails.logger.warn "[DIAGNOSTICS] Projeto '#{FotonCashFlow::SettingsHelper::FINANCE_PROJECT_NAME}' não encontrado."
      end

      # 2. VERIFICAR TRACKER FINANCEIRO
      # ------------------------------------------------------------------
      finance_tracker = Tracker.find_by(name: FotonCashFlow::SettingsHelper::FINANCE_TRACKER_NAME)
      if finance_tracker
        results[:tracker_present] = true
        results[:tracker_id] = finance_tracker.id
        Rails.logger.info "[DIAGNOSTICS] Tracker '#{FotonCashFlow::SettingsHelper::FINANCE_TRACKER_NAME}' encontrado (ID: #{finance_tracker.id})."

        # 2.1. Verificar associação do tracker com o projeto
        if results[:project_present] && finance_project.trackers.include?(finance_tracker)
          results[:tracker_associated_with_project] = true
          Rails.logger.info "[DIAGNOSTICS] Tracker '#{finance_tracker.name}' associado ao projeto '#{finance_project.name}'."
        else
          Rails.logger.warn "[DIAGNOSTICS] Tracker '#{finance_tracker.name}' NÃO associado ao projeto '#{finance_project&.name || 'Nenhum projeto encontrado'}'."
        end

        # 2.2. Verificar configuração do fluxo de trabalho do tracker (simplificado)
        # Uma verificação mais robusta poderia checar a existência de transições específicas
        # Por enquanto, verificamos se há *alguma* regra de fluxo de trabalho para este tracker e alguma role.
        # Poderíamos iterar sobre as roles e verificar se há transições.
        # Para um diagnóstico mais profundo:
        # Check if there's at least one workflow rule for each default role and status combination
        # This is a basic check. A full check would verify all expected transitions.

        # Verificar se existem regras de transição para o tracker
        if WorkflowTransition.where(tracker_id: finance_tracker.id).exists?
            results[:tracker_workflow_configured] = true
            Rails.logger.info "[DIAGNOSTICS] Fluxo de trabalho para o Tracker '#{finance_tracker.name}' parece configurado."
        else
            results[:tracker_workflow_configured] = false
            Rails.logger.warn "[DIAGNOSTICS] Fluxo de trabalho para o Tracker '#{finance_tracker.name}' NÃO configurado. Nenhuma transição encontrada."
        end

      else
        Rails.logger.warn "[DIAGNOSTICS] Tracker '#{FotonCashFlow::SettingsHelper::FINANCE_TRACKER_NAME}' não encontrado."
      end


      # 3. VERIFICAR CUSTOM FIELDS
      # ------------------------------------------------------------------
      FotonCashFlow::SettingsHelper::EXPECTED_CUSTOM_FIELD_ATTRIBUTES.each do |cf_name, expected_attrs|
        cf_status = { present: false, configured_correctly: true, details: [] }
        custom_field = IssueCustomField.find_by(name: cf_name) # Usar IssueCustomField
        Rails.logger.info "[DIAGNOSTICS] Verificando Custom Field: '#{cf_name}'"

        if custom_field
          cf_status[:present] = true
          Rails.logger.info "[DIAGNOSTICS]   - Presente (ID: #{custom_field.id}). Verificando atributos..."

          # Verificar field_format
          if expected_attrs[:field_format] && custom_field.field_format != expected_attrs[:field_format]
            cf_status[:configured_correctly] = false
            cf_status[:details] << l(:text_cash_flow_cf_details_wrong_format,
                                    expected: expected_attrs[:field_format], actual: custom_field.field_format)
            Rails.logger.warn "[DIAGNOSTICS]     - Formato incorreto para '#{cf_name}': Esperado '#{expected_attrs[:field_format]}', Atual '#{custom_field.field_format}'."
          end

          # Verificar is_required
          if expected_attrs[:is_required] && custom_field.is_required != expected_attrs[:is_required]
            cf_status[:configured_correctly] = false
            cf_status[:details] << l(:text_cash_flow_cf_details_wrong_required,
                                    expected: expected_attrs[:is_required], actual: custom_field.is_required)
            Rails.logger.warn "[DIAGNOSTICS]     - Obrigatório incorreto para '#{cf_name}': Esperado '#{expected_attrs[:is_required]}', Atual '#{custom_field.is_required}'."
          end

          # Verificar posição (opcional, mas bom para consistência)
          if expected_attrs[:position] && custom_field.position != expected_attrs[:position]
            # Isso pode ser um aviso, não necessariamente um erro que impeça o funcionamento
            cf_status[:details] << l(:text_cash_flow_cf_details_wrong_position,
                                    expected: expected_attrs[:position], actual: custom_field.position)
            Rails.logger.warn "[DIAGNOSTICS]     - Posição incorreta para '#{cf_name}': Esperado '#{expected_attrs[:position]}', Atual '#{custom_field.position}'."
          end

          # Verificação especial para campos do tipo lista (como 'Tipo de Transação' e 'Categoria')
          if custom_field.field_format == 'list'
            key = FotonCashFlow::SettingsHelper::CUSTOM_FIELD_NAMES.key(cf_name) # Obtém a chave do custom field (:category, :transaction_type)

            expected_values = if key == :category
              categories_from_settings_raw = Setting.plugin_foton_cash_flow['categories']
              actual_categories_from_settings = if categories_from_settings_raw.is_a?(Array)
                                                  categories_from_settings_raw.map do |c|
                                                    c.is_a?(Hash) && c.key?('name') ? c['name'] : c.to_s
                                                  end.compact.presence
                                                else
                                                  nil
                                                end
              actual_categories_from_settings || FotonCashFlow::SettingsHelper::DEFAULT_CATEGORIES.dup
            else
              expected_attrs[:possible_values] || []
            end

            actual_values = custom_field.possible_values.map(&:to_s).sort
            expected_values_sorted = expected_values.map(&:to_s).sort

            Rails.logger.info "[DIAGNOSTICS]     - CF '#{cf_name}' (Tipo Lista):"
            Rails.logger.info "[DIAGNOSTICS]       - Valores Esperados: #{expected_values_sorted.inspect}"
            Rails.logger.info "[DIAGNOSTICS]       - Valores Atuais: #{actual_values.inspect}"

            # Aprimoramento da comparação para lidar com o caso de um array vazio vs. array com string vazia
            if (actual_values == [""] && expected_values_sorted.empty?) || (actual_values != expected_values_sorted)
              cf_status[:configured_correctly] = false
              cf_status[:details] << l(:text_cash_flow_cf_details_wrong_possible_values,
                                      expected: expected_values_sorted.any? ? expected_values_sorted.join(', ') : l(:text_cash_flow_none),
                                      actual: actual_values.any? ? actual_values.join(', ') : l(:text_cash_flow_none))
              Rails.logger.warn "[DIAGNOSTICS]     - Valores possíveis incorretos para '#{cf_name}'."
            else
              Rails.logger.info "[DIAGNOSTICS]     - Valores possíveis para '#{cf_name}' OK."
            end
          else
            Rails.logger.info "[DIAGNOSTICS]     - CF '#{cf_name}' não é do tipo lista, pulando verificação de valores possíveis."
          end

          if !cf_status[:configured_correctly]
            results[:incorrectly_configured_fields] << cf_name
          end
        else
          cf_status[:present] = false
          cf_status[:configured_correctly] = false # Se não está presente, não está configurado corretamente
          cf_status[:details] << l(:text_cash_flow_cf_details_missing)
          results[:missing_custom_fields] << cf_name
          Rails.logger.warn "[DIAGNOSTICS]   - Custom Field '#{cf_name}' NÃO encontrado."
        end

        results[:custom_fields][cf_name] = cf_status
      end

      # 4. RESULTADOS CONSOLIDADOS
      # ------------------------------------------------------------------
      results[:all_custom_fields_present] = results[:missing_custom_fields].empty?
      results[:all_custom_fields_configured_correctly] = results[:incorrectly_configured_fields].empty?
      
      # Status geral considera todas as dependências
      results[:all_dependencies_met] = 
        results[:project_present] &&
        results[:tracker_present] &&
        results[:tracker_associated_with_project] &&
        results[:tracker_workflow_configured] &&
        results[:all_custom_fields_present] &&
        results[:all_custom_fields_configured_correctly]

      Rails.logger.info "[DIAGNOSTICS][check_dependencies_status] Verificação de dependências concluída."
      Rails.logger.info "[DIAGNOSTICS] Status Geral das Dependências: #{results[:all_dependencies_met] ? 'MET' : 'NOT MET'}."
      results
    end
    
    # Método para tentar criar/re-sincronizar as dependências
    def sync_dependencies_now
      begin
        Rails.logger.info "[DIAGNOSTICS][sync_dependencies_now] Iniciando sincronização de dependências."
        # Agora, chamamos diretamente o método no SettingsHelper
        success = FotonCashFlow::SettingsHelper.load_custom_field_ids_into_settings
        if success
          Rails.logger.info "[DIAGNOSTICS][sync_dependencies_now] Sincronização concluída com sucesso."
        else
          Rails.logger.error "[DIAGNOSTICS][sync_dependencies_now] Sincronização falhou no SettingsHelper."
        end
        { success: success }
      rescue => e
        Rails.logger.error "[DIAGNOSTICS][sync_dependencies_now] Erro durante a sincronização de dependências: #{e.message}"
        Rails.logger.error "[DIAGNOSTICS][sync_dependencies_now] Backtrace: #{e.backtrace.join("\n")}"
        { success: false, message: e.message }
      end
    end

    # Nova permissão para gerenciar as configurações do fluxo de caixa
    def authorize_cash_flow_settings_management
      unless User.current.allowed_to?(:manage_cash_flow_settings, nil, global: true)
        deny_access
      end
    end
  end
end