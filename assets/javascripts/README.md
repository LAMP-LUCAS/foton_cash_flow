# Documentação da Arquitetura JavaScript

Este diretório contém todos os arquivos JavaScript para o plugin **FOTON Fluxo de Caixa**, seguindo uma arquitetura modular e orientada a componentes para garantir manutenibilidade e escalabilidade dentro do ambiente Redmine.

A arquitetura utiliza um **padrão de namespace global** (`window.FotonCashFlow`) para garantir a compatibilidade com o pipeline de assets do Redmine (Sprockets), que não suporta módulos ES6 (`import`/`export`) nativamente.

---

## Estrutura da Arquitetura

A estrutura de diretórios ideal para o projeto é:

```
assets/javascripts/
├── application.js              # Ponto de entrada, inicializa o controller
├── components/
│   └── filter_popup.js         # Componente de UI para o popup de filtro
├── controllers/
│   └── cash_flow_page_controller.js # Orquestra a página principal
├── managers/
│   ├── dashboard_manager.js    # Gerencia os gráficos (Chart.js)
│   ├── filter_manager.js       # Gerencia a lógica e o estado dos filtros
│   └── view_manager.js         # Gerencia a manipulação do DOM (tabela, pílulas)
└── README.md                   # Esta documentação
```

---

A lógica é dividida em três camadas principais: **Controladores**, **Gerenciadores** e **Componentes**.

### 1. `application.js` (Ponto de Entrada)

**Propósito:** É o único script carregado globalmente. Ele atua como um roteador, detectando em qual página o usuário está e inicializando o **Controlador** apropriado.

---

### 2. `controllers/`

**Propósito:** Contêm as classes que orquestram uma página ou uma seção complexa da aplicação. Um controlador não manipula o DOM diretamente; ele instancia e coordena os **Gerenciadores**.

- **`cash_flow_page_controller.js`**: Orquestra a página de listagem de lançamentos. Ele inicializa todos os gerenciadores (filtros, ordenação, gráficos, etc.) e os faz reagir a mudanças de estado.

---

### 3. `managers/`

**Propósito:** Cada gerenciador encapsula uma área de lógica de negócio específica.

- **`filter_manager.js`**: Gerencia o estado dos filtros ativos e a interação com o `FilterPopup`.
- **`dashboard_manager.js`**: Gerencia a lógica de agregação de dados e a atualização dos gráficos (Chart.js) em resposta aos filtros. Substitui a lógica do antigo `cash_flow_dashboard.js`.
- **`view_manager.js`**: **Único responsável por manipular o DOM**. Ele recebe comandos do controlador e atualiza a UI (renderiza a tabela, as pílulas de filtro, os indicadores de ordenação, etc.).

---

### 4. `components/`

**Propósito:** São classes menores e focadas que representam um elemento de UI reutilizável.

- **`filter_popup.js`**: Classe que representa o popup de filtro que aparece ao clicar no ícone de uma coluna.

---

### Fluxo de Dados

1. O usuário interage com um componente (ex: clica em "Aplicar" no `FilterPopup`).
2. O componente notifica seu **Gerenciador** (`FilterManager`).
3. O `FilterManager` atualiza seu estado (ex: adiciona um novo filtro) e notifica o **Controlador**.
4. O `CashFlowPageController` aciona um ciclo de atualização completo (`onStateChange`).
5. Ele pede ao `FilterManager` para aplicar os filtros sobre os dados originais.
6. Ele comanda o `ViewManager` e o `DashboardManager` para que eles se atualizem com os dados já filtrados, renderizando a tabela e os gráficos.
