# ./lib/foton_cash_flow/hooks.rb

# frozen_string_literal: true

module FotonCashFlow
  class Hooks < Redmine::Hook::ViewListener
    def view_layouts_base_html_head(context = {})
      controller = context[:controller]
      return unless controller
      # O carregamento de JavaScript foi movido para a partial `_cash_flow_assets.html.erb`
      # para garantir a ordem de carregamento correta e evitar race conditions.
      # O hook agora é responsável apenas pelo CSS global do plugin.
      return unless ['entries', 'settings', 'diagnostics'].include?(controller.controller_name)
      stylesheet_link_tag('cash_flow_main', plugin: 'foton_cash_flow')
    end
  end
end

# Fim do hooks.rb
