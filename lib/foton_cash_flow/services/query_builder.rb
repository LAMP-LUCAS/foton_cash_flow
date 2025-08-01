# plugins/foton_cash_flow/lib/foton_cash_flow/services/query_builder.rb

require_dependency 'settings_helper'

module FotonCashFlow
  module Services 
    class QueryBuilder
      attr_reader :cf_cache

      def initialize(params, user)
        @params = params
        @user = user
        @finance_tracker_id = FotonCashFlow::SettingsHelper.finance_tracker_id
        @cf_ids = {
          entry_date: FotonCashFlow::SettingsHelper.cf_id(:entry_date),
          amount: FotonCashFlow::SettingsHelper.cf_id(:amount),
          transaction_type: FotonCashFlow::SettingsHelper.cf_id(:transaction_type),
          category: FotonCashFlow::SettingsHelper.cf_id(:category)
        }
      end

      def build
        unless FotonCashFlow::SettingsHelper.all_dependencies_met?
          Rails.logger.warn "[CASH_FLOW_BUILDER] Dependências de fluxo de caixa não estão completas. Retornando consulta vazia."
          return Issue.none
        end

        issues = Issue.
          where(tracker_id: @finance_tracker_id).
          includes(:custom_values)

        if @params[:from_date].present?
          issues = issues.by_cash_flow_cf_date_range(@cf_ids[:entry_date], @params[:from_date], nil)
        end

        if @params[:to_date].present?
          issues = issues.by_cash_flow_cf_date_range(@cf_ids[:entry_date], nil, @params[:to_date])
        end

        if @params[:transaction_type].present?
          issues = issues.by_cash_flow_cf_value(@cf_ids[:transaction_type], @params[:transaction_type])
        end

        if @params[:category].present?
          issues = issues.by_cash_flow_cf_value(@cf_ids[:category], @params[:category])
        end

        if @params[:search].present?
          search_term = "%#{@params[:search].downcase}%"
          issues = issues.where("LOWER(issues.subject) LIKE :search OR LOWER(issues.description) LIKE :search", search: search_term)
        end

        if @params[:project_id].present?
          issues = issues.where(project_id: @params[:project_id])
        elsif Setting.plugin_foton_cash_flow['only_finance_project'] == '1'
          internal_finance_project_id = FotonCashFlow::SettingsHelper.internal_finance_project_id
          if internal_finance_project_id.present?
            issues = issues.where(project_id: internal_finance_project_id)
          else
            Rails.logger.warn "[CASH_FLOW_BUILDER] Setting 'only_finance_project' está ativa, mas o ID do projeto interno não está configurado."
          end
        end

        issues
      end

      private
    end
  end
end