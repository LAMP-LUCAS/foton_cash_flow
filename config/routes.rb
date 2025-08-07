# plugins/foton_cash_flow/config/routes.rb
# frozen_string_literal: true

RedmineApp::Application.routes.draw do
  
  # === ROTA ANINHADA A PROJETOS ===
  # Aninhando rotas de entradas de fluxo de caixa em projetos.
  # Isso cria helpers como `project_cash_flow_entries_path`.
  resources :projects do
    resources :cash_flow_entries, controller: 'foton_cash_flow/entries'
  end

  # === ROTAS GLOBAIS DO PLUGIN (Namespaced) ===
  # Agrupa todas as rotas globais sob o namespace 'foton_cash_flow'
  # Isso evita conflitos com outras rotas do Redmine e organiza o código.
  namespace :foton_cash_flow do

    # Rotas para o controlador de diagnósticos
    resources :diagnostics, only: [:index] do
      post 'run_sync', on: :collection
    end

    # Rotas para o controlador de entradas de fluxo de caixa (rotas de admin, fora de projetos)
    # Obs: essas rotas globais podem não ser necessárias se a navegação for sempre por projeto.
    resources :entries, only: [:index, :new, :create, :edit, :update, :destroy] do
      get :export, on: :collection
      get :import_form, on: :collection
      post :import, on: :collection
    end
    
    # Rotas de configuração
    resource :settings, only: [:index, :update]

  end

end