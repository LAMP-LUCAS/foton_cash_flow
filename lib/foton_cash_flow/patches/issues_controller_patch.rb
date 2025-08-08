# plugins/foton_cash_flow/lib/foton_cash_flow/patches/issues_controller_patch.rb

require_dependency 'issues_controller'

module FotonCashFlow
  module Patches
    module IssuesControllerPatch
      extend ActiveSupport::Concern
      
      included do
        # Sobrescreve o método `create` para garantir que o valor da data está no hash de parâmetros
        alias_method :create_without_cash_flow, :create
        def create
          # Verifica se o tipo de tracker é o financeiro e o campo de data está vazio
          if params[:issue][:tracker_id].to_i == FotonCashFlow::SettingsHelper.finance_tracker_id
            entry_date_cf_id = FotonCashFlow::SettingsHelper.cf_id(:entry_date)
            
            # Garante que o hash de custom fields existe antes de tentar acessar
            params[:issue][:custom_field_values] ||= {}
            
            if entry_date_cf_id.present? && params[:issue][:custom_field_values][entry_date_cf_id].blank?
              # Preenche o valor diretamente nos parâmetros antes do Redmine criar a issue
              params[:issue][:custom_field_values][entry_date_cf_id] = Time.zone.today.to_s
              Rails.logger.info "[FOTON_CASH_FLOW][IssuesControllerPatch] Data de lançamento preenchida no POST CREATE com: #{params[:issue][:custom_field_values][entry_date_cf_id]}"
            end
          end
          
          # Chama o método original do Redmine com os parâmetros já modificados
          create_without_cash_flow
        end
      end
    end
  end
end