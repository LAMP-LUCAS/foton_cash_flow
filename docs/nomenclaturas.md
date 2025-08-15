# Padrões de Nomenclatura do Plugin FOTON Fluxo de Caixa

Este documento define as convenções de nomenclatura a serem seguidas no desenvolvimento do plugin, garantindo consistência, legibilidade e manutenibilidade do código.

---

## 1. Versionamento Semântico (SemVer)

O versionamento do plugin segue o padrão [Semantic Versioning 2.0.0](https://semver.org/lang/pt-BR/). O formato da versão é `MAJOR.MINOR.PATCH`.

- **MAJOR**: Incrementado para mudanças incompatíveis com versões anteriores (breaking changes).
- **MINOR**: Incrementado para adição de novas funcionalidades de forma retrocompatível.
- **PATCH**: Incrementado para correções de bugs de forma retrocompatível.

### Versões de Pré-lançamento (Alpha/Beta)

Para versões que não estão prontas para produção, como fases de teste alfa e beta, utilizamos identificadores de pré-lançamento.

- **Alpha**: Versão em desenvolvimento inicial, potencialmente instável e para testes internos. Formato: `MAJOR.MINOR.PATCH-alpha.N` (ex: `1.2.0-alpha.1` ou `0.0.1-alpha.1`).
- **Beta**: Versão com funcionalidades completas, em fase de testes para um público restrito. Formato: `MAJOR.MINOR.PATCH-beta.N` (ex: `1.2.0-beta.1` ou `0.0.1-beta.1`).

O `N` é um número sequencial que se inicia em `1` para cada nova build de pré-lançamento.

**Exemplos:**

- `0.0.1-alpha.1`: Pré-lançamento inicial.
- `0.0.1-beta.1`: Pré-lançamento de testes.
- `1.0.0`: Lançamento inicial.
- `1.1.0`: Adição de um novo tipo de gráfico (funcionalidade nova).
- `1.1.1`: Correção de um bug no cálculo do saldo (correção de bug).
- `2.0.0`: Mudança na estrutura do banco de dados que exige migração manual (breaking change).

---

## 2. Nomenclatura de Branches (Git)

Adotamos um fluxo de trabalho baseado no Git Flow simplificado para organizar o desenvolvimento.

- **`main`**: Contém o código estável e de produção. Apenas merges de `release` ou `hotfix` são permitidos.
- **`develop`**: Branch principal de desenvolvimento. Contém as últimas funcionalidades e correções que serão incluídas na próxima versão.
- **`feature/<nome-da-feature>`**: Para o desenvolvimento de novas funcionalidades.
  - Criada a partir de `develop`.
  - Exemplo: `feature/exportacao-pdf`
- **`fix/<nome-da-correcao>`**: Para correções de bugs não críticos.
  - Criada a partir de `develop`.
  - Exemplo: `fix/filtro-data-invalida`
- **`hotfix/<descricao-curta>`**: Para correções críticas em produção.
  - Criada a partir de `main`.
  - Após a conclusão, deve ser mesclada em `main` e `develop`.
  - Exemplo: `hotfix/permissao-acesso-negada`
- **`release/<versao>`**: Para preparar uma nova versão de produção (testes finais, atualização de documentação).
  - Criada a partir de `develop`.
  - Exemplo: `release/v1.2.0`

---

## 3. Mensagens de Commit

Utilizamos o padrão Conventional Commits para padronizar as mensagens de commit.

**Formato:** `<tipo>(<escopo>): <descrição>`

- **`<tipo>`**:
  - `feat`: Uma nova funcionalidade.
  - `fix`: Uma correção de bug.
  - `docs`: Alterações na documentação.
  - `style`: Alterações de formatação de código (espaços, ponto e vírgula, etc.).
  - `refactor`: Refatoração de código que não altera a funcionalidade externa.
  - `test`: Adição ou correção de testes.
  - `chore`: Manutenção de build, ferramentas auxiliares, etc.

- **`<escopo>` (opcional)**: Onde a mudança ocorreu (ex: `import`, `settings`, `charts`).

**Exemplos:**

- `feat(import): adiciona validação de cabeçalhos no CSV`
- `fix(charts): corrige cálculo do saldo acumulado em meses sem lançamentos`
- `docs(readme): atualiza instruções de instalação`
- `refactor(services): otimiza QueryBuilder para usar cache de campos`

---

## 4. Nomenclatura no Código

### 4.1. CSS

- **Prefixo**: Todas as classes devem ser prefixadas com `cf-` para evitar conflitos com o Redmine ou outros plugins.
- **Metodologia**: BEM (Block, Element, Modifier).
  - `cf-bloco`
  - `cf-bloco__elemento`
  - `cf-bloco__elemento--modificador`

**Exemplos:**

- `.cf-filter-modal` (Bloco)
- `.cf-filter-modal__header` (Elemento)
- `.cf-filter-modal__button--primary` (Modificador)

### 4.2. Chaves de Internacionalização (I18n)

As chaves de tradução devem seguir uma estrutura hierárquica para facilitar a organização.

- **Padrão**: `foton_cash_flow.<area>.<subarea_ou_chave>`

**Exemplos:**

- `foton_cash_flow.settings.title`
- `foton_cash_flow.dashboard.charts.revenue_vs_expense.title`
- `foton_cash_flow.errors.missing_headers`

### 4.3. Ruby (Rails)

- **Módulos e Classes**: `PascalCase` (ex: `FotonCashFlow`, `QueryBuilder`).
- **Variáveis e Métodos**: `snake_case` (ex: `filter_params`, `calculate_totals`).
- **Arquivos**: `snake_case` (ex: `query_builder.rb`, `_summary.html.erb`).
- **Namespace**: Todo o código do plugin deve estar dentro do módulo `FotonCashFlow`.

### 4.4. JavaScript

- **Variáveis e Funções**: `camelCase` (ex: `totalAmount`, `initializeFilters`).
- **Classes**: `PascalCase` (ex: `ChartManager`).
- **Constantes**: `UPPER_SNAKE_CASE` (ex: `API_ENDPOINT`).
- **Nomes de Arquivos**: `snake_case` (ex: `cash_flow_charts.js`).