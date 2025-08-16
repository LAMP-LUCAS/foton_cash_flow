# frozen_string_literal: true

# plugins/foton_cash_flow/lib/foton_cash_flow/patches/issue_custom_value_patch.rb

require_dependency 'custom_value'

module FotonCashFlow
  module Patches
    module CustomValuePatch
      extend ActiveSupport::Concern

      included do
        # Adiciona uma nova validação que será chamada antes de salvar o valor.
        validate :validate_min_max_value
      end

      private

      def validate_min_max_value
        # A validação só se aplica se houver um valor e um campo personalizado associado.
        return if value.blank? || custom_field.nil?

        # A validação só deve ocorrer para campos numéricos (float ou int).
        return unless %w[float int].include?(custom_field.field_format)

        # Tenta converter o valor para um número decimal. Se falhar, a validação padrão do Redmine pegará o erro.
        begin
          value_as_decimal = FotonCashFlow::SettingsHelper.parse_currency_to_decimal(value)
          return if value_as_decimal.nil?
        rescue
          return
        end

        # Verifica o valor mínimo, se estiver definido no campo personalizado.
        if custom_field.min_value.present? && value_as_decimal < custom_field.min_value
          errors.add(:base, I18n.t('activerecord.errors.messages.greater_than_or_equal_to',
                                   field: custom_field.name,
                                   count: custom_field.min_value))
        end

        # Verifica o valor máximo, se estiver definido no campo personalizado.
        if custom_field.max_value.present? && value_as_decimal > custom_field.max_value
          errors.add(:base, I18n.t('activerecord.errors.messages.less_than_or_equal_to',
                                   field: custom_field.name,
                                   count: custom_field.max_value))
        end
      end
    end
  end
end