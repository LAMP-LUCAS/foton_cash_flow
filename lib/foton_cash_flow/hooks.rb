# ./lib/foton_cash_flow/hooks.rb

# frozen_string_literal: true

module FotonCashFlow
  class Hooks < Redmine::Hook::ViewListener
    #render_on :view_issues_new_top, partial: 'issues/foton_cash_flow_entry_date_script'
    # render_on :view_issues_new_form_content_bottom,
    #             :partial => 'issues/foton_cash_flow_custom_field_script'

    def view_layouts_base_html_head(context = {})
      controller_name = context[:controller]&.controller_name
      if controller_name && ['entries', 'settings'].include?(controller_name)
        context[:controller].render_to_string(
          partial: 'foton_cash_flow/shared/cash_flow_assets',
          locals: { plugin_assets_loaded: true }
        )
      end
    end
  end
end

# Fim do hooks.rb
