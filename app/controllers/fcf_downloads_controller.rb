class FcfDownloadsController < ApplicationController
  # Ignora a necessidade de um token de autenticidade para esta ação de download
  skip_before_action :verify_authenticity_token

  # Ação que irá encontrar o arquivo e enviá-lo para o usuário
  def template
    # Define o caminho completo para o arquivo CSV dentro do seu plugin
    file_path = Rails.root.join('plugins', 'foton_cash_flow', 'assets', 'import_template.csv')

    # Verifica se o arquivo existe antes de tentar enviá-lo
    if File.exist?(file_path)
      # Usa o método 'send_file' do Rails para enviar o arquivo para o navegador do usuário
      # O navegador irá tratar isso como um download
      send_file file_path,
                filename: 'import_template.csv', # Nome que o arquivo terá no download
                type: 'text/csv'                  # Tipo do arquivo (MIME type)
    else
      # Se o arquivo não for encontrado, retorna um erro 404 (Not Found)
      render_404
    end
  end
end