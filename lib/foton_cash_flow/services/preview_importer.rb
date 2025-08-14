# plugins/foton_cash_flow/app/services/foton_cash_flow/services/preview_importer.rb
require 'csv'
require 'securerandom'

module FotonCashFlow
  module Services
    class PreviewImporter
      attr_reader :conflicts, :header_map

      # Aliases para os cabeçalhos do CSV para maior flexibilidade.
      HEADER_ALIASES = {
        entry_date: ['Data do Lançamento', 'Entry Date', 'Date'],
        amount: ['Valor', 'Amount', 'Value'],
        transaction_type: ['Tipo de Transação', 'Transaction Type', 'Type'],
        category: ['Categoria', 'Category'],
        description: ['Descrição', 'Description', 'Subject'] # Adicionado para contexto
      }.freeze

      def initialize(file_path, project)
        @file_path = file_path
        @project = project
        @conflicts = []
        @header_map = {} # Mapeia o cabeçalho do arquivo para nossas chaves internas

        # Busca os Custom Fields necessários para a validação.
        # O serviço assume que estes campos existem.
        @category_cf = CustomField.find_by(id: FotonCashFlow::SettingsHelper.cf_id(:category))
        @transaction_type_cf = CustomField.find_by(id: FotonCashFlow::SettingsHelper.cf_id(:transaction_type))
      end

      def call
        # 1. Mapeia os cabeçalhos do arquivo. Se falhar, não continua.
        return self unless map_headers_from_file

        # 2. Itera sobre cada linha do CSV, começando a contagem na linha 2.
        CSV.foreach(@file_path, headers: true, col_sep: ';', encoding: 'UTF-8').with_index(2) do |row, row_number|
          # Valida cada coluna relevante da linha.
          validate_entry_date(row, row_number)
          validate_amount(row, row_number)
          validate_transaction_type(row, row_number)
          validate_category(row, row_number)
        end

        self # Retorna a própria instância do serviço.
      end

      private

      # Mapeia os cabeçalhos do arquivo CSV para as chaves internas do sistema.
      # Retorna `false` e adiciona um erro global se um cabeçalho obrigatório faltar.
      def map_headers_from_file
        begin
          csv_headers = CSV.read(@file_path, headers: true, col_sep: ';', encoding: 'UTF-8').headers
        rescue => e
          add_conflict(
            row_number: 1,
            column_name: 'Arquivo',
            invalid_value: @file_path,
            error_type: 'file_read_error',
            message: "Não foi possível ler o arquivo CSV. Verifique o formato e a codificação. Erro: #{e.message}"
          )
          return false
        end

        HEADER_ALIASES.each do |canonical_key, aliases|
          found_header = csv_headers.find { |csv_h| aliases.any? { |a| a.casecmp(csv_h&.strip) == 0 } }
          @header_map[canonical_key] = found_header if found_header
        end
        true
      end

      # Valida a coluna 'Data do Lançamento'.
      def validate_entry_date(row, row_number)
        header = @header_map[:entry_date]
        return unless header # Pula se a coluna não existir no arquivo

        value = row[header]&.strip
        if value.blank?
          add_conflict(
            row_number: row_number,
            column_name: header,
            invalid_value: value,
            error_type: 'blank_value',
            message: 'A data não pode estar em branco.'
          )
          return
        end

        # Tenta parsear a data no formato AAAA-MM-DD
        Date.strptime(value, '%Y-%m-%d')
      rescue ArgumentError
        add_conflict(
          row_number: row_number,
          column_name: header,
          invalid_value: value,
          error_type: 'invalid_date_format',
          message: 'O formato da data é inválido. Use AAAA-MM-DD.'
        )
      end

      # Valida a coluna 'Valor'.
      def validate_amount(row, row_number)
        header = @header_map[:amount]
        return unless header

        value = row[header]&.strip
        if value.blank?
          add_conflict(
            row_number: row_number,
            column_name: header,
            invalid_value: value,
            error_type: 'blank_value',
            message: 'O valor não pode estar em branco.'
          )
          return
        end

        # Tenta converter o valor para um número.
        FotonCashFlow::SettingsHelper.parse_currency_to_decimal(value)
      rescue ArgumentError
        add_conflict(
          row_number: row_number,
          column_name: header,
          invalid_value: value,
          error_type: 'invalid_number_format',
          message: 'O formato do valor é inválido. Deve ser um número (ex: 1234,56 ou -150.75).'
        )
      end

      # Valida a coluna 'Tipo de Transação'.
      def validate_transaction_type(row, row_number)
        header = @header_map[:transaction_type]
        return unless header

        value = row[header]&.strip
        valid_options = @transaction_type_cf&.possible_values || []

        if value.blank?
          add_conflict(
            row_number: row_number,
            column_name: header,
            invalid_value: value,
            error_type: 'blank_value',
            message: 'O tipo de transação não pode estar em branco.'
          )
          return
        end

        # Verifica se o valor está na lista de opções válidas (case-insensitive).
        unless valid_options.any? { |opt| opt.casecmp(value) == 0 }
          add_conflict(
            row_number: row_number,
            column_name: header,
            invalid_value: value,
            error_type: 'value_not_in_list',
            column_key: :transaction_type,
            message: "O valor '#{value}' não é um tipo de transação válido.",
            resolution_options: valid_options
          )
        end
      end

      # Valida a coluna 'Categoria'.
      def validate_category(row, row_number)
        header = @header_map[:category]
        return unless header # A categoria é opcional, então só validamos se a coluna existir.

        value = row[header]&.strip
        return if value.blank? # Permite categorias em branco.

        valid_options = @category_cf&.possible_values || []

        # Verifica se o valor está na lista de opções válidas (case-insensitive).
        unless valid_options.any? { |opt| opt.casecmp(value) == 0 }
          add_conflict(
            row_number: row_number,
            column_name: header,
            invalid_value: value,
            error_type: 'value_not_in_list',
            column_key: :category,
            message: "A categoria '#{value}' não existe.",
            resolution_options: valid_options
          )
        end
      end

      # Helper para adicionar um novo conflito ao array @conflicts.
      def add_conflict(row_number:, column_name:, invalid_value:, error_type:, message:, resolution_options: [], column_key: nil)
        @conflicts << {
          "id" => SecureRandom.uuid,
          "row_number" => row_number,
          "column_name" => column_name,
          "column_key" => column_key,
          "invalid_value" => invalid_value,
          "error_type" => error_type,
          "message" => message,
          "resolution_options" => resolution_options
        }
      end
    end
  end
end