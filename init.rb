# frozen_string_literal: true

require 'redmine'

# --- CARREGAMENTO E APLICAÇÃO DIRETA DOS PATCHES ---
# Esta abordagem força o carregamento e a aplicação dos patches
# no momento em que o plugin é lido pela primeira vez.

# 1. Carrega os arquivos onde os módulos dos patches estão definidos.
# require_relative 'lib/foton_cash_flow/patches/issue_patch'
# require_relative 'lib/foton_cash_flow/patches/issue_custom_field_patch'
# require_relative 'lib/foton_cash_flow/patches/issue_custom_value_patch'
# require_relative 'lib/foton_cash_flow/patches/issues_controller_patch'
require_relative 'lib/foton_cash_flow'


# 2. Força o carregamento das classes do core do Redmine ANTES de tentar modificá-las.
#    Esta é a correção para o erro 'uninitialized constant'.
require_dependency 'issue'
require_dependency 'custom_field'
require_dependency 'custom_value'

# 3. Aplica os patches de forma explícita e segura.
begin
  Rails.logger.info "FotonCashFlow: Aplicando patches..."
  Issue.send(:include, FotonCashFlow::Patches::IssuePatch)
  IssueCustomField.send(:include, FotonCashFlow::Patches::IssueCustomFieldPatch)
  CustomValue.send(:include, FotonCashFlow::Patches::CustomValuePatch)
  Rails.logger.info "FotonCashFlow: Patches aplicados com sucesso. #{Issue.count} / #{IssueCustomField.count} / #{CustomValue.count} "
rescue => e
  Rails.logger.error "FotonCashFlow: Erro ao aplicar patches: #{e.message}"
end

# --- REGISTRO DO PLUGIN ---
Redmine::Plugin.register :foton_cash_flow do
  name 'FOTON Fluxo de Caixa'
  author 'LAMP/foton'
  description 'Plugin de fluxo de caixa para Redmine desenvolvido pela comunidade FOTON'
  version '0.0.1-alpha.2'

  require_relative 'lib/foton_cash_flow/hooks' if File.exist?(File.join(__dir__, 'lib', 'foton_cash_flow', 'hooks.rb'))

  # O resto do arquivo (permissões, settings, menu) permanece igual.
  project_module :foton_cash_flow do
    permission :view_cash_flow, { 'foton_cash_flow/entries': [:index, :show] }, public: true
    permission :manage_cash_flow_entries, { 'foton_cash_flow/entries': [:new, :create, :edit, :update, :destroy, :import, :import_form, :export] }
    permission :manage_cash_flow_settings, { 'foton_cash_flow/settings': [:index, :update], 'foton_cash_flow/diagnostics': [:index, :run_sync] }, require: :member
    permission :edit_cash_flow_entry_date, { entries: [:update_date] }, require: :member
  end

  settings default: {
    'default_columns' => %w[entry_date transaction_type amount category description notes],
    'default_currency' => 'R$ ',
    'show_in_top_menu' => 'true',
    'top_menu_group_id' => nil,
    'internal_finance_project_id' => nil,
    'only_finance_project' => '0',
    'categories' => [],
    'permanent_users' => []
  }, partial: 'foton_cash_flow/settings/cash_flow_settings'
  
  Rails.logger.info "FotonCashFlow: Padrões e configurações definidos com sucesso."

  # Definição de menus
  menu :top_menu, :foton_cash_flow_top, { controller: 'foton_cash_flow/entries', action: 'index' },
       caption: :label_foton_cash_flow,
       if: proc {
         show_link = Setting.plugin_foton_cash_flow['show_in_top_menu'].to_s == 'true'
         next false unless show_link
         group_id = Setting.plugin_foton_cash_flow['top_menu_group_id']
         User.current.admin? || (group_id.present? && User.current.groups.exists?(group_id.to_i))
       }

  menu :project_menu, :foton_cash_flow, { controller: 'foton_cash_flow/entries', action: 'index' },
       caption: :label_cash_flow, param: :project_id,
       if: proc { |p| p.module_enabled?(:foton_cash_flow) && (User.current.admin? || User.current.allowed_to?(:view_cash_flow, p)) }

  menu :admin_menu, :foton_cash_flow_diagnostics, { controller: 'foton_cash_flow/diagnostics', action: 'index' },
       caption: :label_foton_cash_flow_diagnostics, html: { class: 'icon icon-server' },
       if: proc { User.current.admin? || User.current.allowed_to?(:manage_cash_flow_settings, nil, global: true) }

  Rails.logger.info "FotonCashFlow: Plugin registrado com sucesso."
  # --- FIM DE TODO O CÓDIGO DO PLUGIN ---
end