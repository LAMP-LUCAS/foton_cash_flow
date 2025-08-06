
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

    # Novo método para parsear strings de moeda para decimal
    def self.parse_currency_to_decimal(currency_string)
      return nil unless currency_string.present?
      
      # Remove qualquer símbolo de moeda e separador de milhar
      clean_string = currency_string.to_s.gsub(/[^0-9,\.]/, '')
      
      # Substitui a vírgula por ponto para o formato decimal
      # Lida com casos como "1.000,50" ou "1,000.50"
      if clean_string.count(',') > 1 # Caso de 1,000,000.00
        clean_string = clean_string.delete(',')
      elsif clean_string.include?('.') && clean_string.include?(',')
        # Se tem ponto e vírgula, e o ponto vem antes da vírgula
        # "1.000,50" -> 1000.50
        clean_string = clean_string.gsub('.', '').gsub(',', '.')
      elsif clean_string.include?(',')
        # "123,45" -> 123.45
        clean_string = clean_string.gsub(',', '.')
      end
      
      # Tenta converter para BigDecimal para precisão
      BigDecimal(clean_string)
    rescue ArgumentError, TypeError => e
      Rails.logger.error "[FOTON_CASH_FLOW][SettingsHelper] Falha ao converter valor de moeda '#{currency_string}' para decimal: #{e.message}"
      nil
    end
  end
end

#Fim do cash_flow_settings_controller.rb
