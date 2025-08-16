# ./lib/foton_cash_flow/services/importer.rb

module FotonCashFlow
  module Services
    class Importer
      attr_reader :errors, :imported_count, :newly_created_categories

      HEADER_ALIASES = {
        entry_date: ['Data do Lançamento', 'Entry Date', 'Date'],
        description: ['Descrição', 'Description', 'Subject'],
        amount: ['Valor', 'Amount', 'Value'],
        transaction_type: ['Tipo de Transação', 'Transaction Type', 'Type'],
        category: ['Categoria', 'Category'],
        status: ['Status', 'Situação'],
        responsible_name: ['Responsável', 'Responsible', 'Assigned To'],
        attachment_name: ['Arquivo', 'Anexo', 'Comprovante', 'Attachment']
      }.freeze

      REQUIRED_HEADERS = [:description].freeze # Apenas descrição é realmente obrigatória para criar o alerta

      def initialize(file_content_binary, user, project, resolutions: {}, original_filename: 'import.csv')
        # Força a interpretação do conteúdo do arquivo como UTF-8.
        # Isso é crucial para lidar com arquivos que contêm caracteres acentuados.
        @file_content = file_content_binary.force_encoding('UTF-8')
        @user = user
        @project = project
        @resolutions = resolutions
        @imported_count = 0
        @original_filename = original_filename
        @header_map = {}
        @errors = []
        @newly_created_categories = []
        @cf_objects = cache_custom_field_objects # Alterado para buscar os objetos
        Rails.logger.info "[FOTON_CASH_FLOW][Importer] Initialized with resolutions: #{@resolutions.inspect}"
      end

      def call
        return false unless file_valid? && dependencies_met?

        Tempfile.create(['importer', '.csv']) do |tempfile|
          tempfile.write(@file_content)
          tempfile.rewind
          separator = detect_separator(tempfile.path)

          return false unless map_headers_from_file(tempfile.path, separator)

          preprocess_creation_resolutions!
          return false if @errors.any?

          ActiveRecord::Base.transaction do
            Rails.logger.info "[FOTON_CASH_FLOW][Importer] Starting CSV processing transaction"
            
            CSV.foreach(tempfile.path, headers: true, col_sep: separator, encoding: 'UTF-8').with_index(2) do |row, line_number|
              import_row(row, line_number)
            end
            
            Rails.logger.info "[FOTON_CASH_FLOW][Importer] Transaction completed. Imported: #{@imported_count}, Errors: #{@errors.size}"
            
            # ATENÇÃO: Se houverem erros GERAIS (não de parsing), fazemos o rollback.
            # Erros de parsing por linha são tratados e salvos na própria issue.
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

      # NOVO MÉTODO: Formata os erros de parsing para serem incluídos na descrição da Issue.
      def build_error_note(parsing_errors)
        return nil if parsing_errors.empty?
        
        error_details = parsing_errors.map do |field, value|
          "  \"#{field.to_s.humanize}\": \"#{value}\""
        end.join(",\n")

        "\n\n---\n**ERROS DE IMPORTAÇÃO**\n{\n#{error_details}\n}"
      end

      # MÉTODO PRINCIPAL ALTERADO: Implementa a lógica de resiliência.
      def build_issue_from_row(row, line_number)
        parsing_errors = {}

        # 1. Coleta e valida os dados da linha
        description_val = row[@header_map[:description]] || "Lançamento importado - Linha #{line_number}"
        
        # Validação de Data - sempre garante uma data válida
        entry_date_val = row[@header_map[:entry_date]]
        parsed_date = parse_flexible_date(entry_date_val)
        if parsed_date.nil?
          parsed_date = Date.current # Valor Padrão
          parsing_errors[:data] = entry_date_val.presence || 'vazio'
        end
        
        # Validação de Valor - melhora a detecção de valores problemáticos
        amount_val = row[@header_map[:amount]]&.strip
        parsed_amount = nil
        
        begin
          parsed_amount = FotonCashFlow::SettingsHelper.parse_currency_to_decimal(amount_val)
          # Se o valor é zero mas havia conteúdo, considera como erro
          if parsed_amount == BigDecimal('0.0') && amount_val.present? && amount_val != '0' && amount_val != '0.0'
            parsing_errors[:valor] = amount_val
          end
        rescue => e
          parsed_amount = BigDecimal('0.0') # Valor Padrão
          parsing_errors[:valor] = amount_val.presence || 'vazio'
        end
        
        # Garante que nunca seja nil
        parsed_amount ||= BigDecimal('0.0')

        # Validação de Responsável
        responsible_name_val = row[@header_map[:responsible_name]]&.strip
        responsible_user = find_responsible_user(responsible_name_val)
        if responsible_name_val.present? && responsible_user.nil?
          parsing_errors[:responsavel] = responsible_name_val
        end
        
        # Coleta dos demais campos
        type_val = row[@header_map[:transaction_type]]&.strip || 'expense'
        category_val = row[@header_map[:category]]&.strip
        status_val = row[@header_map[:status]]&.strip
        attachment_name_val = row[@header_map[:attachment_name]]&.strip

        # 2. Resolução de valores com normalização
        resolved_type_string = resolve_value_string(:transaction_type, type_val)
        
        # CORREÇÃO CRÍTICA: Normaliza o tipo de transação para minúsculo
        if resolved_type_string.present?
          resolved_type_string = resolved_type_string.downcase
        end
        
        category_strings = category_val.to_s.split(',').map(&:strip).reject(&:blank?)
        resolved_category_strings = category_strings.map { |cat| resolve_value_string(:category, cat) }.compact
        
        status_id = find_status_id(status_val)
        
        # 3. Construção da Descrição
        description_parts = [description_val]
        error_note = build_error_note(parsing_errors)
        description_parts << error_note if error_note
        
        if parsing_errors.key?(:responsavel)
          description_parts << "Responsável (original): #{responsible_name_val}"
        end

        if attachment_name_val.present?
          description_parts << "Anexo (original): #{attachment_name_val}"
        end

        # 4. Criação da Issue com validação extra
        issue_attributes = {
          tracker_id: FotonCashFlow::SettingsHelper.finance_tracker_id,
          project_id: @project.id,
          author: @user,
          status_id: status_id,
          assigned_to_id: responsible_user&.id,
          subject: description_val,
          description: description_parts.join("\n\n")
        }

        # Garante que os custom fields tenham valores válidos
        category_cf_object = @cf_objects[:category]
        category_value_to_assign = if category_cf_object&.multiple?
                                     resolved_category_strings
                                   else
                                     resolved_category_strings.first
                                   end

        custom_field_values = {}
        custom_field_values[@cf_objects[:entry_date]&.id] = parsed_date if @cf_objects[:entry_date]
        custom_field_values[@cf_objects[:amount]&.id] = parsed_amount if @cf_objects[:amount]
        custom_field_values[@cf_objects[:transaction_type]&.id] = resolved_type_string if @cf_objects[:transaction_type]
        custom_field_values[@cf_objects[:category]&.id] = category_value_to_assign if @cf_objects[:category]

        issue_attributes[:custom_field_values] = custom_field_values

        Rails.logger.info "[FOTON_CASH_FLOW][Importer] Creating issue for line #{line_number} with:"
        Rails.logger.info "  - Date: #{parsed_date}"
        Rails.logger.info "  - Amount: #{parsed_amount}"
        Rails.logger.info "  - Transaction Type: '#{resolved_type_string}'"
        Rails.logger.info "  - Categories: [#{resolved_category_strings.join(', ')}]"

        Issue.new(issue_attributes)
      end
      
      def import_row(row, line_number)
        issue = build_issue_from_row(row, line_number)
        return unless issue

        Rails.logger.info "[FOTON_CASH_FLOW][Importer] Attempting to save issue for line #{line_number}: #{issue.subject}"
        
        # Tenta salvar a issue com log detalhado
        unless issue.save
          error_details = issue.errors.full_messages.join(', ')
          Rails.logger.error "[FOTON_CASH_FLOW][Importer] Failed to save issue for line #{line_number}. Errors: #{error_details}"
          Rails.logger.error "[FOTON_CASH_FLOW][Importer] Issue attributes: #{issue.attributes.inspect}"
          Rails.logger.error "[FOTON_CASH_FLOW][Importer] Custom field values: #{issue.custom_field_values.inspect}"
          
          @errors << I18n.t('foton_cash_flow.errors.import_line_error', line: line_number, errors: error_details)
        else
          @imported_count += 1
          Rails.logger.info "[FOTON_CASH_FLOW][Importer] Successfully saved issue for line #{line_number}"
        end
      end
      
      def preprocess_creation_resolutions!
        Rails.logger.info "[FOTON_CASH_FLOW][Importer] Starting preprocess_creation_resolutions!"
        
        # CORREÇÃO: Processa resoluções para categorias primeiro
        category_resolutions = @resolutions.dig('category')
        if category_resolutions.is_a?(Hash)
          Rails.logger.info "[FOTON_CASH_FLOW][Importer] Processing category resolutions: #{category_resolutions.inspect}"
          
          category_resolutions.each do |value, resolution|
            if resolution == 'create_new' && value.present?
              Rails.logger.info "[FOTON_CASH_FLOW][Importer] Creating category: '#{value}'"
              create_new_category(value)
            end
          end
          
          # FORÇAR RELOAD do campo para garantir que as mudanças sejam refletidas
          if @cf_cache[:category]
            category_cf = CustomField.find(@cf_objects[:category].id)
            Rails.logger.info "[FOTON_CASH_FLOW][Importer] Categories after creation: #{category_cf.possible_values.inspect}"
          end
        end
        
        # NOVA FUNCIONALIDADE: Processa resoluções para tipos de transação se necessário
        transaction_type_resolutions = @resolutions.dig('transaction_type')
        if transaction_type_resolutions.is_a?(Hash)
          transaction_type_resolutions.each do |value, resolution|
            if resolution == 'create_new' && value.present?
              create_new_transaction_type(value)
            end
          end
        end
        
        Rails.logger.info "[FOTON_CASH_FLOW][Importer] Finished preprocess_creation_resolutions!"
      end

      def file_valid?
        if @file_content.blank?
          @errors << I18n.t('foton_cash_flow.errors.no_file_provided')
          return false
        end
        
        # VERIFICAÇÃO DE ENCODING: Garante que o arquivo é UTF-8 válido.
        # Se não for, o arquivo provavelmente foi salvo com uma codificação incompatível (ex: ISO-8859-1).
        unless @file_content.valid_encoding?
          @errors << I18n.t('foton_cash_flow.errors.invalid_encoding')
          return false
        end
        
        unless File.extname(@original_filename).casecmp('.csv').zero?
          @errors << I18n.t('foton_cash_flow.errors.invalid_file_format', format: '.csv')
          return false
        end
        
        true
      end

      def dependencies_met?
        if @cf_objects.values.any?(&:nil?) || FotonCashFlow::SettingsHelper.finance_tracker_id.blank?
          @errors << I18n.t('foton_cash_flow.errors.dependencies_not_met')
          return false
        end
        true
      end

      # Mapeia os cabeçalhos do arquivo CSV para as chaves internas do sistema.
      def map_headers_from_file(file_path, separator)
        csv_headers = CSV.read(file_path, headers: true, col_sep: separator, encoding: 'UTF-8').headers

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

      # Lê a primeira linha do arquivo para determinar o separador mais provável.
      def detect_separator(file_path)
        first_line = File.open(file_path, 'r', &:readline)
        # Retorna vírgula se houver mais vírgulas do que ponto e vírgulas.
        return ',' if first_line.count(',') > first_line.count(';')
        ';' # Caso contrário, assume o padrão ponto e vírgula.
      end

      def cache_custom_field_objects
        {
          entry_date: CustomField.find_by(id: FotonCashFlow::SettingsHelper.cf_id(:entry_date)),
          amount: CustomField.find_by(id: FotonCashFlow::SettingsHelper.cf_id(:amount)),
          transaction_type: CustomField.find_by(id: FotonCashFlow::SettingsHelper.cf_id(:transaction_type)),
          category: CustomField.find_by(id: FotonCashFlow::SettingsHelper.cf_id(:category))
        }
      end

      # ALTERADO: A resolução não cria mais o item, apenas mapeia para o valor correto.
      def resolve_value_string(column_key, original_value)
        resolution = @resolutions.dig(column_key.to_s, original_value)
        
        # Se a resolução for 'create_new' ou não houver resolução, o valor a ser usado é o original.
        # Se for um mapeamento (ex: 'Cat Antiga' -> 'Categoria Nova'), usa o valor da resolução.
        (resolution && resolution != 'create_new') ? resolution : original_value
      end

      # NOVO: Métodos auxiliares para limpar `build_issue_from_row`
      def parse_flexible_date(date_string)
        return nil if date_string.blank?
        
        begin
          Date.parse(date_string)
        rescue ArgumentError
          begin
            Date.strptime(date_string, '%B %d, %Y') # Ex: "August 19, 2024"
          rescue ArgumentError
            nil
          end
        end
      end
      
      def find_status_id(status_name)
        return FotonCashFlow::SettingsHelper.finance_tracker.default_status_id if status_name.blank?
        
        status = IssueStatus.find_by('LOWER(name) = :q', q: status_name.downcase)
        status&.id || FotonCashFlow::SettingsHelper.finance_tracker.default_status_id
      end

      def find_responsible_user(user_name)
        return nil if user_name.blank?
        User.find_by('LOWER(login) = :q OR LOWER(firstname) = :q OR LOWER(lastname) = :q OR LOWER(CONCAT(firstname, \' \', lastname)) = :q', q: user_name.downcase)
      end

      def find_association(type, name, line_number)
        Rails.logger.info "[FOTON_CASH_FLOW][Importer] Finding association for type: '#{type}', name: '#{name}' on line #{line_number}"
        return nil if name.blank?

        # Tipos de transação são apenas strings em uma lista, não um modelo.
        return name if type == :transaction_type
        
        # Outros tipos (se adicionados no futuro) podem ter sua lógica aqui.
        nil
      end

      # ALTERADO: A criação agora é mais robusta e chamada pelo método de pré-processamento.
      def create_new_category(value)
        Rails.logger.info "[FOTON_CASH_FLOW][Importer] Attempting to create category: '#{value}'"
        
        category_cf = @cf_objects[:category]
        unless category_cf&.field_format == 'list'
          Rails.logger.error "[FOTON_CASH_FLOW][Importer] Category custom field not found or not a list"
          return false
        end

        Rails.logger.info "[FOTON_CASH_FLOW][Importer] Current categories: #{category_cf.possible_values.inspect}"

        # Garante que o valor não seja adicionado novamente se já existir (case-insensitive)
        existing_values = category_cf.possible_values.map { |v| v.to_s.strip.downcase }
        if existing_values.include?(value.strip.downcase)
          Rails.logger.info "[FOTON_CASH_FLOW][Importer] Category '#{value}' already exists"
          return true
        end

        # Adiciona a nova categoria
        new_possible_values = category_cf.possible_values + [value]
        category_cf.possible_values = new_possible_values
        
        if category_cf.save!
          @newly_created_categories << value
          Rails.logger.info "[FOTON_CASH_FLOW][Importer] Category '#{value}' created successfully"
          Rails.logger.info "[FOTON_CASH_FLOW][Importer] Updated categories: #{category_cf.possible_values.inspect}"
          return true
        else
          error_msg = category_cf.errors.full_messages.join(', ')
          Rails.logger.error "[FOTON_CASH_FLOW][Importer] Failed to create category '#{value}': #{error_msg}"
          @errors << "Falha ao criar categoria '#{value}': #{error_msg}"
          return false
        end
      rescue => e
        Rails.logger.error "[FOTON_CASH_FLOW][Importer] Exception creating category '#{value}': #{e.message}"
        @errors << "Erro ao criar categoria '#{value}': #{e.message}"
        return false
      end
      
      # NOVO: Método para criar novos tipos de transação se necessário
      def create_new_transaction_type(value)
        transaction_type_cf = @cf_objects[:transaction_type]
        return unless transaction_type_cf&.field_format == 'list'

        # Normaliza o valor para minúsculo
        normalized_value = value.strip.downcase
        
        # Verifica se já existe
        existing_values = transaction_type_cf.possible_values.map { |v| v.to_s.strip.downcase }
        return if existing_values.include?(normalized_value)

        transaction_type_cf.possible_values << normalized_value
        if transaction_type_cf.save
          Rails.logger.info "[FOTON_CASH_FLOW][Importer] Novo tipo de transação criado: '#{normalized_value}'"
        else
          @errors << "Falha ao criar tipo de transação '#{normalized_value}': #{transaction_type_cf.errors.full_messages.join(', ')}"
        end
      end
    end
  end
end