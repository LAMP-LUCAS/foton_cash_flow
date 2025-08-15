# frozen_string_literal: true

#plugins/foton_cash_flow/lib/foton_cash_flow/patches/issue_custom_field_patch.rb

require_dependency 'custom_field'

module FotonCashFlow
  module Patches
    module IssueCustomFieldPatch
      extend ActiveSupport::Concern

      included do
        # Torna os novos atributos "safe" para serem atribuídos em massa,
        # uma boa prática de segurança do Redmine.
        safe_attributes 'min_value', 'max_value'
      end
    end
  end
end