# frozen_string_literal: true

require_dependency 'issue'
require_dependency 'settings_helper'

module FotonCashFlow
  module Patches
    module IssuePatch
      extend ActiveSupport::Concern

      included do
        include FotonCashFlow::SettingsHelper

        Rails.logger.info "[INFO][FOTON_CASH_FLOW][IssuePatch] Patch 'IssuePatch' incluído no modelo Issue."
        
        # --- SCOPES DE FILTRAGEM ---
        scope :by_cash_flow_cf_value, ->(cf_id, value) {
          Rails.logger.info "[DEBUG][FOTON_CASH_FLOW][IssuePatch] Scope by_cash_flow_cf_value chamado. cf_id: #{cf_id}, value: #{value}"
          joins(:custom_values).where(custom_values: { custom_field_id: cf_id, value: value })
        }

        scope :by_cash_flow_cf_value_like, ->(cf_id, value) {
          Rails.logger.info "[DEBUG][FOTON_CASH_FLOW][IssuePatch] Scope by_cash_flow_cf_value_like chamado. cf_id: #{cf_id}, value: #{value}"
          joins(:custom_values)
            .where(custom_values: { custom_field_id: cf_id })
            .where("LOWER(custom_values.value) LIKE ?", "%#{value.to_s.downcase}%")
        }

        scope :by_cash_flow_cf_date_range, ->(cf_id, from_date, to_date) {
          Rails.logger.info "[DEBUG][FOTON_CASH_FLOW][IssuePatch] Scope by_cash_flow_cf_date_range chamado. cf_id: #{cf_id}, from: #{from_date}, to: #{to_date}"
          query = joins(:custom_values).where(custom_values: { custom_field_id: cf_id })
          query = query.where("custom_values.value >= ?", from_date.to_s) if from_date.present?
          query = query.where("custom_values.value <= ?", to_date.to_s) if to_date.present?
          query
        }

        # Validação do tipo de tracker antes de aplicar as regras de negócio do plugin.
        def cash_flow_issue?
          # NOVO LOG: Mostra o ID do tracker atual e o ID esperado
          expected_tracker_id = FotonCashFlow::SettingsHelper.finance_tracker_id
          Rails.logger.info "[DEBUG][FOTON_CASH_FLOW][IssuePatch] cash_flow_issue? chamado. current_tracker_id: #{self.tracker_id}, expected_tracker_id: #{expected_tracker_id}"
          self.tracker_id == expected_tracker_id
        end

        # Métodos para acesso direto aos campos personalizados
        def cash_flow_transaction_type
          # NOVO LOG: Registra qual nome de campo personalizado está buscando
          field_name = FotonCashFlow::SettingsHelper::CUSTOM_FIELD_NAMES[:transaction_type]
          Rails.logger.info "[DEBUG][FOTON_CASH_FLOW][IssuePatch] Buscando custom field: '#{field_name}'"
          custom_field_value_by_name(field_name)
        end

        def cash_flow_amount
          field_name = FotonCashFlow::SettingsHelper::CUSTOM_FIELD_NAMES[:amount]
          Rails.logger.info "[DEBUG][FOTON_CASH_FLOW][IssuePatch] Buscando custom field: '#{field_name}'"
          value_str = custom_field_value_by_name(field_name)
          FotonCashFlow::SettingsHelper.parse_currency_to_decimal(value_str)
        end

        def cash_flow_category
          field_name = FotonCashFlow::SettingsHelper::CUSTOM_FIELD_NAMES[:category]
          Rails.logger.info "[DEBUG][FOTON_CASH_FLOW][IssuePatch] Buscando custom field: '#{field_name}'"
          custom_field_value_by_name(field_name)
        end

        def cash_flow_entry_date
          field_name = FotonCashFlow::SettingsHelper::CUSTOM_FIELD_NAMES[:entry_date]
          Rails.logger.info "[DEBUG][FOTON_CASH_FLOW][IssuePatch] Buscando custom field: '#{field_name}'"
          value_str = custom_field_value_by_name(field_name)
          return nil unless value_str.present?
          begin
            Time.zone.parse(value_str).to_date
          rescue ArgumentError
            nil
          end
        end

        def custom_field_value_by_name(field_name)
          custom_field = CustomField.find_by_name(field_name)
          # NOVO LOG: Registra o resultado da busca pelo nome do campo
          Rails.logger.info "[DEBUG][FOTON_CASH_FLOW][IssuePatch] custom_field_value_by_name - Resultado da busca por '#{field_name}': ID #{custom_field&.id || 'não encontrado'}"
          if custom_field
            value = self.custom_value_for(custom_field).try(:value)
            Rails.logger.info "[DEBUG][FOTON_CASH_FLOW][IssuePatch] custom_field_value_by_name: #{field_name} -> #{value.inspect}"
            value.to_s.strip
          else
            Rails.logger.info "[WARNING][FOTON_CASH_FLOW][IssuePatch] Campo personalizado '#{field_name}' não encontrado. Verifique as configurações do plugin."
            nil
          end
        end
        
        # --- CALLBACKS DO MODELO ---
        before_validation :set_entry_date_if_blank_from_params, on: :create
        validate :validate_cash_flow_custom_fields_from_params, if: :cash_flow_issue?
        validate :validate_entry_date_modification, if: :cash_flow_issue?
      end # included do

      private

      # Versão corrigida da função com acesso direto
      def set_entry_date_if_blank_from_params
        Rails.logger.info "[INFO][FOTON_CASH_FLOW][IssuePatch] [before_validation] set_entry_date_if_blank_from_params chamado."
        
        return unless cash_flow_issue? && self.new_record?
        
        Rails.logger.info "[INFO][FOTON_CASH_FLOW][IssuePatch] [before_validation] A issue é do tipo 'Fluxo de Caixa'. Verificando a data."

        date_cf = IssueCustomField.find_by(name: FotonCashFlow::SettingsHelper::CUSTOM_FIELD_NAMES[:entry_date])
        Rails.logger.info "[INFO][FOTON_CASH_FLOW][IssuePatch] [before_validation] Inspeção da data (date_cf): #{date_cf.inspect}"
        return unless date_cf

        # CORREÇÃO: Busca segura do valor
        custom_value = self.custom_value_for(date_cf.id)
        current_date_value = custom_value.value if custom_value

        Rails.logger.info "[DEBUG][FOTON_CASH_FLOW][IssuePatch] [before_validation] Valor da data de lançamento atual: '#{current_date_value.inspect}'"

        if current_date_value.blank?
          today_formatted = Time.zone.today.to_s
          Rails.logger.info "[DEBUG][FOTON_CASH_FLOW][IssuePatch] [before_validation] Data de lançamento vazia. Novo valor: '#{today_formatted}'."
          
          # CORREÇÃO: Atualização apropriada
          if custom_value
            custom_value.value = today_formatted
          else
            self.custom_field_values.build(custom_field_id: date_cf.id, value: today_formatted)
          end
        else
          Rails.logger.info "[INFO][FOTON_CASH_FLOW][IssuePatch] [before_validation] Campo 'Data de Lançamento' já possui valor."
        end
      rescue => e
        Rails.logger.error "[ERRO][FOTON_CASH_FLOW][IssuePatch] Erro em set_entry_date_if_blank_from_params: #{e.message}"
        errors.add(:base, "Erro ao preencher data de lançamento")
      end
      
      # Versão corrigida e unificada da validação, acessando os dados de forma segura
      def validate_cash_flow_custom_fields_from_params
        Rails.logger.info "[INFO][FOTON_CASH_FLOW][IssuePatch] Iniciando validação de custom fields para 'Financeiro'."
        
        # Acessa o hash de custom field values de forma segura, seja ele Hash ou Array
        cf_values = case self.custom_field_values
                    when Hash then self.custom_field_values
                    when Array then self.custom_field_values.each_with_object({}) { |cf, hash| hash[cf.custom_field_id.to_s] = cf.value }
                    else {}
                    end
        Rails.logger.info "[DEBUG][FOTON_CASH_FLOW][IssuePatch] Valores de Custom Fields processados para validação: #{cf_values.inspect}"

        # 1. Validação do campo 'Data do Lançamento'
        date_cf = IssueCustomField.find_by(name: FotonCashFlow::SettingsHelper::CUSTOM_FIELD_NAMES[:entry_date])
        Rails.logger.info "[INFO][FOTON_CASH_FLOW][IssuePatch] [before_validation] Inspeção da data (date_cf): #{date_cf.inspect}"
        if date_cf.present?
          entry_date_value = custom_value_for(date_cf)&.value.to_s.strip
          Rails.logger.debug "[DEBUG][FOTON_CASH_FLOW][IssuePatch] Validando Data do Lançamento (ID: #{date_cf.id}). Valor: '#{entry_date_value}'"
          
          if entry_date_value.blank?
            Rails.logger.warn "[ALERTA][FOTON_CASH_FLOW][IssuePatch]   - Erro: Data de Lançamento é obrigatória."
            errors.add(:base, "Data de Lançamento é obrigatória.")
          elsif entry_date_value !~ /^\d{4}-\d{2}-\d{2}$/
            Rails.logger.warn "[ALERTA][FOTON_CASH_FLOW][IssuePatch]   - Erro: Data de Lançamento em formato inválido. Valor: '#{entry_date_value}'"
            errors.add(:base, "Data de Lançamento em formato inválido.")
          end
        else
          Rails.logger.error "[ERRO][FOTON_CASH_FLOW][IssuePatch] Custom Field 'Data do Lançamento' não encontrado."
        end

        # 2. Validação do campo 'Valor'
        amount_cf = IssueCustomField.find_by(name: FotonCashFlow::SettingsHelper::CUSTOM_FIELD_NAMES[:amount])
        Rails.logger.info "[INFO][FOTON_CASH_FLOW][IssuePatch] [before_validation] Inspeção do Valor (amount_cf): #{amount_cf.inspect}"
        if amount_cf.present?
          amount_value = custom_value_for(amount_cf)&.value.to_s.strip
          Rails.logger.debug "[DEBUG][FOTON_CASH_FLOW][IssuePatch] Validando Valor (ID: #{amount_cf.id}). Valor: '#{amount_value}'"
          
          if amount_value.blank?
            Rails.logger.warn "[ALERTA][FOTON_CASH_FLOW][IssuePatch]   - Erro: O valor do lançamento é obrigatório."
            errors.add(:base, "O valor do lançamento é obrigatório.")
          else
            begin
              FotonCashFlow::SettingsHelper.parse_currency_to_decimal(amount_value)
            rescue => e
              Rails.logger.warn "[ALERTA][FOTON_CASH_FLOW][IssuePatch]   - Erro: Valor em formato inválido. Valor: '#{amount_value}'. Erro: #{e.message}"
              errors.add(:base, "Valor do lançamento em formato inválido.")
            end
          end
        else
          Rails.logger.error "[ERRO][FOTON_CASH_FLOW][IssuePatch] Custom Field 'Valor' não encontrado."
        end

        # 3. Validação do campo 'Tipo de Transação'
        transaction_type_cf = IssueCustomField.find_by(name: FotonCashFlow::SettingsHelper::CUSTOM_FIELD_NAMES[:transaction_type])
        Rails.logger.info "[INFO][FOTON_CASH_FLOW][IssuePatch] [before_validation] Inspeção do Tipo de transação (transaction_type_cf): #{transaction_type_cf.inspect}"
        if transaction_type_cf.present?
          transaction_type_value = custom_value_for(transaction_type_cf)&.value.to_s.strip
          Rails.logger.debug "[DEBUG][FOTON_CASH_FLOW][IssuePatch] Validando Tipo de Transação (ID: #{transaction_type_cf.id}). Valor: '#{transaction_type_value}'"
          
          unless %w[revenue expense].include?(transaction_type_value)
            Rails.logger.warn "[ALERTA][FOTON_CASH_FLOW][IssuePatch]   - Erro: Tipo de Transação inválido. Valor: '#{transaction_type_value}'"
            errors.add(:base, "Tipo de Transação inválido.")
          end
        else
          Rails.logger.error "[ERRO][FOTON_CASH_FLOW][IssuePatch] Custom Field 'Tipo de Transação' não encontrado."
        end

        # 4. Validação do campo 'Categoria'
        category_cf = IssueCustomField.find_by(name: FotonCashFlow::SettingsHelper::CUSTOM_FIELD_NAMES[:category])
        Rails.logger.info "[INFO][FOTON_CASH_FLOW][IssuePatch] [before_validation] Inspeção da categoria (category_cf): #{category_cf.inspect}"
        if category_cf.present?
          category_value = custom_value_for(category_cf)&.value.to_s.strip
          Rails.logger.debug "[DEBUG][FOTON_CASH_FLOW][IssuePatch] Validando Categoria (ID: #{category_cf.id}). Valor: '#{category_value}'"
          
          if category_cf.is_required? && category_value.blank?
            Rails.logger.warn "[ALERTA][FOTON_CASH_FLOW][IssuePatch]   - Erro: Categoria é obrigatória."
            errors.add(:base, "Categoria é obrigatória.")
          elsif category_value.present? && !category_cf.possible_values.include?(category_value)
            Rails.logger.warn "[ALERTA][FOTON_CASH_FLOW][IssuePatch]   - Erro: Categoria inválida. Valor: '#{category_value}'"
            errors.add(:base, "Categoria inválida.")
          end
        else
          Rails.logger.error "[ERRO][FOTON_CASH_FLOW][IssuePatch] Custom Field 'Categoria' não encontrado."
        end

        Rails.logger.info "[INFO][FOTON_CASH_FLOW][IssuePatch] Validação de custom fields concluída."
      end

      # O método validate_entry_date_modification não teve alterações significativas na lógica,
      # mas o log foi ajustado para maior clareza.
      def validate_entry_date_modification
        Rails.logger.info "[INFO][FOTON_CASH_FLOW][IssuePatch] [validate] Validando modificação da data de lançamento."
        
        entry_date_cf = IssueCustomField.find_by(name: FotonCashFlow::SettingsHelper::CUSTOM_FIELD_NAMES[:entry_date])
        Rails.logger.info "[INFO][FOTON_CASH_FLOW][IssuePatch] [before_validation] Inspeção da data inserida (entry_date_cf): #{entry_date_cf.inspect}"
        return unless entry_date_cf.present?
        
        Rails.logger.debug "[DEBUG][FOTON_CASH_FLOW][IssuePatch] [validate] ID do campo de data para validação de modificação: '#{entry_date_cf.id}'"
        
        custom_value = custom_value_for(entry_date_cf.id)
        
        if custom_value && custom_value.value_changed? && custom_value.value_was.present?
          Rails.logger.info "[DEBUG][FOTON_CASH_FLOW][IssuePatch] [validate] Data alterada de #{custom_value.value_was} para #{custom_value.value}"
          unless User.current.allowed_to?(:edit_cash_flow_entry_date, project)
            errors.add(:base, "Você não tem permissão para alterar a data de lançamento.")
            Rails.logger.warn "[ALERTA][FOTON_CASH_FLOW][IssuePatch] [validate] Usuário #{User.current.login} tentou alterar data sem permissão."
          end
        end
      end

    end
  end
end

# Fim do arquivo inssue_patch.rb