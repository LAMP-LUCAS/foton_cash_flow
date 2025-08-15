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

**Propósito:** É o único script carregado globalmente. Ele atua como um roteador, detectando em qual página o usuário está e inicializando o **Controlador** apropriado (ex: `CashFlowPageController` para a página principal, `ImportFormController` para a de importação).


### 2. `controllers/`

**Propósito:** Contêm as classes que orquestram uma página ou uma seção complexa da aplicação. Um controlador não manipula o DOM diretamente; ele instancia e coordena os **Gerenciadores**.

- **`import_form_controller.js`**: Gerencia a lógica do formulário de importação, incluindo a pré-análise do arquivo CSV, a exibição do modal de conciliação de conflitos e a finalização da importação via AJAX.


### 3. `managers/`

**Propósito:** Cada gerenciador encapsula uma área de lógica de negócio específica.

- **`chart_manager.js`**: Gerencia a interatividade dos gráficos, como a funcionalidade de maximizar e minimizar. Ele trabalha em conjunto com o `DashboardManager`.
- **`dashboard_manager.js`**: Gerencia a lógica de agregação de dados e a renderização/atualização dos gráficos (usando Chart.js) em resposta aos filtros aplicados. Ele extrai os dados das linhas visíveis da tabela e os processa para os gráficos.
- **`view_manager.js`**: **Único responsável por manipular o DOM da página principal**. Ele recebe comandos do controlador e atualiza a UI (renderiza a tabela, as pílulas de filtro, os indicadores de ordenação, etc.).


### 4. `components/`

**Propósito:** São classes menores e focadas que representam um elemento de UI reutilizável.


---

### 5. `utils/`

**Propósito:** Contém funções auxiliares e puras que podem ser reutilizadas em diferentes partes da aplicação.

- **`color_utils.js`**: Fornece funções para gerar cores consistentes e determinísticas para elementos como categorias de despesa e status, garantindo que a mesma categoria tenha sempre a mesma cor nos gráficos e na tabela.

---

### 6. Outros Scripts

- **`cash_flow_settings.js`**: Contém a lógica para a página de configurações do plugin, como a adição e remoção dinâmica de categorias. Não segue a arquitetura de managers/controllers por ser uma página mais simples.


### Fluxo de Dados

1. O usuário interage com um componente (ex: clica em "Aplicar" no `FilterPopup`).
2. O componente notifica seu **Gerenciador** (`FilterManager`).
3. O `FilterManager` atualiza seu estado (ex: adiciona um novo filtro) e notifica o **Controlador**.
4. O `CashFlowPageController` aciona um ciclo de atualização completo (`onStateChange`).
5. Ele pede ao `FilterManager` para aplicar os filtros sobre os dados originais.
6. Ele comanda o `ViewManager` e o `DashboardManager` para que eles se atualizem com os dados já filtrados, renderizando a tabela e os gráficos.
