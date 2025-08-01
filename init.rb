# frozen_string_literal: true

require 'redmine'
require_relative 'lib/foton_cash_flow'


Redmine::Plugin.register :foton_cash_flow do |config|
  Rails.logger.info "[FOTON_CASH_FLOW] Carregando plugin"
  name 'FOTON Fluxo de Caixa'
  author 'LAMP/foton'
  description 'Plugin de fluxo de caixa para Redmine desenvolvido pela comunidade FOTON'
  version '0.0.1'

  require_relative 'lib/foton_cash_flow/hooks' if File.exist?(File.join(__dir__, 'lib', 'foton_cash_flow', 'hooks.rb'))

  Rails.configuration.to_prepare do
    # Configuração de autoload
    plugin_lib_path = File.expand_path('../lib', __FILE__)
    plugin_app_path = File.expand_path('../app', __FILE__)

    [plugin_lib_path, plugin_app_path].each do |path|
      unless Rails.application.config.autoload_paths.include?(path)
        Rails.application.config.autoload_paths << path
        Rails.logger.info "[FOTON_CASH_FLOW] Adicionado ao autoload_paths: #{path}"
      end
    end

    # Patch da Issue
    unless Issue.included_modules.include?(FotonCashFlow::Patches::IssuePatch)
      Issue.send(:include, FotonCashFlow::Patches::IssuePatch)
    end
  end

  # Permissões atualizadas
  project_module :cash_flow_pro do
    
    permission :view_cash_flow, {
      'foton_cash_flow/entries': [:index, :show]
    }, public: true

    permission :manage_cash_flow_entries, {
      'foton_cash_flow/entries': [:new, :create, :edit, :update, :destroy, :import, :import_form, :export]
    }

    permission :manage_cash_flow_settings, {
      'foton_cash_flow/settings': [:index, :update],
      'foton_cash_flow/diagnostics': [:index, :run_sync], require: :member
    }
  end

  # Configurações (mantidas iguais)
  settings default: {
    'default_columns' => %w[entry_date transaction_type amount category description notes],
    'default_currency' => 'R$ ',
    'show_in_top_menu' => 'false',
    'internal_finance_project_id' => nil,
    'only_finance_project' => '0',
    'categories' => []
  }, partial: 'foton_cash_flow/settings/cash_flow_settings'

  menu :top_menu, :cash_flow_pro_top, { controller: 'foton_cash_flow/entries', action: 'index' },
       caption: :label_cash_flow_pro,
       if: ->(_context) { Setting.plugin_foton_cash_flow['show_in_top_menu'].to_s == 'true' }

  menu :project_menu, :cash_flow_pro, { controller: 'foton_cash_flow/entries', action: 'index' },
       caption: :label_cash_flow, param: :project_id,
       if: proc { |p| User.current.admin? || User.current.allowed_to?(:view_cash_flow, p) }
       
  menu :admin_menu, :foton_cash_flow_diagnostics, { controller: 'foton_cash_flow/diagnostics', action: 'index' },
       caption: :label_foton_cash_flow_diagnostics, html: { class: 'icon icon-server' },
       if: Proc.new { User.current.admin? || User.current.allowed_to?(:manage_cash_flow_settings, nil, global: true) }

  
  
       # REMOVIDO: Rails.application.config.autoload_paths += %W(#{config.directory}/lib)
end

# Fim do arquivo init.rb