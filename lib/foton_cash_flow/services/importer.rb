# ./lib/foton_cash_flow/services/importer.rb

module FotonCashFlow
  module Services
    class Importer
      include ActiveModel::Model

      attr_reader :imported_count, :errors

      def initialize(file, user)
        @file = file
        @user = user
        @imported_count = 0
        @errors = []
        @cf_cache = cache_custom_fields
      end

      def call
        return false unless valid_file?

        ActiveRecord::Base.transaction do
          CSV.foreach(@file.path, headers: true, col_sep: ',') do |row|
            import_row(row)
          end
          raise ActiveRecord::Rollback if @errors.any?
        end

        @errors.empty?
      rescue CSV::MalformedCSVError => e
        @errors << "Formato de CSV inválido: #{e.message}"
        false
      rescue => e
        @errors << "Erro inesperado: #{e.message}"
        false
      end

      private

      def valid_file?
        if @file.blank?
          @errors << "Nenhum arquivo selecionado"
          return false
        end
        
        unless File.extname(@file.original_filename) == '.csv'
          @errors << "Formato de arquivo inválido. Use .csv"
          return false
        end
        
        true
      end

      def cache_custom_fields
        {
          entry_date: CustomField.find_by(name: 'Data do Lançamento')&.id,
          amount: CustomField.find_by(name: 'Valor')&.id,
          transaction_type: CustomField.find_by(name: 'Tipo de Transação')&.id,
          category: CustomField.find_by(name: 'Categoria')&.id
        }
      end

      def import_row(row)
        issue = build_issue(row)
        if issue.save
          @imported_count += 1
        else
          @errors << "Linha #{@imported_count + @errors.size + 1}: #{issue.errors.full_messages.join(', ')}"
        end
      end

      def build_issue(row)
        tracker = Tracker.find_by(name: 'Financeiro')
        raise "Tracker 'Financeiro' não encontrado" unless tracker

        issue = Issue.new(
          tracker: tracker,
          project_id: row['project_id'],
          author: @user,
          subject: row['description'] || 'Lançamento importado',
          description: row['notes']
        )

        issue.custom_field_values = {
          @cf_cache[:entry_date] => row['entry_date'],
          @cf_cache[:amount] => row['amount'],
          @cf_cache[:transaction_type] => row['transaction_type'],
          @cf_cache[:category] => row['category']
        }

        issue
      end
    end
  end
end

# Fim do arquivo importer.rb
