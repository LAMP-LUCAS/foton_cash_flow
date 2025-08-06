# plugins/foton_cash_flow/init.rb

# frozen_string_literal: true

require 'redmine'
require_relative 'lib/foton_cash_flow'
require_relative 'lib/foton_cash_flow/patches/issue_patch'

Redmine::Plugin.register :foton_cash_flow do |config|
  Rails.logger.info "[FOTON_CASH_FLOW] Carregando plugin"
  name 'FOTON Fluxo de Caixa'
  author 'LAMP/foton'
  description 'Plugin de fluxo de caixa para Redmine desenvolvido pela comunidade FOTON'
  version '0.0.1'

  #ActionController::Base.asset_host = proc { |source| "/plugin_assets/foton_cash_flow" }

  # Garante que o patch da Issue seja incluído imediatamente na classe Issue.
  # Isso é mais robusto do que usar um callback.
  unless Issue.included_modules.include?(FotonCashFlow::Patches::IssuePatch)
    Issue.send(:include, FotonCashFlow::Patches::IssuePatch)
    Rails.logger.info "[FOTON_CASH_FLOW] Patch 'IssuePatch' incluído com sucesso na classe Issue."
  else
    Rails.logger.info "[FOTON_CASH_FLOW] Patch 'IssuePatch' já incluído. Pulando."
  end

  # Carregamento do hook para o layout do Redmine
  require_relative 'lib/foton_cash_flow/hooks' if File.exist?(File.join(__dir__, 'lib', 'foton_cash_flow', 'hooks.rb'))

  # Use `ActiveSupport::Reloader.to_prepare` para garantir que o patch seja aplicado
  # corretamente em um ambiente Rails 7.
  ActiveSupport::Reloader.to_prepare do
    Rails.logger.info "[FOTON_CASH_FLOW] Verificando e aplicando patches..."

    unless Issue.included_modules.include?(FotonCashFlow::Patches::IssuePatch)
      Issue.send(:include, FotonCashFlow::Patches::IssuePatch)
      Rails.logger.info "[FOTON_CASH_FLOW] Patch 'IssuePatch' incluído com sucesso na classe Issue."
    else
      Rails.logger.info "[FOTON_CASH_FLOW] Patch 'IssuePatch' já incluído. Pulando."
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
      'foton_cash_flow/diagnostics': [:index, :run_sync]
    }, require: :member
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

end