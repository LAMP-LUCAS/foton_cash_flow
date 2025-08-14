# plugins/foton_cash_flow/config/routes.rb
# frozen_string_literal: true

RedmineApp::Application.routes.draw do
  
  # === ROTA ANINHADA A PROJETOS ===
  # Aninhando rotas de entradas de fluxo de caixa em projetos.
  # Isso cria helpers como `project_cash_flow_entries_path`.
  # Todas as ações, incluindo import/export, devem estar aqui.
  resources :projects do
    resources :cash_flow_entries, controller: 'foton_cash_flow/entries' do
      collection do
        get :export
        get :import_form
        # A rota 'import' original pode ser mantida como fallback ou removida se não for mais usada.
        post :import 
        post :import_preview
        post :import_finalize
      end
    end
  end

  # === ROTAS GLOBAIS DO PLUGIN (Namespaced) ===
  # Agrupa todas as rotas globais sob o namespace 'foton_cash_flow'
  # Isso evita conflitos com outras rotas do Redmine e organiza o código.
  namespace :foton_cash_flow do
    # Rotas para o controlador de diagnósticos
    resources :diagnostics, only: [:index] do
      post 'run_sync', on: :collection
    end
    # Rotas de configuração
    resource :settings, only: [:index, :update]

  end

  # === ROTA DE ACESSO AO ARQUIVO DE DOWNLOAD ===
  # Esta rota é responsável por fornecer o arquivo de template para download.
  get 'foton_cash_flow/download_template', to: 'fcf_downloads#template'

end