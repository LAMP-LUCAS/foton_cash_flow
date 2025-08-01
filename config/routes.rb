# plugins/foton_cash_flow/config/routes.rb

# frozen_string_literal: true

RedmineApp::Application.routes.draw do
  scope module: 'foton_cash_flow' do
    # Rotas globais para entradas de fluxo de caixa (acessíveis via menu superior ou por administradores)
    resources :cash_flow_entries, controller: 'entries', as: 'cash_flow_entries' do
      collection do
        get 'import_form'
        post 'import'
        get 'export'
      end
    end

    # Rotas aninhadas a projetos para entradas de fluxo de caixa (acessíveis de dentro de um projeto)
    resources :projects do
      resources :cash_flow_entries, controller: 'entries', as: 'project_cash_flow_entries' do
        collection do
          get 'import_form'
          post 'import'
          get 'export'
        end
      end
    end

    # Rotas de diagnóstico
    resources :diagnostics, controller: 'diagnostics', only: [:index] do
      collection do
        post :run_sync
      end
    end

    # Rotas de configuração
    resource :settings, controller: 'settings', only: [:index, :update]
  end
end

#Fim do routes.rb