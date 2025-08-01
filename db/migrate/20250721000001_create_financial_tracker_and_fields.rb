
# frozen_string_literal: true

# ÚNICA MIGRAÇÃO NECESSÁRIA PARA O PLUGIN FOTON CASH FLOW
# Cria status, tracker "Financeiro" e todos os custom fields essenciais.
class CreateFinancialTrackerAndFields < ActiveRecord::Migration[5.2]
  def up
    # Status padrão para o fluxo financeiro
    status = {
      'Novo' => { position: 1, is_closed: false },
      'Em Processamento' => { position: 2, is_closed: false },
      'Pago' => { position: 3, is_closed: true },
      'Cancelado' => { position: 4, is_closed: true }
    }
    status.each do |name, attrs|
      IssueStatus.create_with(
        is_closed: attrs[:is_closed],
        position: attrs[:position]
      ).find_or_create_by!(name: name)
    end

    default_status = IssueStatus.find_by(name: 'Novo')

    # Tracker principal
    tracker = Tracker.create!(
      name: 'Financeiro',
      default_status_id: default_status.id,
      is_in_roadmap: false,
      core_fields: %w[assigned_to_id category_id fixed_version_id parent_issue_id start_date due_date]
    )

    # Custom fields essenciais
    fields = [
      {
        name: 'Data do Lançamento', field_format: 'date', is_required: true, is_for_all: true, searchable: true, is_filter: true
      },
      {
        name: 'Valor', field_format: 'float', is_required: true, is_for_all: true, searchable: true, is_filter: true,
        min_value: '-99999999999999.999999',
        max_value: '99999999999999.999999'
      
      },
      {
        name: 'Tipo de Transação', field_format: 'list', possible_values: ['revenue', 'expense'], is_required: true, is_for_all: true, searchable: true, is_filter: true
      },
      {
        name: 'Categoria', field_format: 'list', possible_values: ['Vendas', 'Serviços', 'Salários', 'Impostos', 'Outros'], is_required: true, is_for_all: true, searchable: true, is_filter: true
      },
      {
        name: 'Recorrência', field_format: 'list', possible_values: ['Não', 'Mensal', 'Anual'], is_required: true, default_value: 'Não', is_for_all: true, searchable: true, is_filter: true
      }
    ]
    fields.each do |field_params|
      field = IssueCustomField.new(field_params)
      field.trackers << tracker
      field.save!
    end

    # Associa o tracker a todos os projetos existentes
    Project.all.each do |project|
      project.trackers << tracker unless project.trackers.include?(tracker)
    end
  end

  def down
    Tracker.where(name: 'Financeiro').destroy_all
    IssueCustomField.where(name: [
      'Data do Lançamento',
      'Valor',
      'Tipo de Transação',
      'Categoria',
      'Recorrência'
    ]).destroy_all
    # Não remove os status pois podem ser usados por outros trackers
  end
end
