# ./lib/foton_cash_flow/services/importer.rb

module FotonCashFlow
  module Services
    class Importer
      attr_reader :errors, :imported_count, :newly_created_categories

      # Define os nomes de cabeçalho alternativos (aliases) que o importador reconhecerá.
      # Isso permite que o usuário envie um CSV com cabeçalhos em português, inglês, etc.
      HEADER_ALIASES = {
        entry_date: ['Data do Lançamento', 'Entry Date', 'Date'],
        description: ['Descrição', 'Description', 'Subject'],
        amount: ['Valor', 'Amount', 'Value'],
        transaction_type: ['Tipo de Transação', 'Transaction Type', 'Type'],
        category: ['Categoria', 'Category']
      }.freeze

      REQUIRED_HEADERS = [:description, :amount, :transaction_type].freeze

      # Adicionamos o parâmetro resolutions com um valor padrão vazio
      def initialize(file_content, user, project, resolutions: {}, original_filename: 'import.csv')
        @file_content = file_content
        @user = user
        @project = project
        @imported_count = 0
        @original_filename = original_filename
        @header_map = {} # Armazena o mapeamento do cabeçalho do arquivo para nossas chaves
        @resolutions = resolutions # Armazena as resoluções do usuário
        @errors = []
        Rails.logger.info "[FOTON_CASH_FLOW][Importer] Initialized with resolutions: #{@resolutions.inspect}"
        @newly_created_categories = []
        @cf_cache = cache_custom_fields
      end

      def call
        return false unless file_valid? && dependencies_met?

        # Cria um Tempfile para que a biblioteca CSV possa lê-lo de forma consistente.
        Tempfile.create(['importer', '.csv']) do |tempfile|
          tempfile.write(@file_content)
          tempfile.rewind

          return false unless map_headers_from_file(tempfile.path)

          ActiveRecord::Base.transaction do
            CSV.foreach(tempfile.path, headers: true, col_sep: ';', encoding: 'UTF-8') do |row|
              import_row(row, $. + 1) # $. é o número da linha atual no arquivo
            end
            raise ActiveRecord::Rollback if @errors.any?
          end
        end

        @errors.empty?
      rescue CSV::MalformedCSVError => e
        @errors << I18n.t('foton_cash_flow.errors.malformed_csv', error: e.message)
        false
      rescue => e
        @errors << I18n.t('foton_cash_flow.errors.generic_import_error', error: e.message)
        Rails.logger.error "[FOTON_CASH_FLOW][Importer] Generic error: #{e.message}\n#{e.backtrace.join("\n")}"
        false
      end

      private

      def file_valid?
        if @file_content.blank?
          @errors << I18n.t('foton_cash_flow.errors.no_file_provided')
          return false
        end
        
        unless File.extname(@original_filename).casecmp('.csv').zero?
          @errors << I18n.t('foton_cash_flow.errors.invalid_file_format', format: '.csv')
          return false
        end
        
        true
      end

      def dependencies_met?
        if @cf_cache.values.any?(&:nil?) || FotonCashFlow::SettingsHelper.finance_tracker_id.blank?
          @errors << I18n.t('foton_cash_flow.errors.dependencies_not_met')
          return false
        end
        true
      end

      # Mapeia os cabeçalhos do arquivo CSV para as chaves internas do sistema.
      def map_headers_from_file(file_path)
        csv_headers = CSV.read(file_path, headers: true, col_sep: ';', encoding: 'UTF-8').headers

        HEADER_ALIASES.each do |canonical_key, aliases|
          found_header = csv_headers.find { |csv_h| aliases.any? { |a| a.casecmp(csv_h.strip) == 0 } }
          @header_map[canonical_key] = found_header if found_header
        end

        # Valida se as colunas obrigatórias foram encontradas
        missing_headers = REQUIRED_HEADERS.select { |key| @header_map[key].nil? }
        unless missing_headers.empty?
          expected_names = missing_headers.map { |key| HEADER_ALIASES[key].first }.join(', ')
          @errors << I18n.t('foton_cash_flow.errors.missing_headers', headers: expected_names)
          return false
        end

        true
      end

      def cache_custom_fields
        {
          entry_date: FotonCashFlow::SettingsHelper.cf_id(:entry_date),
          amount: FotonCashFlow::SettingsHelper.cf_id(:amount),
          transaction_type: FotonCashFlow::SettingsHelper.cf_id(:transaction_type),
          category: FotonCashFlow::SettingsHelper.cf_id(:category)
        }
      end

      def import_row(row, line_number)
        # **CORREÇÃO:** build_issue_from_row agora pode retornar nil se houver erros de validação.
        issue = build_issue_from_row(row, line_number)
        return unless issue # Pula para a próxima linha se a construção falhou.

        if issue.save
          @imported_count += 1
        else
          @errors << I18n.t('foton_cash_flow.errors.import_line_error', line: line_number, errors: issue.errors.full_messages.join(', '))
        end
      end

      def build_issue_from_row(row, line_number)
        # Busca os valores usando o mapa de cabeçalhos para flexibilidade.
        entry_date_val = @header_map[:entry_date] ? row[@header_map[:entry_date]] : Date.current.to_s
        amount_val = row[@header_map[:amount]]&.strip
        type_val = row[@header_map[:transaction_type]]&.strip
        category_val = @header_map[:category] ? row[@header_map[:category]]&.strip : nil
        description_val = row[@header_map[:description]] || I18n.t('foton_cash_flow.defaults.imported_entry_subject')

        Rails.logger.info "[FOTON_CASH_FLOW][Importer] Processing line #{line_number}: type='#{type_val}', category='#{category_val}'"

        # **ROBUSTEZ:** Valida a data antes de tentar usá-la.
        parsed_date = Date.parse(entry_date_val) rescue nil
        unless parsed_date
          @errors << I18n.t('foton_cash_flow.errors.import_line_error', line: line_number, errors: "Formato de data inválido para '#{entry_date_val}'")
          return nil
        end

        # **ROBUSTEZ:** Resolve e valida os valores que dependem do banco de dados.
        # Primeiro, resolve a string (caso o usuário tenha mapeado um valor no modal).
        type_string = resolve_value_string(:transaction_type, type_val)
        category_string = resolve_value_string(:category, category_val)
        Rails.logger.info "[FOTON_CASH_FLOW][Importer] Line #{line_number} after resolution: type='#{type_string}', category='#{category_string}'"

        # **CORREÇÃO CRÍTICA:** Agora, busca os objetos do banco de dados usando a string resolvida.
        # O método `find_association` irá adicionar um erro e retornar nil se não encontrar, evitando o crash.
        transaction_type = find_association(:transaction_type, type_string, line_number)
        #category = find_association(:category, category_string, line_number)

        # **ROBUSTEZ:** Validação explícita dos resultados da busca de associação.
        # Categoria é opcional, mas se um valor for fornecido, ele deve ser válido.
        # if category_string.present? && category.nil?
        #   Rails.logger.warn "[FOTON_CASH_FLOW][Importer] Line #{line_number}: Invalid category '#{category_string}'. Skipping row."
        #   return nil
        # end
        
        # Tipo de transação é obrigatório.
        return nil if transaction_type.nil?

        issue = Issue.new(
          tracker_id: FotonCashFlow::SettingsHelper.finance_tracker_id,
          project_id: @project.id,
          author: @user,
          subject: description_val,
          # **CORREÇÃO:** Atribui os objetos encontrados (ou seus IDs) aos campos personalizados.
          custom_field_values: {
            @cf_cache[:entry_date] => parsed_date,
            @cf_cache[:amount] => FotonCashFlow::SettingsHelper.parse_currency_to_decimal(amount_val),
            # Para campos de lista, o valor é a própria string.
            @cf_cache[:transaction_type] => type_string,
            # Para campos de associação (lookup), o valor é o ID do registro.
            @cf_cache[:category] => category_string #category ? category.id : nil
          }
        )

        issue
      end

      # Aplica a resolução do usuário para um determinado valor.
      def resolve_value_string(column_key, original_value)
        # Busca a resolução no mapa. Ex: @resolutions[:category]['Categoria Inexistente']
        resolution = @resolutions.dig(column_key.to_s, original_value)
        Rails.logger.info "[FOTON_CASH_FLOW][Importer] Resolving value for column '#{column_key}', original: '#{original_value}'. Resolution found: '#{resolution.inspect}'"

        return original_value unless resolution # Se não há resolução, retorna o valor original.

        if resolution == 'create_new'
          # Se a resolução é para criar um novo item (atualmente, só para categorias)
          create_new_category(original_value) if column_key == :category && original_value.present?
          original_value # Retorna o valor original, que agora é válido.
        else
          # Se a resolução é um mapeamento para um valor existente.
          resolution
        end
      end

      # Encontra a associação (ex: Categoria) pelo nome.
      def find_association(type, name, line_number)
        Rails.logger.info "[FOTON_CASH_FLOW][Importer] Finding association for type: '#{type}', name: '#{name}' on line #{line_number}"
        return nil if name.blank?

        model, cf_id = case type
        when :transaction_type
          # Tipos de transação são apenas strings em uma lista, não um modelo separado.
          # A validação já ocorreu na pré-análise.
          return name
        when :category
          [IssueCategory, @cf_cache[:category]]
        else
          return nil
        end

        # Para categorias, que são um modelo, buscamos o objeto.
        record = model.find_by('LOWER(name) = ? AND project_id = ?', name.strip.downcase, @project.id)

        if record.nil?
          Rails.logger.warn "[FOTON_CASH_FLOW][Importer] Association NOT FOUND for type: '#{type}', name: '#{name}'"
          @errors << I18n.t('foton_cash_flow.errors.import_line_error', line: line_number, errors: "O valor '#{name}' para #{type} não foi encontrado no projeto.")
        else
          Rails.logger.info "[FOTON_CASH_FLOW][Importer] Association FOUND for type: '#{type}', name: '#{name}', record ID: #{record.id}"
        end

        record
      end

      # Adiciona um novo valor à lista de um Custom Field.
      def create_new_category(value)
        category_cf = IssueCustomField.find_by(id: @cf_cache[:category])
        return unless category_cf&.field_format == 'list'

        # Garante que o valor não seja adicionado novamente se já existir (case-insensitive)
        existing_values = category_cf.possible_values.map { |v| v.to_s.strip.downcase }
        return if existing_values.include?(value.strip.downcase)

        category_cf.possible_values << value
        if category_cf.save
          @newly_created_categories << value
          Rails.logger.info "[FOTON_CASH_FLOW][Importer] Nova categoria criada com sucesso: '#{value}'"
        else
          @errors << I18n.t('foton_cash_flow.errors.category_creation_failed', category: value, errors: category_cf.errors.full_messages.join(', '))
        end
      end
    end
  end
end
