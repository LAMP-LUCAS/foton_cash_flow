# ./lib/foton_cash_flow/services/exporter.rb

module FotonCashFlow
  module Services
    class Exporter
      # Define a ordem e as chaves canônicas para os cabeçalhos do CSV.
      # As traduções serão buscadas dos arquivos de localidade (I18n).
      def self.header_keys
        [
          :id, :entry_date, :transaction_type, :amount, :category,
          :status, :subject, :project, :author
        ]
      end

      # Gera os cabeçalhos traduzidos com base no locale atual.
      def self.csv_headers
        header_keys.map do |key|
          I18n.t("foton_cash_flow.exporter.headers.#{key}")
        end
      end

      def initialize(issues, currency_symbol = 'R$')
        @issues = issues
        @currency_symbol = currency_symbol
        @cf_cache = cache_custom_fields
      end
      
      def export_csv
        CSV.generate(headers: true, col_sep: ';') do |csv|
          csv << self.class.csv_headers
          @issues.each do |issue|
            csv << build_row(issue)
          end
        end
      end

      private

      def cache_custom_fields
        {
          entry_date: FotonCashFlow::SettingsHelper.cf_id(:entry_date),
          amount: FotonCashFlow::SettingsHelper.cf_id(:amount),
          transaction_type: FotonCashFlow::SettingsHelper.cf_id(:transaction_type),
          category: FotonCashFlow::SettingsHelper.cf_id(:category)
        }
      end

      def build_row(issue)
        self.class.header_keys.map do |key|
          case key
          when :entry_date then issue.custom_field_value(@cf_cache[:entry_date])
          when :transaction_type then issue.custom_field_value(@cf_cache[:transaction_type])
          when :amount then issue.custom_field_value(@cf_cache[:amount])
          when :category then issue.custom_field_value(@cf_cache[:category])
          when :status then issue.status&.name
          when :project then issue.project&.name
          when :author then issue.author&.name
          else issue.send(key) rescue ''
          end
        end
      end
    end
  end
end