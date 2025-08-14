# frozen_string_literal: true

# Migração otimizada para o plugin Foton Cash Flow
#
# Esta migração garante que a estrutura do banco de dados seja criada
# ou atualizada antes de inserir os dados, prevenindo erros como
# PG::UndefinedColumn.
class CreateFinancialTrackerAndFields < ActiveRecord::Migration[7.2]
  def up
    # 1. Cria ou encontra o status padrão para o fluxo financeiro.
    # Usando find_or_create_by! com create_with é a forma mais robusta.
    status_novo = IssueStatus.find_or_create_by!(name: 'Novo') do |s|
      s.position = 1
      s.is_closed = false
    end
    IssueStatus.find_or_create_by!(name: 'Em Processamento') do |s|
      s.position = 2
      s.is_closed = false
    end
    IssueStatus.find_or_create_by!(name: 'Pago') do |s|
      s.position = 3
      s.is_closed = true
    end
    IssueStatus.find_or_create_by!(name: 'Cancelado') do |s|
      s.position = 4
      s.is_closed = true
    end

    # 2. Garante que a coluna `core_fields` exista na tabela `trackers`.
    # Isso evita o erro PG::UndefinedColumn.
    unless column_exists?(:trackers, :core_fields)
      add_column :trackers, :core_fields, :text, array: true, default: [], null: false
    end

    # 3. Cria ou encontra o tracker "Financeiro" e define seus atributos.
    # O método find_or_create_by! é ideal para evitar duplicatas.
    tracker = Tracker.find_or_create_by!(name: 'Financeiro') do |t|
      t.default_status_id = status_novo.id
      t.is_in_roadmap = false
      # Agora a coluna core_fields já existe e pode ser populada
      t.core_fields = %w[assigned_to_id category_id fixed_version_id parent_issue_id start_date due_date]
    end

    # 4. Cria ou encontra os Custom Fields essenciais e os associa ao tracker.
    fields = [
      {
        name: 'Data do Lançamento', field_format: 'date', is_required: true, is_for_all: true, searchable: true, is_filter: true
      },
      {
        name: 'Valor', field_format: 'float', is_required: true, is_for_all: true, searchable: true, is_filter: true,
        min_value: '-99999999999999.999999',
        max_value: '99999999999999.999999',
        regexp: '^-?\d{1,3}(\.\d{3})*(,\d+)?$' # Aceita 1.000,00 ou 1000,00
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
      field = IssueCustomField.find_or_create_by!(name: field_params[:name]) do |f|
        f.field_format = field_params[:field_format]
        f.is_required = field_params[:is_required]
        f.is_for_all = field_params[:is_for_all]
        f.searchable = field_params[:searchable]
        f.is_filter = field_params[:is_filter]
        f.possible_values = field_params[:possible_values] if field_params[:possible_values]
        f.default_value = field_params[:default_value] if field_params[:default_value]
        f.min_value = field_params[:min_value] if field_params[:min_value]
        f.max_value = field_params[:max_value] if field_params[:max_value]
        f.regexp = field_params[:regexp] if field_params[:regexp]
      end
      
      # Garante a associação do CustomField com o Tracker
      unless field.trackers.include?(tracker)
        field.trackers << tracker
      end
    end

    # 5. Associa o tracker a todos os projetos existentes.
    # Novamente, a verificação com `unless` evita duplicatas.
    Project.all.each do |project|
      project.trackers << tracker unless project.trackers.include?(tracker)
    end
  end

  def down
    # Lógica para reverter a migração de forma segura.
    # É importante remover as associações antes de destruir os registros.

    # 1. Remove as associações dos Custom Fields com o Tracker.
    tracker = Tracker.find_by(name: 'Financeiro')
    if tracker
      custom_fields = IssueCustomField.where(name: [
        'Data do Lançamento', 'Valor', 'Tipo de Transação',
        'Categoria', 'Recorrência'
      ])
      custom_fields.each do |field|
        field.trackers.delete(tracker) if field.trackers.include?(tracker)
        field.destroy if field.trackers.empty?
      end
    end
    
    # 2. Desassocia o tracker de todos os projetos.
    Project.all.each do |project|
      project.trackers.delete(tracker) if project.trackers.include?(tracker)
    end

    # 3. Remove o Tracker e os Custom Fields (se não forem mais usados).
    Tracker.where(name: 'Financeiro').destroy_all
    
    # Obs: Não é ideal remover os Status na migração 'down', pois eles podem
    # estar em uso por outros trackers. Por isso, a lógica foi removida.
  end
end