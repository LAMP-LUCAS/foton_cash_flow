# Documentação da Arquitetura JavaScript

Este diretório contém todos os arquivos JavaScript para o plugin **foton Fluxo de Caixa**, seguindo uma arquitetura modular e orientada a componentes para garantir manutenibilidade e escalabilidade.

---

## Estrutura da Arquitetura

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
- **`sorting_manager.js`**: Gerencia o estado da ordenação da tabela.
- **`pagination_manager.js`**: Gerencia o estado da paginação.
- **`dashboard_manager.js`**: Gerencia a lógica de agregação de dados e a atualização dos gráficos (Chart.js) em resposta aos filtros.
- **`view_manager.js`**: **Único responsável por manipular o DOM**. Ele recebe dados dos outros gerenciadores e atualiza a UI (renderiza a tabela, as pílulas de filtro, os indicadores de ordenação, etc.).

---

### 4. `components/` e `filters/`

**Propósito:** São classes menores e focadas.
- **`components/`**: Classes que representam um elemento de UI, como um popup (`filter_popup.js`).
- **`filters/`**: Classes que definem a lógica de um tipo de filtro específico (`string_filter.js`, `number_filter.js`).

---

### Fluxo de Dados

1.  O usuário interage com um componente (ex: clica em "Aplicar" no `FilterPopup`).
2.  O componente notifica seu **Gerenciador** (`FilterManager`).
3.  O `FilterManager` atualiza seu estado (ex: adiciona um novo filtro) e notifica o **Controlador**.
4.  O `CashFlowPageController` aciona um ciclo de renderização.
5.  Ele pede aos gerenciadores para processarem os dados (filtrar, depois ordenar).
6.  Ele passa os dados processados para o `ViewManager` e o `DashboardManager` para que eles atualizem a UI (tabela e gráficos).
