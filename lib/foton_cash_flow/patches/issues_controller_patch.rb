# plugins/foton_cash_flow/lib/foton_cash_flow/patches/issues_controller_patch.rb

module FotonCashFlow
  module Patches
    module IssuesControllerPatch
      extend ActiveSupport::Concern
      
      included do
        alias_method :create_without_foton_patch, :create
        alias_method :create, :create_with_foton_patch
      end
      
      def create_with_foton_patch
        is_cash_flow_issue = (@issue.tracker_id == FotonCashFlow::SettingsHelper.finance_tracker_id)
        
        if is_cash_flow_issue
          entry_date_cf_id = FotonCashFlow::SettingsHelper.cf_id(:entry_date)
          if entry_date_cf_id
            current_value = @issue.custom_field_value(entry_date_cf_id)
            if current_value.blank?
              # Desativar temporariamente a validação
              @issue.instance_variable_set(:@skip_date_validation, true)
              @issue.custom_field_values = {entry_date_cf_id => Date.today.to_s}
            end
          end
        end

        create_without_foton_patch do
          if @issue.persisted? && is_cash_flow_issue
            if current_value.blank?
              flash[:notice] = "#{flash[:notice]} ".html_safe + 
                              l(:notice_entry_date_set_to_today, date: Date.today.strftime('%d/%m/%Y'))
            end
          end
          yield if block_given?
        end
      end
      
    end
  end
end