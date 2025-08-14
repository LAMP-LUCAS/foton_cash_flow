# frozen_string_literal: true

module FotonCashFlow
  module EntriesHelper
    include ApplicationHelper # Inclui os helpers padrão do Redmine
    include Redmine::Pagination::Helper
    include Redmine::I18n

    # Cache de classe para IDs de custom fields
    @@class_cf_cache = {}

    # =====================================================
    #  FORMATAÇÃO DE DADOS
    # =====================================================

    # Formata o status da issue, usando a tradução padrão do Redmine.
    def format_status(status)
      content_tag(:span, status.name, class: "status-label status-#{status.id}")
    end

    # Formata o tipo de transação com estilo apropriado
    def format_transaction_type(issue)
      return ''.html_safe unless issue.present?

      tipo = issue.cash_flow_transaction_type
      return ''.html_safe if tipo.blank?

      label = case tipo
              when 'revenue' then l('foton_cash_flow.cf_options.revenue')
              when 'expense' then l('foton_cash_flow.cf_options.expense')
              else tipo
              end

      content_tag :span, label,
                  class: "badge rounded-pill #{tipo == 'revenue' ? 'bg-success' : 'bg-danger'}",
                  style: "font-size:0.95em;"
    end

    # Formata o valor monetário com cor e símbolo de moeda
    def format_amount(amount, options = {})
      Rails.logger.debug "[FOTON_CASH_FLOW][EntriesHelper] Executando format_amount. Valor recebido: #{amount.inspect}. Tipo: #{amount.class}"
      
      # Garante que o valor é um BigDecimal ou um número antes de formatar
      parsed_amount = amount.is_a?(BigDecimal) ? amount : BigDecimal(amount.to_s) rescue BigDecimal('0.0')

      css_class = amount_css_class(parsed_amount)

      # Usamos a localização do Redmine para garantir a formatação correta
      formatted_amount = format_currency(parsed_amount)
      Rails.logger.debug "[FOTON_CASH_FLOW][EntriesHelper] Valor formatado: #{formatted_amount}, classe CSS: #{css_class}, amount: #{parsed_amount.to_s}"

      content_tag :span, formatted_amount, class: css_class
    end

    # Link para uma issue de fluxo de caixa
    def link_to_cash_flow_issue(issue)
      link_to "##{issue.id}", issue_path(issue),
        title: issue.subject,
        class: 'issue-link'
    end

    # Formata a data.
    # Este método agora lida com objetos Date e strings de data de forma robusta.
    def format_date(date_obj_or_str)
      return 'N/A' if date_obj_or_str.blank?

      # Se já for um objeto Date, usa-o diretamente. Senão, tenta converter a string.
      date = date_obj_or_str.is_a?(Date) ? date_obj_or_str : (Date.parse(date_obj_or_str.to_s) rescue nil)

      if date.present?
        I18n.l(date, format: :default)
      else
        'N/A'
      end
    end

    # =====================================================
    #  COLEÇÕES PARA FORMULÁRIOS
    # =====================================================
    def transaction_type_collection
      [
        [l('foton_cash_flow.cf_options.revenue'), 'revenue'],
        [l('foton_cash_flow.cf_options.expense'), 'expense']
      ]
    end

    def project_collection_for_select(projects)
      projects.map { |p| [p.name, p.id] }.sort_by(&:first)
    end

    # =====================================================
    #
    # ---------------  MÉTODOS PRIVADOS  ------------------
    #
    # =====================================================
    private

    # Determina a classe CSS com base no valor
    def amount_css_class(amount)
      if amount.positive?
        'text-success'
      elsif amount.negative?
        'text-danger'
      else
        ''
      end
    end

    # Formata o valor monetário usando as configurações do plugin
    def format_currency(amount, options = {})
      default_options = {
        unit: (Setting.plugin_foton_cash_flow['default_currency'] || 'R$ '),
        separator: ',',
        delimiter: '.',
        precision: 2
      }
      options = default_options.merge(options)
      # Usa o helper number_to_currency que está disponível via ApplicationHelper,
      # que já está incluído neste helper.
      number_to_currency(amount, options)
    end

    # Helper method to get custom field ID by name
    def custom_field_id_by_name(name)
      @@class_cf_cache[name] ||= CustomField.find_by(name: name)&.id
    end

    # =====================================================
    #  HELPERS DE RECURSOS INCOMPLETOS (COMENTADOS)
    # =====================================================

    # O helper de recorrência foi comentado pois a funcionalidade
    # não está completamente implementada no plugin (falta CF e lógica).
    # def recurrence_label(issue)
    #   return ''.html_safe unless issue.present?
    #
    #   cf_recurrence_id = custom_field_id_by_name('Recorrência')
    #   return ''.html_safe unless cf_recurrence_id.present?
    #
    #   val = issue.custom_field_value(cf_recurrence_id)
    #   return ''.html_safe if val.blank?
    #
    #   label = l("foton_cash_flow.db.cf_recurrence_#{val}", default: val.humanize)
    #
    #   content_tag(:span, label,
    #               class: 'badge bg-warning text-dark',
    #               title: l('foton_cash_flow.fields.recurrence'))
    # end

    # O helper de filtro por issue foi comentado pois não está sendo
    # utilizado na view principal atualmente.
    # def issue_filter_options(selected_issues = [])
    #   tracker = Tracker.find_by(name: FotonCashFlow::SettingsHelper::FINANCE_TRACKER_NAME)
    #   return '' unless tracker.present?
    #   # ... lógica restante
    # end
  end
end