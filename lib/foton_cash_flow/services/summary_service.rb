# lib/foton_cash_flow/services/summary_service.rb
module FotonCashFlow
  module Services
    class SummaryService
      attr_reader :total_revenue, :total_expense, :balance,
                  :bar_chart_labels, :bar_chart_revenue, :bar_chart_expense,
                  :pie_chart_labels, :pie_chart_data

      def initialize(issues)
        @issues = issues
        @total_revenue = BigDecimal('0.0')
        @total_expense = BigDecimal('0.0')
        @balance = BigDecimal('0.0')
        @bar_chart_labels = []
        @bar_chart_revenue = []
        @bar_chart_expense = []
        @pie_chart_labels = []
        @pie_chart_data = []

        @transaction_type_cf_id = FotonCashFlow::SettingsHelper.cf_id(:transaction_type)
        @amount_cf_id = FotonCashFlow::SettingsHelper.cf_id(:amount)
        @entry_date_cf_id = FotonCashFlow::SettingsHelper.cf_id(:entry_date)
        @category_cf_id = FotonCashFlow::SettingsHelper.cf_id(:category)
      end

      def calculate
        Rails.logger.info "[DEBUG] Executando CashFlowSummaryService#calculate."

        @issues.each do |issue|
          if issue.cash_flow_transaction_type == 'revenue'
            @total_revenue += issue.cash_flow_amount
          elsif issue.cash_flow_transaction_type == 'expense'
            @total_expense += issue.cash_flow_amount
          end
        end
        @balance = @total_revenue - @total_expense

        prepare_bar_chart_data
        prepare_pie_chart_data
      rescue => e
        Rails.logger.error "[ERROR] Erro em CashFlowSummaryService#calculate: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        @total_revenue = BigDecimal('0.0')
        @total_expense = BigDecimal('0.0')
        @balance = BigDecimal('0.0')
        @bar_chart_labels = []
        @bar_chart_revenue = []
        @bar_chart_expense = []
        @pie_chart_labels = []
        @pie_chart_data = []
      end

      private

      def prepare_bar_chart_data
        Rails.logger.info "[DEBUG] Preparando dados para gráfico de barras."
        monthly_data = Hash.new { |h, k| h[k] = { revenue: BigDecimal('0.0'), expense: BigDecimal('0.0') } }

        @issues.each do |issue|
          entry_date = issue.cash_flow_entry_date
          next unless entry_date.present?

          month_key = entry_date.strftime('%Y-%m')
          if issue.cash_flow_transaction_type == 'revenue'
            monthly_data[month_key][:revenue] += issue.cash_flow_amount
          elsif issue.cash_flow_transaction_type == 'expense'
            monthly_data[month_key][:expense] += issue.cash_flow_amount
          end
        end

        sorted_keys = monthly_data.keys.sort

        @bar_chart_labels = sorted_keys.map { |key| Date.strptime(key, '%Y-%m').strftime('%b/%Y') }
        @bar_chart_revenue = sorted_keys.map { |key| monthly_data[key][:revenue] }
        @bar_chart_expense = sorted_keys.map { |key| monthly_data[key][:expense] }

        @bar_chart_labels ||= []
        @bar_chart_revenue ||= []
        @bar_chart_expense ||= []
      rescue => e
        Rails.logger.error "[ERROR] Erro em prepare_bar_chart_data: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        @bar_chart_labels = []
        @bar_chart_revenue = []
        @bar_chart_expense = []
      end

      def prepare_pie_chart_data
        Rails.logger.info "[DEBUG] Preparando dados para gráfico de pizza."
        category_expenses = Hash.new(BigDecimal('0.0'))

        @issues.each do |issue|
          if issue.cash_flow_transaction_type == 'expense'
            category = issue.cash_flow_category
            amount = issue.cash_flow_amount
            category_expenses[category || 'Sem Categoria'] += amount
          end
        end

        @pie_chart_labels = category_expenses.keys.compact
        @pie_chart_data = category_expenses.values.compact

        @pie_chart_labels ||= []
        @pie_chart_data ||= []
      rescue => e
        Rails.logger.error "[ERROR] Erro em prepare_pie_chart_data: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        @pie_chart_labels = []
        @pie_chart_data = []
      end
    end
  end
end