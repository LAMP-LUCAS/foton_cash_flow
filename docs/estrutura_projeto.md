# Plugin foton Fluxo de Caixa - Documentação Técnica

## Visão Geral

O Plugin foton Fluxo de Caixa é uma solução avançada para gerenciamento financeiro integrado ao Redmine. Ele oferece um conjunto completo de funcionalidades para controle de receitas e despesas, com foco em usabilidade e eficiência.

### Principais Funcionalidades

1. **Gestão de Lançamentos**
   - Registro de receitas e despesas
   - Categorização e organização por projetos
   - Controle de status e autoria
   - Sistema avançado de filtros estilo Notion

2. **Interface Moderna**
   - Design responsivo e intuitivo
   - Modal de filtros com Select2
   - Tabelas dinâmicas e interativas

3. **Importação e Exportação**
   - Suporte a arquivos CSV
   - Template padronizado
   - Validação de dados

4. **Configurações Flexíveis**
   - Personalização de colunas
   - Controle de acesso granular
   - Internacionalização completa

## Estrutura do Projeto

``` directory
.
├── .vscode
│   └── settings.json
├── app
│   ├── controllers
│   │   └── foton_cash_flow
│   │       ├── diagnostics_controller.rb
│   │       ├── entries_controller.rb
│   │       └── settings_controller.rb
│   ├── helpers
│   │   └── foton_cash_flow
│   │       ├── entries_helper.rb
│   │       └── settings_helper.rb
│   └── views
│       └── foton_cash_flow
│           ├── diagnostics
│           │   └── index.html.erb
│           ├── entries
│           │   ├── _charts.html.erb
│           │   ├── _form.html.erb
│           │   ├── _no_projects_modal.html.erb
│           │   ├── _summary.html.erb
│           │   ├── _sync_btn.html.erb
│           │   ├── _sync_modal.html.erb
│           │   ├── _table.html.erb
│           │   ├── create.js.erb
│           │   ├── edit.html.erb
│           │   ├── import_form.html.erb
│           │   ├── index.html.erb
│           │   ├── new.html.erb
│           │   └── no_projects_alert.html.erb
│           ├── settings
│           │   ├── _cash_flow_settings.html.erb
│           │   └── index.html.erb
│           └── shared
│               └── _cash_flow_assets.html.erb
├── assets
│   ├── javascripts
│   │   ├── application.js         # Ponto de entrada (roteador de controllers)
│   │   ├── cash_flow_charts.js    # Lógica dos gráficos (Chart.js)
│   │   ├── cash_flow_main.js      # Lógica da página principal (filtros, interações)
│   │   ├── cash_flow_settings.js  # Lógica da página de configurações
│   │   └── README.md
│   └── stylesheets
│       ├── cash_flow_main.css
│       └── README.md
├── config
│   ├── initializers
│   │   └── foton_cash_flow.rb
│   ├── locales
│   │   ├── en.yml
│   │   └── pt-BR.yml
│   └── routes.rb
├── db
│   └── migrate
│       └── 20250721000001_create_financial_tracker_and_fields.rb
├── docs
│   ├── Descritivo.md
│   ├── estrutura_dados.md
│   ├── estrutura_projeto.md
│   └── import_template.csv
├── lib
│   ├── foton_cash_flow
│   │   ├── patches
│   │   │   ├── issue_patch.rb
│   │   │   └── issues_controller_patch.rb
│   │   ├── services
│   │   │   ├── exporter.rb
│   │   │   ├── importer.rb
│   │   │   ├── query_builder.rb
│   │   │   └── summary_service.rb
│   │   └── hooks.rb
│   ├── tasks
│   │   ├── .config
│   │   ├── install_plugin.py
│   │   ├── remove_plugin.py
│   │   └── update_plugin.py
│   └── foton_cash_flow.rb
├── .gitattributes
├── .gitignore
├── Gemfile
├── import_template.csv
├── init.rb
└── README.md
```

## Arquitetura e Organização

O projeto segue uma arquitetura MVC (Model-View-Controller) robusta, alinhada com as melhores práticas do Rails e padrões do Redmine. A estrutura foi desenhada para maximizar a manutenibilidade e extensibilidade.

### Padrões de Projeto Utilizados

1. **MVC (Model-View-Controller)**
   - Separação clara de responsabilidades
   - Código modular e testável
   - Facilidade de manutenção

2. **Asset Pipeline**
   - Gerenciamento eficiente de recursos
   - Minificação automática
   - Versionamento de assets

3. **Hooks System**
   - Integração não-intrusiva com o Redmine
   - Carregamento condicional de recursos
   - Extensibilidade via hooks

## Detalhamento da Estrutura

### Diretório `app/`

Principal diretório da aplicação, seguindo a convenção Rails:

- **controllers/**
  - `cash_flow_entries_controller.rb`: Controlador principal do plugin. Gerencia o CRUD de lançamentos financeiros (Issues), filtros dinâmicos, importação/exportação CSV e permissões.
  - `cash_flow_settings_controller.rb`: Interface administrativa para configurações do plugin.

- **helpers/**
  - `cash_flow_entries_helper.rb`: Métodos auxiliares para views, incluindo formatação de valores, datas, tipos e categorias.


- **views/**
  - **cash_flow_entries/**
    - `index.html.erb`: Tela principal com dashboard, filtros, tabela de lançamentos e ações.
    - `_charts.html.erb`: Partial que renderiza os contêineres dos gráficos.
    - `_form.html.erb`: Partial de formulário reutilizado para criação e edição de lançamentos (Issues).
    - `new.html.erb`, `edit.html.erb`: Usam o partial `_form.html.erb` para criar/editar lançamentos.
    - `import_form.html.erb`: Interface para importação de lançamentos via CSV.
  - **cash_flow_settings/**: Views administrativas para configuração do plugin.

### Diretório `assets/`

Recursos estáticos e bibliotecas:

- **javascripts/**
  - `application.js`: Ponto de entrada que inicializa os scripts da página correta.
  - `cash_flow_main.js`: Lógica interativa da página principal (filtros, modais, etc.).
  - `cash_flow_charts.js`: Inicialização e gerenciamento dos gráficos do dashboard (usando Chart.js).
  - `cash_flow_settings.js`: Lógica para a página de configurações (ex: adicionar categorias dinamicamente).

- **stylesheets/**
  - `cash_flow_main.css`: CSS principal, unificado, documentado e sem dependências externas.

> **Observação:**  
> Todos os estilos e scripts foram unificados e documentados para facilitar a manutenção. Não há mais dependência de Bootstrap ou Select2.

### Diretório `config/`

- `routes.rb`: Definição de rotas customizadas do plugin.
- **locales/**
  - `pt-BR.yml`, `en.yml`: Arquivos de tradução.

### Diretório `db/migrate/`

- Migrações para estruturação e evolução do banco de dados.

### Diretório `lib/`

- **foton_cash_flow/**

  - `hooks.rb`: Integração com hooks do Redmine para carregamento de assets e extensibilidade.
  - `patches/`: Módulos que estendem classes do core do Redmine (ex: `IssuePatch`).
  - `services/`: Classes que encapsulam a lógica de negócio (ex: `Importer`, `QueryBuilder`).

### Raiz do Projeto

- **Scripts de Automação**
  - `install_plugin.py`, `update_plugin.py`, `remove_plugin.py`: Scripts para instalação, atualização e remoção automatizadas do plugin.
  - `.config`: Configurações dos scripts.
- **Configuração e Documentação**
  - `Gemfile`: Dependências do plugin.
  - `init.rb`: Inicialização e configuração do plugin.
  - `import_template.csv`: Template para importação de lançamentos.
  - `README.md`: Guia principal de uso.
  - `estrutura_projeto.md`: Documentação técnica detalhada.

## Práticas de Desenvolvimento

### Convenções de Código

- Ruby: seguimos o guia de estilo da comunidade Ruby
- JavaScript: ESLint com configuração padrão
- CSS: BEM (Block Element Modifier)

### Fluxo de Desenvolvimento

1. **Instalação**

   ```bash
   python install_plugin.py
   ```

2. **Atualização**

   ```bash
   python update_plugin.py
   ```

3. **Remoção**

   ```bash
   python remove_plugin.py
   ```

### Manutenção

- Assets são compilados automaticamente
- Migrações são versionadas
- Hooks garantem carregamento eficiente

## Considerações de Segurança

1. **Permissões**
   - Controle granular por papel
   - Validação em múltiplas camadas
   - Proteção contra CSRF

2. **Validação de Dados**
   - Sanitização de inputs
   - Validações no modelo
   - Controles de acesso

3. **Auditoria**
   - Registro de alterações
   - Rastreamento de usuários
   - Logs de operações

---

Este plugin representa uma solução robusta para gestão financeira no Redmine, combinando usabilidade moderna com práticas sólidas de desenvolvimento.
