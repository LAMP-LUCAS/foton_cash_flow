# ./lib/foton_cash_flow/hooks.rb

# frozen_string_literal: true

module FotonCashFlow
  class Hooks < Redmine::Hook::ViewListener
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
