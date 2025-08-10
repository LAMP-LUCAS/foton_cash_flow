# ./lib/foton_cash_flow/hooks.rb

# frozen_string_literal: true

module FotonCashFlow
  class Hooks < Redmine::Hook::ViewListener
    def view_layouts_base_html_head(context = {})
      controller = context[:controller]
      return unless controller
      return unless ['entries', 'settings', 'diagnostics'].include?(controller.controller_name)
      stylesheet_link_tag('cash_flow_main', plugin: 'foton_cash_flow') + # Carrega o CSS do plugin
        javascript_include_tag('application', plugin: 'foton_cash_flow')   # Carrega o JS unificado (incluindo Chart.js)
    end
  end
end

# Fim do hooks.rb
