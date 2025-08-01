
# Plugins/foton_cash_flow/app/controllers/settings_controller.rb

# Controller responsável pelas configurações do plugin Cash Flow Pro.
# Permite ao admin definir colunas padrão, projetos com tabela própria e usuários com acesso permanente.
# O admin SEMPRE terá acesso total ao plugin, independentemente das configurações.

require 'csv'

module FotonCashFlow
  class SettingsController < ApplicationController
    before_action :require_admin # Apenas administradores devem acessar as configurações

    # Exibe o formulário de configurações
    def index
      @settings = Setting.plugin_foton_cash_flow
    end

    # Salva as configurações do plugin
    def update
      # Usa strong parameters para segurança e clareza
      permitted_settings = params.require(:settings).permit(
        :default_currency,
        :show_in_top_menu,
        default_columns: [],
        custom_projects: [],
        permanent_users: [],
        categories: []
      )


      # Salva as configurações
      Setting.plugin_foton_cash_flow = Setting.plugin_foton_cash_flow.merge(permitted_settings.to_h)

      flash[:notice] = l(:notice_successful_update)
      redirect_to cash_flow_settings_path
    end

    private

    # O admin sempre tem acesso total ao plugin
    def require_admin
      unless User.current.admin?
        render_403
        return false
      end
    end
  end
end

#Fim do cash_flow_settings_controller.rb
