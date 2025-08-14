module FotonCashFlow
  # Helper para a página de diagnóstico, encapsulando a lógica de apresentação.
  module DiagnosticsHelper
    # Mapeia um status simbólico (:ok, :warning, :error) para um hash
    # contendo classes CSS, ícone e o texto traduzido correspondente.
    def diagnostic_details(status)
      case status
      when :ok
        { class: 'ok', icon: 'icon-ok-circled', text: l('foton_cash_flow.diagnostics.status_ok') }
      when :warning
        { class: 'warning', icon: 'icon-attention', text: l('foton_cash_flow.diagnostics.status_warning') }
      when :error
        { class: 'error', icon: 'icon-cancel-circled', text: l('foton_cash_flow.diagnostics.status_error') }
      else
        { class: 'unknown', icon: 'icon-help', text: l('foton_cash_flow.diagnostics.status_unknown') }
      end
    end
  end
end