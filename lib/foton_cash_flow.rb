# frozen_string_literal: true

module FotonCashFlow
  # Este módulo pode conter métodos de ajuda ou configurações gerais do plugin.
end

# Usamos o hook to_prepare aqui, no ponto de entrada do nosso módulo.
# Isso garante que ele será chamado no momento certo do ciclo de vida do Rails.
# Rails.configuration.to_prepare do
#   # Log para confirmar que o bloco está sendo executado.
#   Rails.logger.info "FotonCashFlow: [lib/foton_cash_flow.rb] Executando bloco to_prepare..."

#   # Carrega os patches
#   require_dependency 'foton_cash_flow/patches/issue_patch'
#   require_dependency 'foton_cash_flow/patches/issue_custom_field_patch'
#   require_dependency 'foton_cash_flow/patches/issue_custom_value_patch'

#   # Aplica os patches
#   begin
#     Issue.send(:include, FotonCashFlow::Patches::IssuePatch) unless Issue.included_modules.include?(FotonCashFlow::Patches::IssuePatch)
#     IssueCustomField.send(:include, FotonCashFlow::Patches::IssueCustomFieldPatch) unless IssueCustomField.included_modules.include?(FotonCashFlow::Patches::IssueCustomFieldPatch)
#     IssueCustomValue.send(:include, FotonCashFlow::Patches::IssueCustomValuePatch) unless IssueCustomValue.included_modules.include?(FotonCashFlow::Patches::IssueCustomValuePatch)
#     Rails.logger.info "FotonCashFlow: [lib/foton_cash_flow.rb] Patches aplicados com sucesso."
#   rescue => e
#     Rails.logger.error "FotonCashFlow: [lib/foton_cash_flow.rb] Erro ao aplicar patches: #{e.message}"
#   end
# end