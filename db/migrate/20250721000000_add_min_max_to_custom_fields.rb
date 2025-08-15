# frozen_string_literal: true

class AddMinMaxToCustomFields < ActiveRecord::Migration[7.1]
  def change
    # Adiciona as colunas min_value e max_value à tabela custom_fields.
    # Elas serão do tipo float para permitir valores decimais.
    add_column :custom_fields, :min_value, :float
    add_column :custom_fields, :max_value, :float
  end
end