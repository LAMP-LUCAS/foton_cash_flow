# frozen_string_literal: true

# plugins/foton_cash_flow/lib/foton_cash_flow/patches/issue_patch.rb

require_dependency 'issue'
require_dependency 'settings_helper'

module FotonCashFlow
  module Patches
    
    module IssuePatch
      extend ActiveSupport::Concern

      included do
        include FotonCashFlow::SettingsHelper
        
        # Log para confirmar a inclusão do patch
        Rails.logger.info "[FOTON_CASH_FLOW][IssuePatch] IssuePatch incluído no modelo Issue."

        
        validate :validate_cash_flow_custom_fields, if: :cash_flow_issue?

        # --- SCOPES PARA FILTRAGEM DE CUSTOM FIELDS ---
        # Estes scopes permitirão que CashFlowQueryBuilder construa queries complexas.

        # Scope genérico para filtrar por um custom field_id e um valor exato
        scope :by_cash_flow_cf_value, ->(cf_id, value) {
          Rails.logger.debug "[FOTON_CASH_FLOW][IssuePatch] Scope by_cash_flow_cf_value chamado com cf_id: #{cf_id}, value: #{value}"
          joins(:custom_values).where(custom_values: { custom_field_id: cf_id, value: value })
        }

        # Scope para filtrar por um custom field_id com LIKE (case-insensitive)
        scope :by_cash_flow_cf_value_like, ->(cf_id, value) {
          Rails.logger.debug "[FOTON_CASH_FLOW][IssuePatch] Scope by_cash_flow_cf_date_range chamado com cf_id: #{cf_id}, from: #{from_date}, to: #{to_date}"
          joins(:custom_values)
            .where(custom_values: { custom_field_id: cf_id })
            .where("LOWER(custom_values.value) LIKE ?", "%#{value.to_s.downcase}%)")
        }

        # Scope para filtrar por um custom field_id de data em um range
        scope :by_cash_flow_cf_date_range, ->(cf_id, from_date, to_date) {
          Rails.logger.debug "[FOTON_CASH_FLOW][IssuePatch] Scope by_cash_flow_cf_date_range chamado com cf_id: #{cf_id}, from: #{from_date}, to: #{to_date}"
          query = joins(:custom_values).where(custom_values: { custom_field_id: cf_id })
          query = query.where("custom_values.value >= ?", from_date.to_s) if from_date.present?
          query = query.where("custom_values.value <= ?", to_date.to_s) if to_date.present?
          query
        }

        # Validar se a issue é um lançamento de fluxo de caixa
        def cash_flow_issue?
          Rails.logger.debug "[FOTON_CASH_FLOW][IssuePatch] Verificando se é uma issue de fluxo de caixa. tracker_id: #{tracker_id}, finance_tracker_id: #{FotonCashFlow::SettingsHelper.finance_tracker_id}"
          tracker_id == FotonCashFlow::SettingsHelper.finance_tracker_id
        end

        # Métodos para acesso direto aos campos personalizados
        def cash_flow_transaction_type
          value = custom_field_value_by_name(FotonCashFlow::SettingsHelper::CUSTOM_FIELD_NAMES[:transaction_type])
          Rails.logger.debug "[FOTON_CASH_FLOW][IssuePatch] cash_flow_transaction_type para Issue ID #{id}: #{value.inspect}"
          value
        end

        def cash_flow_amount
          value_str = custom_field_value_by_name(FotonCashFlow::SettingsHelper::CUSTOM_FIELD_NAMES[:amount])
          parsed_amount = FotonCashFlow::SettingsHelper.parse_currency_to_decimal(value_str)
          Rails.logger.debug "[FOTON_CASH_FLOW][IssuePatch] cash_flow_amount para Issue ID #{id}: #{value_str.inspect} -> #{parsed_amount.inspect}"
          parsed_amount
        end

        def cash_flow_category
          value = custom_field_value_by_name(FotonCashFlow::SettingsHelper::CUSTOM_FIELD_NAMES[:category])
          Rails.logger.debug "[FOTON_CASH_FLOW][IssuePatch] cash_flow_category para Issue ID #{id}: #{value.inspect}"
          value
        end

        def cash_flow_entry_date
          value = custom_field_value_by_name(FotonCashFlow::SettingsHelper::CUSTOM_FIELD_NAMES[:entry_date])
          Rails.logger.debug "[FOTON_CASH_FLOW][IssuePatch] cash_flow_entry_date para Issue ID #{id}: #{value.inspect}"
          value
        end

        def cash_flow_status
          value = custom_field_value_by_name(FotonCashFlow::SettingsHelper::CUSTOM_FIELD_NAMES[:status])
          Rails.logger.debug "[FOTON_CASH_FLOW][IssuePatch] cash_flow_status para Issue ID #{id}: #{value.inspect}"
          value
        end

        def cash_flow_author
          value = custom_field_value_by_name(FotonCashFlow::SettingsHelper::CUSTOM_FIELD_NAMES[:author])
          Rails.logger.debug "[FOTON_CASH_FLOW][IssuePatch] cash_flow_author para Issue ID #{id}: #{value.inspect}"
          value
        end

        # Helper para obter o valor de um campo personalizado pelo nome
        def custom_field_value_by_name(field_name)
          custom_field = CustomField.find_by_name(field_name)
          if custom_field
            value = custom_value_for(custom_field).try(:value)
            Rails.logger.debug "[FOTON_CASH_FLOW][IssuePatch] custom_field_value_by_name: #{field_name} -> #{value.inspect}"
            value
          else
            Rails.logger.warn "[FOTON_CASH_FLOW][IssuePatch] Campo personalizado '#{field_name}' não encontrado."
            nil
          end
        end
      end # included do

      # Validação dos campos personalizados de fluxo de caixa
      def validate_cash_flow_custom_fields
        Rails.logger.info "[FOTON_CASH_FLOW][IssuePatch] Executando validação de custom fields para Issue ID #{id}."

        # Validação do tipo de transação
        transaction_type_cf_id = FotonCashFlow::SettingsHelper.cf_id(:transaction_type)
        if transaction_type_cf_id
          transaction_type_value = get_custom_field_value(transaction_type_cf_id)
          Rails.logger.debug "[FOTON_CASH_FLOW][IssuePatch] Validação - Tipo de Transação: #{transaction_type_value.inspect}"
          unless %w[revenue expense].include?(transaction_type_value)
            errors.add(:base, l(:error_cf_transaction_type_invalid))
          end
        end

        # Validação do valor (amount)
        amount_cf_id = FotonCashFlow::SettingsHelper.cf_id(:amount)
        if amount_cf_id
          amount_value = get_custom_field_value(amount_cf_id)
          parsed_amount = FotonCashFlow::SettingsHelper.parse_currency_to_decimal(amount_value)
          
          # Se a string original estiver em branco, `parsed_amount` será '0.0',
          # mas não queremos permitir lançamentos vazios. Por isso, a verificação
          # `amount_value.present?` é essencial.
          if amount_value.present?
            if parsed_amount.nil? || parsed_amount <= 0
              errors.add(:base, l(:error_cf_amount_invalid))
            end
          else
            # Caso o campo seja obrigatório (is_required), o Redmine já lida
            # com a validação de presença. Mas, se não for, esta validação aqui
            # garante que não aceitamos valores vazios como válidos.
            errors.add(:base, l(:error_cf_amount_invalid)) unless amount_cf_id.present? && CustomField.find(amount_cf_id).is_required == false
          end
        end

        # Validação da data de lançamento
        entry_date_cf_id = FotonCashFlow::SettingsHelper.cf_id(:entry_date)
        if entry_date_cf_id
          entry_date_value = get_custom_field_value(entry_date_cf_id)
          Rails.logger.debug "[FOTON_CASH_FLOW][IssuePatch] Validação - Data de Lançamento: #{entry_date_value.inspect}"
          begin
            Date.parse(entry_date_value) if entry_date_value.present?
          rescue ArgumentError
            errors.add(:base, l(:error_cf_entry_date_invalid))
          end
        end

        # Validação da Categoria (se for custom field tipo lista e tiver valores definidos)
        category_cf_id = FotonCashFlow::SettingsHelper.cf_id(:category)
        if category_cf_id
          category_value = get_custom_field_value(category_cf_id)
          expected_category_attrs = FotonCashFlow::SettingsHelper.expected_custom_field_attributes_for(FotonCashFlow::SettingsHelper::CUSTOM_FIELD_NAMES[:category])

          # Se a categoria é requerida e está em branco
          if expected_category_attrs[:is_required] && category_value.blank?
            errors.add(:base, l(:error_cf_category_required))
          end

          # Se há valores de categoria e o valor atual não está entre os possíveis (e não está em branco)
          if category_value.present? && expected_category_attrs[:possible_values].present? && !expected_category_attrs[:possible_values].include?(category_value)
              # Esta parte pode precisar de ajuste, pois 'Categoria' obtém valores de `Setting.plugin_foton_cash_flow['categories']`
              # O SettingsHelper já lida com isso em custom_field_possible_values
              available_categories = FotonCashFlow::SettingsHelper.custom_field_possible_values(:category)
              unless available_categories.include?(category_value)
                errors.add(:base, l(:error_cf_category_invalid_value))
              end
          end
        end
      end

      # Método auxiliar para obter o valor de um custom field de forma segura
      def get_custom_field_value(cf_id)
        custom_field_values.detect { |v| v.custom_field_id == cf_id }.try(:value)
      end
    end

  end
end

# Fim do arquivo issue_patch.rb
