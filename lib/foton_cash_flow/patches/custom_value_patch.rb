# frozen_string_literal: true

# plugins/foton_cash_flow/lib/foton_cash_flow/patches/issue_custom_value_patch.rb

require_dependency 'custom_value'

module FotonCashFlow
  module Patches
    module CustomValuePatch
      extend ActiveSupport::Concern

      included do
        # A validação de min/max foi removida para simplificar o plugin.
        # Se desejar reativá-la, descomente a linha abaixo e garanta
        # que a migração de banco de dados foi executada.
        # validate :validate_min_max_value
      end
    end
  end
end