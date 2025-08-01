# ./lib/foton_cash_flow/services/exporter.rb

module FotonCashFlow
  module Services
    class Exporter

      COLUMNS = %w[entry_date transaction_type amount category description notes project_id user_id created_at].freeze

      def initialize(params, user = User.current)
        @issues = issues
        @params = params || {}
        @user = user
        @cf_cache = cache_custom_fields
      end

      def generate
        CSV.generate(headers: true, col_sep: ';') do |csv|
          csv << headers
          issues.each { |issue| csv << build_row(issue) }
        end
      end

      def filename
        "fluxo_caixa_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv"
      end

      private

      def headers
        COLUMNS.map { |col| I18n.t("cash_flow.export_headers.#{col}", default: col.humanize) }
      end

      def issues
        @issues ||= CashFlowQueryBuilder.new(@params, @user).build
      end

      def cache_custom_fields
        {
          entry_date: CustomField.find_by(name: 'Data do Lançamento')&.id,
          amount: CustomField.find_by(name: 'Valor')&.id,
          transaction_type: CustomField.find_by(name: 'Tipo de Transação')&.id,
          category: CustomField.find_by(name: 'Categoria')&.id
        }
      end

      def build_row(issue)
        COLUMNS.map do |column|
          case column
          when 'entry_date' then issue.custom_field_value(@cf_cache[:entry_date])
          when 'description' then issue.subject
          when 'amount' then format_number(issue.custom_field_value(@cf_cache[:amount]))
          when 'transaction_type' then translate_transaction_type(issue.custom_field_value(@cf_cache[:transaction_type]))
          when 'category' then issue.custom_field_value(@cf_cache[:category])
          when 'notes' then issue.description
          when 'project_id' then issue.project_id
          when 'user_id' then issue.author_id
          when 'created_at' then I18n.l(issue.created_on, format: :long)
          else issue.send(column) rescue ''
          end
        end
      end

      def format_number(value)
        ActionController::Base.helpers.number_to_currency(value.to_f, unit: '', delimiter: '.', separator: ',')
      end

      def translate_transaction_type(type)
        I18n.t("cash_flow.transaction_types.#{type}", default: type)
      end
      
      def to_csv
        # Exemplo básico de implementação, adapte aos seus campos e necessidades
        CSV.generate(headers: true) do |csv|
          csv << ["ID", "Data do Lançamento", "Categoria", "Tipo de Transação", "Valor", "Status", "Descrição"] # Cabeçalhos
          @issues.each do |issue|
            csv << [
              issue.id,
              issue.custom_field_value(FotonCashFlow::SettingsHelper.cf_id(:entry_date)),
              issue.custom_field_value(FotonCashFlow::SettingsHelper.cf_id(:category)),
              issue.custom_field_value(FotonCashFlow::SettingsHelper.cf_id(:transaction_type)),
              issue.custom_field_value(FotonCashFlow::SettingsHelper.cf_id(:amount)),
              issue.status.name,
              issue.subject
            ]
          end
        end
      end
    end
  end
end
# Fim do arquivo exporter.rb