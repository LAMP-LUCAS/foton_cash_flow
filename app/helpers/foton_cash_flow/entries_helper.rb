# ./app/helpers/foton_cash_flow/entries_helper.rb

# frozen_string_literal: true

module FotonCashFlow
  module EntriesHelper
    # Incluir o helper de paginação do Redmine para ter acesso a métodos como pagination_links
    include Redmine::Pagination::Helper

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
      Rails.logger.debug "[FOTON_CASH_FLOW][EntriesHelper] format_transaction_type chamado para Issue ID: #{issue&.id}. Objeto recebido: #{issue.class}"
      return ''.html_safe unless issue.present?

      tipo = issue.cash_flow_transaction_type
      return ''.html_safe if tipo.blank?

      label = case tipo
              when 'revenue' then l(:label_revenue)
              when 'expense' then l(:label_expense)
              else tipo
              end

      content_tag :span, label,
                class: "badge rounded-pill #{tipo == 'revenue' ? 'bg-success' : 'bg-danger'}",
                style: "font-size:0.95em;"
    end

    # Formata o valor monetário com cor e símbolo de moeda
    def format_amount(value, options = {})
      Rails.logger.debug "[FOTON_CASH_FLOW][EntriesHelper] Executando format_amount. Valor recebido: #{value.inspect}. Tipo: #{value.class}"
      amount = extract_amount(value)
      css_class = amount_css_class(value, amount)

      # Usamos a localização do Redmine para garantir a formatação correta
      # A formatação é delegada a um helper nativo do Rails
      formatted_amount = l_currency(amount)
      Rails.logger.debug "[FOTON_CASH_FLOW][EntriesHelper] Valor formatado: #{formatted_amount}, classe CSS: #{css_class}, amount: #{amount.to_s}"

      content_tag :span, formatted_amount, class: css_class
    end

    # Link para uma issue de fluxo de caixa
    def link_to_cash_flow_issue(issue)
      link_to "##{issue.id}", issue_path(issue),
        title: issue.subject,
        class: 'issue-link'
    end

    # Formata a data.
    def format_date(date_str)
      date = Date.parse(date_str) rescue nil
      if date.present?
        format_date(date)
      else
        'N/A'
      end
    end

    def l_currency(amount)
      ActionController::Base.helpers.number_to_currency(amount, locale: I18n.locale)
    end

    # =====================================================
    #  RECORRÊNCIA DE LANÇAMENTOS
    # =====================================================
    
    # Helper method to get custom field ID by name
    def custom_field_id_by_name(name)
      # Cache the custom field IDs to avoid repeated database queries
      @@class_cf_cache[name] ||= CustomField.find_by(name: name)&.id
    end

    def recurrence_label(issue)
      return ''.html_safe unless issue.present?

      cf_recurrence_id = custom_field_id_by_name('Recorrência')
      return ''.html_safe unless cf_recurrence_id.present?

      val = issue.custom_field_value(cf_recurrence_id)
      return ''.html_safe if val.blank?

      label = case val
              when 'mensal' then l(:label_monthly)
              when 'anual' then l(:label_yearly)
              when 'semanal' then l(:label_weekly)
              else val
              end

      content_tag(:span, label,
                  class: 'badge bg-warning text-dark',
                  title: l(:label_recurrent_entry))
    end

    # =====================================================
    #  FILTRO DE DEMANDA
    # =====================================================
    def issue_filter_options(selected_issues = [])
      tracker = Tracker.find_by(name: 'Financeiro')
      return ''.html_safe unless tracker.present?

      issues = Issue.where(tracker_id: tracker.id).order(:subject)

      options = issues.map do |issue|
        content_tag(:div, class: 'issue-select-item') do
          check_box_tag('query[issue_ids][]', issue.id, selected_issues.include?(issue.id.to_s),
                        id: "issue_#{issue.id}") +
          label_tag("issue_#{issue.id}", "##{issue.id}: #{issue.subject}")
        end
      end

      safe_join(options)
    end

    # =====================================================
    #  COLEÇÕES PARA FORMULÁRIOS
    # =====================================================
    def transaction_type_collection
      [[l(:label_revenue), 'revenue'], [l(:label_expense), 'expense']]
    end

    def project_collection_for_select(projects)
      projects.map { |p| [p.name, p.id] }.sort_by(&:first)
    end

    def link_to_cash_flow_issue(issue)
      return '' unless issue.present? && issue.id.present?

      link_to "##{issue.id}", issue_path(issue),
              title: issue.subject,
              class: 'issue-link'
    end

    # =====================================================
    #
    # ---------------  MÉTODOS PRIVADOS  ------------------
    #
    # =====================================================
    private

    # Extrai o valor monetário de diferentes tipos de entrada
    def extract_amount(value)
      value.is_a?(BigDecimal) ? value : BigDecimal(value.to_s.gsub('.', '').gsub(',', '.').to_s)
    rescue
      BigDecimal('0.0')
    end

    # Determina a classe CSS com base no valor
    def amount_css_class(original_value, amount)
      if amount.positive?
        'text-success'
      elsif amount.negative?
        'text-danger'
      else
        ''
      end
    end

    # Formata o valor monetário
    def format_currency(amount, options = {})
      default_options = {
        unit: (Setting.plugin_foton_cash_flow['default_currency'] || 'R$ '),
        separator: ',',
        delimiter: '.',
        precision: 2
      }
      options = default_options.merge(options)
      number_to_currency(amount, options)
    end

    def custom_field_id_by_name(name)
      @@class_cf_cache[name] ||= CustomField.find_by_name(name)&.id
    end


        # Método centralizado para formatação de moeda
    def l_currency(amount)
      # Adicionar opções padrão para o formato brasileiro
      ActionController::Base.helpers.number_to_currency(
        amount,
        unit: 'R$',
        separator: ',',
        delimiter: '.',
        precision: 2,
        locale: :pt # Certifique-se que o locale está configurado corretamente no seu Redmine
      )
    end

  end
end