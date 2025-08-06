# plugins/foton_cash_flow/config/routes.rb

# frozen_string_literal: true

RedmineApp::Application.routes.draw do
  namespace :foton_cash_flow do

    # Rotas para o controlador de entradas de fluxo de caixa
    resources :entries, only: [:index, :new, :create, :edit, :update, :destroy] do
      get :export, on: :collection
      get :import_form, on: :collection
      post :import, on: :collection
    end
    
    # Rotas para o controlador de diagnósticos
    get 'diagnostics', to: 'diagnostics#index', as: 'diagnostics'
    post 'diagnostics/run_sync', to: 'diagnostics#run_sync', as: 'diagnostics_run_sync'

    # Rotas de configuração
    resource :settings, only: [:index, :update] do
      get :index, on: :collection
    end
  end

  # Rotas aninhadas a projetos para entradas de fluxo de caixa
  resources :projects do
    resources :cash_flow_entries, controller: 'foton_cash_flow/entries'
  end


  resources :cash_flow_entries do
    collection do
      get 'import_form'  # Cria a rota import_form_cash_flow_entries_path
    end
  end


  resources :cash_flow_entries do
    collection do
      get 'export'  # Isso criará export_cash_flow_entries_path
    end
  end

  
  namespace :foton_cash_flow do
    resources :diagnostics do
      post 'run_sync', on: :collection
    end
  end

end
