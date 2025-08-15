# plugins/foton_cash_flow/init.rb

# frozen_string_literal: true

require 'redmine'

Redmine::Plugin.register :foton_cash_flow do # |config|
  Rails.logger.info "[FOTON_CASH_FLOW] Carregando plugin"
  name 'FOTON Fluxo de Caixa'
  author 'LAMP/foton'
  description 'Plugin de fluxo de caixa para Redmine desenvolvido pela comunidade FOTON'
  version '0.0.1-alpha.2'

  # Carregamento do hook para o layout do Redmine
  require_relative 'lib/foton_cash_flow/hooks' if File.exist?(File.join(__dir__, 'lib', 'foton_cash_flow', 'hooks.rb'))

  # Use `ActiveSupport::Reloader.to_prepare` para garantir que o patch seja aplicado
  # corretamente em um ambiente Rails 7.
  ActiveSupport::Reloader.to_prepare do
    Rails.logger.info "[FOTON_CASH_FLOW] Verificando e aplicando patches..."
    # Carregamento dos arquivos dos patches aqui
    require_relative 'lib/foton_cash_flow'
    require_relative 'lib/foton_cash_flow/patches/issue_patch'
    require_dependency 'foton_cash_flow/patches/issue_custom_field_patch'
    require_dependency 'foton_cash_flow/patches/issue_custom_value_patch'

    #FotonCashFlow::EntriesController.send(:helper, Redmine::PluginAssets::Helper)

    # Carrega e aplica todos os patches de forma segura.
    # O uso de require_dependency é a forma correta de garantir que as classes
    # do Redmine sejam carregadas antes de tentarmos modificá-las.
    patch_map = {
      Issue: FotonCashFlow::Patches::IssuePatch,
      IssueCustomField: FotonCashFlow::Patches::IssueCustomFieldPatch,
      IssueCustomValue: FotonCashFlow::Patches::IssueCustomValuePatch
    }

    patch_map.each do |klass_name, patch_module|
      klass = klass_name.to_s.constantize
      if klass.included_modules.exclude?(patch_module)
        klass.send(:include, patch_module)
        Rails.logger.info "[FOTON_CASH_FLOW] Patch '#{patch_module}' aplicado com sucesso em '#{klass_name}'."
      end
    end
  end

  # Permissões atualizadas
  project_module :foton_cash_flow do
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
  
    permission :edit_cash_flow_entry_date, {
      :entries => [:update_date] }, :require => :member
  
  
    end

  # Configurações (mantidas iguais)
  settings default: {
    'default_columns' => %w[entry_date transaction_type amount category description notes],
    'default_currency' => 'R$ ',
    'show_in_top_menu' => 'true',
    'top_menu_group_id' => nil,
    'internal_finance_project_id' => nil,
    'only_finance_project' => '0',
    'categories' => []
  }, partial: 'foton_cash_flow/settings/cash_flow_settings'

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
       if: Proc.new { User.current.admin? || User.current.allowed_to?(:manage_cash_flow_settings, nil, global: true) }

end