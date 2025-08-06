# lib/foton_cash_flow/services/summary_service.rb
module FotonCashFlow
  module Services
    class SummaryService
      attr_reader :total_revenue, :total_expense, :balance,
                  :bar_chart_labels, :bar_chart_revenue, :bar_chart_expense,
                  :pie_chart_labels, :pie_chart_data,
                  :balance_chart_labels, :balance_chart_data,
                  :cumulative_revenue_labels, :cumulative_revenue_data, :cumulative_expense_data

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
        @balance_chart_labels = []
        @balance_chart_data = []
        @cumulative_revenue_labels = []
        @cumulative_revenue_data = []
        @cumulative_expense_data = []

        @transaction_type_cf_id = FotonCashFlow::SettingsHelper.cf_id(:transaction_type)
        @amount_cf_id = FotonCashFlow::SettingsHelper.cf_id(:amount)
        @entry_date_cf_id = FotonCashFlow::SettingsHelper.cf_id(:entry_date)
        @category_cf_id = FotonCashFlow::SettingsHelper.cf_id(:category)

        # A constante FotonCashFlow::SettingsHelper será acessada no momento da inicialização
        # do serviço, mas não é usada diretamente neste arquivo para evitar dependências de dados.
        # Os IDs de custom fields são obtidos do FotonCashFlow::SettingsHelper::CF_IDS que é
        # carregado em um initializer, garantindo que o plugin esteja configurado.
      end

      def calculate
        Rails.logger.info "[FOTON_CASH_FLOW] Executando SummaryService#calculate..."
        
        # O loop principal para calcular os totais
        @issues.each do |issue|
          if issue.cash_flow_transaction_type == 'revenue'
            @total_revenue += issue.cash_flow_amount
          elsif issue.cash_flow_transaction_type == 'expense'
            @total_expense += issue.cash_flow_amount
          end
        end
        @balance = @total_revenue - @total_expense
        
        Rails.logger.info "[FOTON_CASH_FLOW] Totais calculados: Receita=#{@total_revenue}, Despesa=#{@total_expense}, Saldo=#{@balance}"

        prepare_bar_chart_data
        prepare_pie_chart_data
        prepare_balance_chart_data
        prepare_cumulative_flow_data
      rescue => e
        Rails.logger.error "[FOTON_CASH_FLOW] Erro em SummaryService#calculate: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        
        # Em caso de erro, os valores são resetados para garantir que não haja lixo
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
        Rails.logger.info "[FOTON_CASH_FLOW] Preparando dados para o gráfico de barras..."

        monthly_data = @issues.each_with_object(Hash.new { |h, k| h[k] = { revenue: BigDecimal('0.0'), expense: BigDecimal('0.0') } }) do |issue, memo|
          entry_date_str = issue.cash_flow_entry_date
          next unless entry_date_str.present?

          begin
            # Correção: Converte a string para um objeto Date antes de usar strftime
            entry_date = Date.parse(entry_date_str)
            month_key = entry_date.strftime('%Y-%m')

            if issue.cash_flow_transaction_type == 'revenue'
              memo[month_key][:revenue] += issue.cash_flow_amount
            elsif issue.cash_flow_transaction_type == 'expense'
              memo[month_key][:expense] += issue.cash_flow_amount
            end
          rescue ArgumentError => e
            Rails.logger.error "[FOTON_CASH_FLOW] Erro ao analisar a data '#{entry_date_str}': #{e.message}"
            next
          end
        end

        # Ordena por mês e preenche os arrays do gráfico
        sorted_data = monthly_data.sort_by { |month, _| month }

        sorted_data.each do |month_key, values|
          month_label = Date.strptime(month_key, '%Y-%m').strftime('%b/%Y')
          @bar_chart_labels << month_label
          @bar_chart_revenue << values[:revenue]
          @bar_chart_expense << values[:expense]
        end

        Rails.logger.info "[FOTON_CASH_FLOW] Dados do gráfico de barras preparados. Labels: #{@bar_chart_labels}, Receita: #{@bar_chart_revenue}, Despesa: #{@bar_chart_expense}"
      rescue => e
        Rails.logger.error "[FOTON_CASH_FLOW] Erro em prepare_bar_chart_data: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        @bar_chart_labels = []
        @bar_chart_revenue = []
        @bar_chart_expense = []
      end

      def prepare_pie_chart_data
        Rails.logger.info "[FOTON_CASH_FLOW] Preparando dados para o gráfico de pizza..."
        category_expenses = Hash.new(BigDecimal('0.0'))

        @issues.each do |issue|
          if issue.cash_flow_transaction_type == 'expense'
            category = issue.cash_flow_category
            amount = issue.cash_flow_amount
            category_expenses[category || 'Sem Categoria'] += amount
          end
        end

        @pie_chart_labels = category_expenses.keys
        @pie_chart_data = category_expenses.values

        Rails.logger.info "[FOTON_CASH_FLOW] Dados do gráfico de pizza preparados. Labels: #{@pie_chart_labels}, Dados: #{@pie_chart_data}"
      rescue => e
        Rails.logger.error "[FOTON_CASH_FLOW] Erro em prepare_pie_chart_data: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        @pie_chart_labels = []
        @pie_chart_data = []
      end

      def prepare_balance_chart_data
        Rails.logger.info "[DEBUG] Preparando dados para gráfico de balanço acumulado."
        monthly_balance = Hash.new(BigDecimal('0.0'))

        @issues.each do |issue|
          # Verifica se a data é válida e converte para um objeto Date
          next unless issue.cash_flow_entry_date.present?

          begin
            date_object = Date.parse(issue.cash_flow_entry_date)
            date_key = date_object.strftime('%Y-%m')
            amount = issue.cash_flow_amount
            
            if issue.cash_flow_transaction_type == 'revenue'
              monthly_balance[date_key] += amount
            elsif issue.cash_flow_transaction_type == 'expense'
              monthly_balance[date_key] -= amount
            end
          rescue ArgumentError => e
            Rails.logger.error "[FOTON_CASH_FLOW] Erro ao analisar a data '#{issue.cash_flow_entry_date}': #{e.message}"
            next
          end
        end

        sorted_keys = monthly_balance.keys.sort
        cumulative_balance = BigDecimal('0.0')

        @balance_chart_labels = sorted_keys.map { |key| Date.strptime(key, '%Y-%m').strftime('%b/%Y') }
        @balance_chart_data = sorted_keys.map do |key|
          cumulative_balance += monthly_balance[key]
          cumulative_balance.round(2)
        end

        @balance_chart_labels ||= []
        @balance_chart_data ||= []
      rescue => e
        Rails.logger.error "[ERROR] Erro em prepare_balance_chart_data: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        @balance_chart_labels = []
        @balance_chart_data = []
      end

      def prepare_cumulative_flow_data
        Rails.logger.info "[DEBUG] Preparando dados para gráfico de fluxo acumulado."
        monthly_revenue = Hash.new(BigDecimal('0.0'))
        monthly_expense = Hash.new(BigDecimal('0.0'))

        @issues.each do |issue|
          # Verifica se a data é válida e converte para um objeto Date
          next unless issue.cash_flow_entry_date.present?

          begin
            date_object = Date.parse(issue.cash_flow_entry_date)
            date_key = date_object.strftime('%Y-%m')
            amount = issue.cash_flow_amount

            if issue.cash_flow_transaction_type == 'revenue'
              monthly_revenue[date_key] += amount
            elsif issue.cash_flow_transaction_type == 'expense'
              monthly_expense[date_key] += amount
            end
          rescue ArgumentError => e
            Rails.logger.error "[FOTON_CASH_FLOW] Erro ao analisar a data '#{issue.cash_flow_entry_date}': #{e.message}"
            next
          end
        end

        sorted_keys = (monthly_revenue.keys | monthly_expense.keys).sort
        cumulative_rev = BigDecimal('0.0')
        cumulative_exp = BigDecimal('0.0')

        @cumulative_revenue_labels = sorted_keys.map { |key| Date.strptime(key, '%Y-%m').strftime('%b/%Y') }
        @cumulative_revenue_data = sorted_keys.map do |key|
          cumulative_rev += monthly_revenue[key]
          cumulative_rev.round(2)
        end
        @cumulative_expense_data = sorted_keys.map do |key|
          cumulative_exp += monthly_expense[key]
          cumulative_exp.round(2)
        end
      rescue => e
        Rails.logger.error "[ERROR] Erro em prepare_cumulative_flow_data: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        @cumulative_revenue_labels = []
        @cumulative_revenue_data = []
        @cumulative_expense_data = []
      end

    end
  end
end