# ./app/controllers/foton_cash_flow/entries_controller.rb

module FotonCashFlow
  class EntriesController < ApplicationController
    include Rails.application.routes.url_helpers
    helper FotonCashFlow::EntriesHelper
    #helper :pagination # Opcional, se você tiver um helper de paginação separado.

    before_action :find_project, only: [:index]
    before_action :authorize_cash_flow, only: [:index]
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

      # Verifica as dependências.
      @dependencies_met = FotonCashFlow::SettingsHelper.all_dependencies_met?

      unless @dependencies_met
        flash.now[:warning] = l(:warning_cash_flow_dependencies_not_met_full)
        # Se as dependências não foram atendidas, inicializa as variáveis
        # para evitar erros na view e renderiza a página com o aviso.
        @query = Issue.none
        @total_revenue = @total_expense = @balance = BigDecimal('0.0')
        @bar_chart_labels = @bar_chart_revenue = @bar_chart_expense = @pie_chart_labels = @pie_chart_data = []
      else
        # O bloco a seguir será executado somente se as dependências forem atendidas.
        begin
          # Filtra as issues com base nos parâmetros
          @query = FotonCashFlow::Services::QueryBuilder.new(params, User.current).build
          Rails.logger.debug "[FOTON_CASH_FLOW][EntriesController] Query Builder retornou: #{@query.count} issues."

          # Calcula o sumário (receita, despesa, balanço)
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

      @issue_count = @query.count
      @limit = per_page_option
      @issue_pages = Paginator.new @issue_count, @limit, params['page']
      @offset = @issue_pages.offset
      @issues_for_table = @query.limit(@limit).offset(@offset)

      @cash_flow_status_collection = IssueStatus.all.map { |s| [s.name, s.id.to_s] }
      
      respond_to do |format|
        format.html
        format.csv { send_data FotonCashFlow::Services::Exporter.new(@query, Setting.plugin_foton_cash_flow['default_currency']).export_csv, filename: "fluxo_de_caixa_#{Time.now.strftime('%Y%m%d%H%M%S')}.csv" }
      end
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
        redirect_to cash_flow_entries_path(project_id: @project)
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
        redirect_to cash_flow_entries_path(project_id: @project)
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
      redirect_to cash_flow_entries_path(project_id: @project)
    end

    def import_form
      Rails.logger.info "[FOTON_CASH_FLOW][EntriesController] Iniciando CashFlow::EntriesController#import_form."
      # Mostra o formulário de importação
    end

    def import
      Rails.logger.info "[FOTON_CASH_FLOW][EntriesController] Iniciando CashFlow::EntriesController#import."
      if params[:csv_file].present?
        begin
          importer_service = FotonCashFlow::Services::Importer.new(params[:csv_file].path, @project)
          imported_count = importer_service.import
          Rails.logger.info "[FOTON_CASH_FLOW][EntriesController] #{imported_count} entradas importadas com sucesso."
          flash[:notice] = l(:notice_cash_flow_imported_successfully, count: imported_count)
          redirect_to cash_flow_entries_path(project_id: @project)
        rescue StandardError => e
          Rails.logger.error "[FOTON_CASH_FLOW][EntriesController] Erro na importação do fluxo de caixa: #{e.message}"
          flash[:error] = l(:error_cash_flow_import_failed, error: e.message)
          render :import_form, status: :unprocessable_entity
        end
      else
        Rails.logger.warn "[FOTON_CASH_FLOW][EntriesController] Nenhuma arquivo CSV fornecido para importação."
        flash[:error] = l(:error_no_csv_file_provided)
        render :import_form, status: :unprocessable_perhaps
      end
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
          return redirect_to cash_flow_settings_path, alert: l(:warning_internal_finance_project_not_set_and_needed)
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
      @filter_params = params.permit(:from_date, :to_date, :transaction_type, :category, :search, :project_id, :status, :author, :page)
      Rails.logger.debug "[FOTON_CASH_FLOW][EntriesController] [filter_params] Parâmetros filtrados: #{@filter_params.inspect}"
    end

    # def ensure_cash_flow_dependencies
    #   unless FotonCashFlow::SettingsHelper.all_dependencies_met?
    #     Rails.logger.error "[FOTON_CASH_FLOW][EntriesController] Dependências do fluxo de caixa não atendidas. Redirecionando."
    #     flash[:error] = l(:error_cash_flow_dependencies_missing) # Usa uma chave de tradução para a mensagem
    #     redirect_to diagnostics_path #default_rescue_path # Redireciona para um caminho seguro, como a página de configurações ou a home
    #     return false # Impede a execução posterior da action
    #   end
    #   true
    # end

    def find_issue_and_set_custom_fields
      Rails.logger.info "[FOTON_CASH_FLOW][EntriesController] [find_issue_and_set_custom_fields] Buscando Issue ID #{params[:id]} para o projeto #{@project&.id}."
      @issue = @project.issues.find(params[:id])
      Rails.logger.debug "[FOTON_CASH_FLOW][EntriesController] Issue encontrada: #{@issue.id}. Tipo: #{@issue.cash_flow_transaction_type}, Valor: #{@issue.cash_flow_amount}."
    rescue ActiveRecord::RecordNotFound
      Rails.logger.error "[FOTON_CASH_FLOW][EntriesController] Issue com ID '#{params[:id]}' não encontrada para o projeto '#{@project&.name}'."
      flash[:error] = l(:error_record_not_found, msg: "Lançamento de fluxo de caixa não encontrado.")
      redirect_to cash_flow_entries_path(project_id: @project)
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
          # Tenta ir para o index geral se não houver projeto
          Rails.logger.error "[FOTON_CASH_FLOW][EntriesController][default_rescue_path] Redirecionando para página do Fluxo de Caixa."
          cash_flow_entries_path
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

  end
end