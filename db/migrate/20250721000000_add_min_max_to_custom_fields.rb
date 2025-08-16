# frozen_string_literal: true

class AddMinMaxToCustomFields < ActiveRecord::Migration[7.1]
  def change
    # Adiciona as colunas min_value e max_value à tabela custom_fields.
    # Usamos o tipo :decimal para armazenar valores monetários com precisão.
    add_column :custom_fields, :min_value, :decimal, precision: 15, scale: 2
    add_column :custom_fields, :max_value, :decimal, precision: 15, scale: 2
  end
end