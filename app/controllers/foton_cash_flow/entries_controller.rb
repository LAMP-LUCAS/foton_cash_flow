# ./app/controllers/foton_cash_flow/entries_controller.rb

module FotonCashFlow
  class EntriesController < ApplicationController
    include Rails.application.routes.url_helpers
    helper FotonCashFlow::EntriesHelper
    #helper :pagination # Opcional, se você tiver um helper de paginação separado.

    before_action :find_project, only: [:index, :import_form, :import, :export, :import_preview, :import_finalize]
    before_action :authorize_cash_flow, only: [:index, :import_form, :import, :export, :import_preview, :import_finalize]
    # Garante que o usuário esteja logado para as ações de importação
    before_action :require_login, only: [:import_form, :import_preview, :import_finalize]

    before_action :filter_params, only: [:index, :export] 
    before_action :check_dependencies_and_set_flash, only: [:index]
    #before_action :ensure_cash_flow_dependencies
    before_action :find_issue_and_set_custom_fields, only: [:edit, :update, :destroy]
    before_action :set_new_cash_flow_entry, only: [:new, :create]
    
    rescue_from Exception, with: :handle_server_error # Para capturar qualquer erro e redirecionar
    rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
    rescue_from ActionController::ParameterMissing, with: :parameter_missing

    def index
      Rails.logger.info "[FOTON_CASH_FLOW][EntriesController] Iniciando CashFlow::EntriesController#index."

      @dependencies_met = FotonCashFlow::SettingsHelper.all_dependencies_met?

      unless @dependencies_met
        flash.now[:warning] = l(:warning_cash_flow_dependencies_not_met_full)
        @query = Issue.none
        @total_revenue = @total_expense = @balance = BigDecimal('0.0')
        @bar_chart_labels = @bar_chart_revenue = @bar_chart_expense = @pie_chart_labels = @pie_chart_data = []
      else
        begin
          @query = FotonCashFlow::Services::QueryBuilder.new(params, User.current).build
          
          # --- Adiciona a nova lógica de filtragem por servidor aqui ---
          @query = apply_server_side_filters(@query)
          # -----------------------------------------------------------

          Rails.logger.debug "[FOTON_CASH_FLOW][EntriesController] Query Builder retornou: #{@query.count} issues."

          summary_service = FotonCashFlow::Services::SummaryService.new(@query)
          summary_service.calculate
          @total_revenue = summary_service.total_revenue
          @total_expense = summary_service.total_expense
          @balance = summary_service.balance
          @bar_chart_labels = summary_service.bar_chart_labels
          @bar_chart_revenue = summary_service.bar_chart_revenue
          @bar_chart_expense = summary_service.bar_chart_expense
          @pie_chart_labels = summary_service.pie_chart_labels
          @pie_chart_data = summary_service.pie_chart_data
        rescue => e
          Rails.logger.error "[FOTON_CASH_FLOW][EntriesController] Erro não crítico durante a execução do index: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
          flash.now[:error] = l(:error_cash_flow_processing_failed, msg: e.message)
          @query = Issue.none
          @total_revenue = @total_expense = @balance = BigDecimal('0.0')
          @bar_chart_labels = @bar_chart_revenue = @bar_chart_expense = @pie_chart_labels = @pie_chart_data = []
        end
      end

      # Contagem correta de issues, garantindo que a contagem seja de IDs distintos
      # para evitar contagens infladas por JOINs na query.
      @issue_count = @query.distinct.count
      @limit = per_page_option  # || 25 # Garante um valor padrão para o limite
      @issue_pages = Paginator.new @issue_count, @limit, params['page']
      @offset = @issue_pages.offset

      # --- CORREÇÃO E OTIMIZAÇÃO ---

      # 1. Obter apenas os IDs únicos das issues para a página atual.
      #    O .distinct é crucial para evitar que a mesma issue apareça múltiplas vezes na tabela.
      paginated_issue_ids = @query.distinct.limit(@limit).offset(@offset).pluck(:id)

      # 2. Fazer uma query limpa usando esses IDs para carregar os objetos
      #    com as associações (eager loading), resolvendo o problema de N+1.
      #    Usamos um hash para reordenar os resultados na ordem original da query.
      issues_map = Issue.where(id: paginated_issue_ids).includes(:status, :assigned_to).index_by(&:id)
      @issues_for_table = paginated_issue_ids.map { |id| issues_map[id] }.compact

      # 3. Corrigir o cálculo de @categories para ser eficiente e correto, buscando
      #    os valores distintos do campo personalizado diretamente do banco.
      category_cf_id = FotonCashFlow::SettingsHelper.cf_id(:category)
      @categories = CustomValue.where(custom_field_id: category_cf_id, customized_type: 'Issue', customized_id: @query.select(:id)).pluck(:value).uniq.compact.sort      
      
      # Otimização: Busca os status uma única vez e reutiliza a variável.
      # .order() é mais eficiente que .all.sort_by() pois ordena no banco.
      @statuses = IssueStatus.order(:position).to_a
      @cash_flow_status_collection = @statuses.map { |s| [s.name, s.id.to_s] }
      # A exportação CSV é tratada pela ação #export para maior clareza.
    end

    def new
      Rails.logger.info "[FOTON_CASH_FLOW][EntriesController] Iniciando CashFlow::EntriesController#new."
      # @issue já está definido pelo before_action set_new_cash_flow_entry
    end

    def create
      Rails.logger.info "[FOTON_CASH_FLOW][EntriesController] Iniciando CashFlow::EntriesController#create."
      @issue.assign_attributes(issue_params)
      if @issue.save
        Rails.logger.info "[FOTON_CASH_FLOW][EntriesController] Entrada de fluxo de caixa criada com sucesso: Issue ID #{@issue.id}."
        flash[:notice] = l(:notice_successful_create)
        redirect_to project_cash_flow_entries_path(@project)
      else
        Rails.logger.error "[FOTON_CASH_FLOW][EntriesController] Erro ao criar entrada de fluxo de caixa: #{@issue.errors.full_messages.join(', ')}"
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      Rails.logger.info "[FOTON_CASH_FLOW][EntriesController] Iniciando CashFlow::EntriesController#edit para Issue ID #{@issue.id}."
      # @issue já está definido pelo before_action find_issue_and_set_custom_fields
    end

    def update
      Rails.logger.info "[FOTON_CASH_FLOW][EntriesController] Iniciando CashFlow::EntriesController#update para Issue ID #{@issue.id}."
      if @issue.update(issue_params)
        Rails.logger.info "[FOTON_CASH_FLOW][EntriesController] Entrada de fluxo de caixa atualizada com sucesso: Issue ID #{@issue.id}."
        flash[:notice] = l(:notice_successful_update)
        redirect_to project_cash_flow_entries_path(@project)
      else
        Rails.logger.error "[FOTON_CASH_FLOW][EntriesController] Erro ao atualizar entrada de fluxo de caixa: #{@issue.errors.full_messages.join(', ')}"
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      Rails.logger.info "[FOTON_CASH_FLOW][EntriesController] Iniciando CashFlow::EntriesController#destroy para Issue ID #{@issue.id}."
      if @issue.destroy
        Rails.logger.info "[FOTON_CASH_FLOW][EntriesController] Entrada de fluxo de caixa deletada com sucesso: Issue ID #{@issue.id}."
        flash[:notice] = l(:notice_successful_delete)
      else
        Rails.logger.error "[FOTON_CASH_FLOW][EntriesController] Erro ao deletar entrada de fluxo de caixa: #{@issue.errors.full_messages.join(', ')}"
        flash[:error] = l(:error_unable_to_delete)
      end
      redirect_to project_cash_flow_entries_path(@project)
    end

    def import_form
      # Esta action pode até ficar vazia,
      # pois o before_action :find_project já vai definir @project
      # para a view ser renderizada corretamente.
      logger.info "[FOTON_CASH_FLOW][EntriesController] Iniciando CashFlow::EntriesController#import_form."
    end

    # Lógica substituída pelas duas abaixo, conferir se não perdeu informações.
    def import
      Rails.logger.info "[FOTON_CASH_FLOW][EntriesController] Iniciando CashFlow::EntriesController#import."
      if params[:csv_file].present?
        begin
          # **MELHORIA**: Passa o conteúdo e o nome do arquivo separadamente.
          importer_service = FotonCashFlow::Services::Importer.new(
            params[:csv_file].read, 
            User.current, 
            @project, 
            original_filename: params[:csv_file].original_filename)
          
          # Supondo que `importer_service.call` agora retorna `true` ou `false` e que o serviço
          # armazena os erros e as novas categorias criadas em atributos acessíveis.
          if importer_service.call
            notice_messages = []
            
            # 1. Mensagem de sucesso da importação
            notice_messages << l(:notice_cash_flow_imported_successfully, count: importer_service.imported_count)
            
            # 2. Verifica se novas categorias foram criadas e adiciona à mensagem de aviso
            if importer_service.newly_created_categories.present?
              new_categories = importer_service.newly_created_categories.join(', ')
              notice_messages << l(:notice_new_categories_created, categories: new_categories)
              Rails.logger.info "[FOTON_CASH_FLOW][EntriesController] Novas categorias criadas automaticamente: #{new_categories}"
            end

            flash[:notice] = notice_messages.join(' ')
            redirect_to project_cash_flow_entries_path(@project)
          else
            Rails.logger.error "[FOTON_CASH_FLOW][EntriesController] Erro na importação do fluxo de caixa: #{importer_service.errors.join(', ')}"
            flash.now[:error] = l(:error_cash_flow_import_failed, error: importer_service.errors.join(', '))
            render :import_form, status: :unprocessable_entity
          end
        rescue StandardError => e
          Rails.logger.error "[FOTON_CASH_FLOW][EntriesController] Erro na importação do fluxo de caixa: #{e.message}"
          flash.now[:error] = l(:error_cash_flow_import_failed, error: e.message)
          render :import_form, status: :unprocessable_entity
        end
      else
        Rails.logger.warn "[FOTON_CASH_FLOW][EntriesController] Nenhuma arquivo CSV fornecido para importação."
        flash.now[:error] = l(:error_no_csv_file_provided)
        render :import_form, status: :unprocessable_entity
      end
    end

    # ETAPA 1: Recebe o arquivo, faz a pré-análise e retorna os conflitos como JSON.
    def import_preview
      Rails.logger.info "[FOTON_CASH_FLOW][EntriesController] Iniciando pré-análise de importação."
      unless params[:csv_file].present?
        return render json: { error: l(:error_no_csv_file_provided) }, status: :bad_request
      end

      # Usamos um service object para a lógica de negócio
      preview_service = FotonCashFlow::Services::PreviewImporter.new(params[:csv_file].path, @project)
      preview_service.call

      if preview_service.conflicts.empty?
        # Sem conflitos, podemos importar diretamente
        importer_service = FotonCashFlow::Services::Importer.new(
          params[:csv_file].read, 
          User.current, 
          @project,
          original_filename: params[:csv_file].original_filename
        )
        importer_service.call # Executa a importação
        flash[:notice] = l(:notice_cash_flow_imported_successfully, count: importer_service.imported_count)
        render json: { redirect_url: project_cash_flow_entries_path(@project) }
      else
        # Há conflitos. Armazena o arquivo temporariamente e envia os conflitos para o frontend.
        temp_file_key = "import_cache_#{SecureRandom.hex(16)}"
        # **MELHORIA**: Armazena o conteúdo do arquivo e os conflitos no cache.
        cached_data = {
          file_content: File.read(params[:csv_file].path),
          original_filename: params[:csv_file].original_filename,
          conflicts: preview_service.conflicts
        }
        Rails.cache.write(temp_file_key, cached_data, expires_in: 30.minutes)

        render json: {
          conflicts: preview_service.conflicts,
          data_key: temp_file_key 
        }, status: :ok
      end
    rescue => e
      Rails.logger.error "[FOTON_CASH_FLOW][EntriesController][Preview] Erro: #{e.message}"
      render json: { error: l(:error_cash_flow_import_failed, error: e.message) }, status: :internal_server_error
    end

    # ETAPA 2: Recebe as resoluções do modal e finaliza a importação.
    def import_finalize
      Rails.logger.info "[FOTON_CASH_FLOW][EntriesController] Finalizando importação com resoluções."
      data_key = params[:data_key]
      
      # **CORREÇÃO:** Pega o hash de resoluções diretamente.
      # O método `permit!` é usado aqui por simplicidade, pois já confiamos nos dados
      # que nosso próprio frontend montou. Em um cenário de API pública, seria necessário
      # uma permissão mais granular.
      user_resolutions = params.require(:resolutions).permit! if params[:resolutions]
      
      cached_data = Rails.cache.read(data_key)
      unless cached_data
        return render json: { error: l(:error_import_session_expired) }, status: :bad_request
      end

      # **CORREÇÃO:** Remove a lógica de transformação complexa e desnecessária.
      # O objeto `user_resolutions` já está no formato correto que o Importer espera:
      # { "category" => { "Valor Inválido" => "Valor Escolhido" } }
      
      importer_service = FotonCashFlow::Services::Importer.new(
        cached_data[:file_content], 
        User.current, 
        @project, 
        resolutions: user_resolutions || {}, # <-- Passa as resoluções diretamente
        original_filename: cached_data[:original_filename]
      )
      
      if importer_service.call
        notice_messages = [l(:notice_cash_flow_imported_successfully, count: importer_service.imported_count)]
        if importer_service.newly_created_categories.present?
          notice_messages << l(:notice_new_categories_created, categories: importer_service.newly_created_categories.join(', '))
        end
        flash[:notice] = notice_messages.join(' ')
        render json: { redirect_url: project_cash_flow_entries_path(@project) }
      else
        render json: { error: l(:error_cash_flow_import_failed, error: importer_service.errors.join(', ')) }, status: :unprocessable_entity
      end
    ensure
      # Limpa o arquivo do cache após a tentativa
      Rails.cache.delete(data_key) if data_key.present?
    end

    def export
      Rails.logger.info "[FOTON_CASH_FLOW][EntriesController] Iniciando CashFlow::EntriesController#export."
      @query = FotonCashFlow::Services::QueryBuilder.new(params, User.current).build # Rebuild query for export
      csv_data = FotonCashFlow::Services::Exporter.new(@query, Setting.plugin_foton_cash_flow['default_currency']).export_csv
      send_data csv_data, filename: "fluxo_de_caixa_#{Time.now.strftime('%Y%m%d%H%M%S')}.csv", type: 'text/csv', disposition: 'attachment'
      Rails.logger.info "[FOTON_CASH_FLOW][EntriesController] Dados de fluxo de caixa exportados com sucesso."
    end


    private

    def find_project
      Rails.logger.info "[FOTON_CASH_FLOW][EntriesController] [find_project] Iniciando. project_param: #{params[:project_id].inspect}, action_name: #{action_name}"
      @project = Project.find(params[:project_id]) unless params[:project_id].blank?
      # Se project_id não for fornecido e only_finance_project for 1, tenta usar o projeto financeiro interno
      if @project.nil? && Setting.plugin_foton_cash_flow['only_finance_project'].to_s == '1'
        internal_finance_project_id = FotonCashFlow::SettingsHelper.internal_finance_project_id
        if internal_finance_project_id.present?
          @project = Project.find_by(id: internal_finance_project_id)
          Rails.logger.info "[FOTON_CASH_FLOW][EntriesController] [find_project] Usando projeto financeiro interno: #{@project&.name} (ID: #{@project&.id})"
        end
      end

      unless @project || (action_name == 'index' && Setting.plugin_foton_cash_flow['only_finance_project'].to_s == '0')
        # Permite index sem projeto se 'only_finance_project' não estiver ativo
        # ou se o projeto financeiro interno não estiver definido e 'only_finance_project' for 1
        if Setting.plugin_foton_cash_flow['only_finance_project'].to_s == '1' && FotonCashFlow::SettingsHelper.internal_finance_project_id.blank?
          Rails.logger.warn "[FOTON_CASH_FLOW][EntriesController] [find_project] Redirecionando: Projeto não encontrado ou financeiro interno não configurado."
          return redirect_to foton_cash_flow_settings_path, alert: l(:warning_internal_finance_project_not_set_and_needed)
        end
      end
      Rails.logger.info "[FOTON_CASH_FLOW][EntriesController] [find_project] Finalizado. @project é #{@project&.name} (ID: #{@project&.id})"
    rescue ActiveRecord::RecordNotFound
      Rails.logger.error "[FOTON_CASH_FLOW][EntriesController] [find_project] Projeto com ID '#{params[:project_id]}' não encontrado."
      flash[:error] = l(:error_project_not_found)
      redirect_to default_rescue_path
    end

    def authorize_cash_flow
      Rails.logger.info "[FOTON_CASH_FLOW][EntriesController] [authorize_cash_flow] Iniciando. Current user: #{User.current.login} (Admin: #{User.current.admin?}). Project: #{@project&.name} (ID: #{@project&.id})"
      case action_name
      when 'index', 'show'
        # Permissão de visualização é pública ou requer view_cash_flow no projeto
        unless User.current.admin? || User.current.allowed_to?(:view_cash_flow, @project, global: true)
          Rails.logger.warn "[FOTON_CASH_FLOW][EntriesController] [authorize_cash_flow] Usuário '#{User.current.login}' sem permissão para visualizar fluxo de caixa no projeto '#{@project&.name}'."
          deny_access
        end
      when 'new', 'create', 'edit', 'update', 'destroy', 'import', 'import_form', 'export'
        unless User.current.admin? || User.current.allowed_to?(:manage_cash_flow_entries, @project, global: true)
          Rails.logger.warn "[FOTON_CASH_FLOW][EntriesController] [authorize_cash_flow] Usuário '#{User.current.login}' sem permissão para gerenciar entradas de fluxo de caixa no projeto '#{@project&.name}'."
          deny_access
        end
      when 'run_sync' # Diagnósticos
        unless User.current.admin? || User.current.allowed_to?(:manage_cash_flow_settings, nil, global: true)
          Rails.logger.warn "[FOTON_CASH_FLOW][EntriesController] [authorize_cash_flow] Usuário '#{User.current.login}' sem permissão para gerenciar configurações/diagnósticos de fluxo de caixa."
          deny_access
        end
      end
      Rails.logger.info "[FOTON_CASH_FLOW][EntriesController] [authorize_cash_flow] Finalizado."
    end

    def filter_params
      @filter_params = params.permit(
        :from_date, :to_date, :search, :project_id, :author, :page,
        :query_transaction_type, :query_status, :query_category
      )
      Rails.logger.debug "[FOTON_CASH_FLOW][EntriesController] [filter_params] Parâmetros filtrados: #{@filter_params.inspect}"
    end

    def find_issue_and_set_custom_fields
      Rails.logger.info "[FOTON_CASH_FLOW][EntriesController] [find_issue_and_set_custom_fields] Buscando Issue ID #{params[:id]} para o projeto #{@project&.id}."
      @issue = @project.issues.find(params[:id])
      Rails.logger.debug "[FOTON_CASH_FLOW][EntriesController] Issue encontrada: #{@issue.id}. Tipo: #{@issue.cash_flow_transaction_type}, Valor: #{@issue.cash_flow_amount}."
    rescue ActiveRecord::RecordNotFound
      Rails.logger.error "[FOTON_CASH_FLOW][EntriesController] Issue com ID '#{params[:id]}' não encontrada para o projeto '#{@project&.name}'."
      flash[:error] = l(:error_record_not_found, msg: "Lançamento de fluxo de caixa não encontrado.")
      redirect_to project_cash_flow_entries_path(@project)
    end

    def set_new_cash_flow_entry
      Rails.logger.info "[FOTON_CASH_FLOW][EntriesController] [set_new_cash_flow_entry] Criando nova entrada de fluxo de caixa."
      @issue = Issue.new(project: @project, tracker_id: FotonCashFlow::SettingsHelper.finance_tracker_id)
      @issue.author = User.current # Define o autor padrão como o usuário atual

      # Define valores padrão para campos personalizados se aplicável
      # Por exemplo, definir a data de lançamento como a data atual
      entry_date_cf = CustomField.find_by_name(FotonCashFlow::SettingsHelper::CUSTOM_FIELD_NAMES[:entry_date])
      if entry_date_cf
        @issue.custom_field_values = { entry_date_cf.id => format_date(Date.current) }
      end
      Rails.logger.debug "[FOTON_CASH_FLOW][EntriesController] Nova Issue para fluxo de caixa preparada. Project ID: #{@issue.project_id}, Tracker ID: #{@issue.tracker_id}."
    end

    def issue_params
      params.require(:issue).permit(:subject, :description, :project_id, :tracker_id, :status_id, :priority_id, custom_field_values: {})
    end

    # Helper para parsear datas, se necessário
    def parse_date(date_string)
      return nil unless date_string.present?
      Date.parse(date_string) rescue nil
    end

    # Tratamento de erro para registro não encontrado
    def record_not_found(exception)
      Rails.logger.error "[FOTON_CASH_FLOW][EntriesController][RECORD_NOT_FOUND] Registro não encontrado: #{exception.message}"
      flash[:error] = l(:error_record_not_found, msg: exception.message)
      redirect_to default_rescue_path
    end

    # Tratamento de erro para parâmetro obrigatório faltando
    def parameter_missing(exception)
      Rails.logger.error "[FOTON_CASH_FLOW][EntriesController][PARAMETER_MISSING] Parâmetros faltando: #{exception.message}"
      flash[:error] = l(:error_parameter_missing, msg: exception.message)
      redirect_to default_rescue_path
    end

    # Tratamento genérico de erros de servidor
    def handle_server_error(exception)
      Rails.logger.error "[FOTON_CASH_FLOW][EntriesController][SERVER_ERROR] Erro interno do servidor: #{exception.message}"
      Rails.logger.error exception.backtrace.join("\n")
      flash[:error] = l(:error_internal_server_error, msg: exception.message)
      redirect_to default_rescue_path
    end

    # Define o caminho padrão para redirecionamentos de resgate
    def default_rescue_path
      begin
        if @project.present?
          Rails.logger.error "[FOTON_CASH_FLOW][EntriesController][default_rescue_path] Redirecionando para página do projeto."
          project_path(@project) 
        else
          # Se não houver projeto, redireciona para a página inicial como um fallback seguro.
          Rails.logger.error "[FOTON_CASH_FLOW][EntriesController][default_rescue_path] Redirecionando para a página inicial (sem projeto definido)."
          home_path
        end
      rescue => e
        Rails.logger.error "[FOTON_CASH_FLOW][EntriesController][default_rescue_path] Erro inesperado no default_rescue_path: #{e.message}"
        home_path
      end
    end

    def check_dependencies_and_set_flash
      Rails.logger.info "[FOTON_CASH_FLOW][EntriesController] Verificando dependências antes de carregar o índice."
      @dependencies_met = FotonCashFlow::SettingsHelper.all_dependencies_met?
      unless @dependencies_met
        flash.now[:warning] = l(:warning_cash_flow_dependencies_not_met)
        # O modal de sincronização será exibido na view
      end
      # @sync_issues_count = FotonCashFlow::Services::SynchronizationService.new.unsynced_issues_count
      # No momento, esta linha foi comentada pois não há um SynchronizationService disponível.
      # Será necessário implementar um serviço para verificar as issues não sincronizadas.
      # Por ora, a lógica do modal será baseada apenas no status geral das dependências.
    end

    def apply_server_side_filters(query)
      filtered_query = query
      # Filtro por tipo de transação (custom field)
      if params[:query_transaction_type].present?
        cf_id = FotonCashFlow::SettingsHelper.cf_id(:transaction_type)
        filtered_query = filtered_query.by_cash_flow_cf_value(cf_id, params[:query_transaction_type])
      end
      # Filtro por status (coluna padrão)
      if params[:query_status].present?
        filtered_query = filtered_query.by_status(params[:query_status])
      end
      # Filtro por categoria (custom field)
      if params[:query_category].present?
        cf_id = FotonCashFlow::SettingsHelper.cf_id(:category)
        filtered_query = filtered_query.by_cash_flow_cf_value(cf_id, params[:query_category])
      end

      # Exemplo de como você poderia usar outros filtros se necessário
      # filtered_query = filtered_query.by_cash_flow_cf_date_range(...)
      # filtered_query = filtered_query.by_subject(...)

      filtered_query
    end

    
  end
end