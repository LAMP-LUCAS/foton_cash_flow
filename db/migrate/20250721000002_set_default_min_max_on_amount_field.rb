# frozen_string_literal: true

# Migração de Dados para o plugin Foton Cash Flow
#
# Esta migração é responsável por definir os valores padrão de min/max
# no campo personalizado 'Valor' após sua criação. Separar a manipulação
# de dados da alteração de esquema é uma boa prática para evitar problemas
# de cache de modelo no Rails.
class SetDefaultMinMaxOnAmountField < ActiveRecord::Migration[7.2]
  def up
    # Garante que o modelo esteja atualizado com as novas colunas
    IssueCustomField.reset_column_information

    amount_field = IssueCustomField.find_by(name: 'Valor')
    if amount_field
      # O valor anterior era muito grande para uma coluna decimal(15,2).
      # Ajustamos para um valor que se encaixa na precisão (13 dígitos antes da vírgula).
      amount_field.update_columns(min_value: -999_999_999_999.99, max_value: 999_999_999_999.99)
    end
  end

  def down
    # Não há necessidade de reverter a atualização de dados, pois as colunas serão removidas.
  end
end