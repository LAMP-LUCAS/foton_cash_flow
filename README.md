# foton Fluxo de Caixa — Plugin para Redmine

> **Controle financeiro simples, visual e eficiente para o seu Redmine.**

---

## Sobre o Plugin

O **foton Fluxo de Caixa** é um plugin desenvolvido pela comunidade FOTON para facilitar o controle de receitas e despesas diretamente no Redmine. Com ele, você registra, visualiza, importa e exporta lançamentos financeiros de forma intuitiva, com filtros avançados, somatórios automáticos e interface responsiva.

> [!TIP]
> Consulte a [estrutura detalhada do projeto e explicação dos arquivos](estrutura_projeto.md) para entender como o plugin está organizado.

> [!TIP]
> Consulte a [Estrutura dos Dados do Plugin](estrutura_dados.md) para entender como os dados são armazenados e manipulados no Redmine.

---

## Funcionalidades Principais

- **Lançamentos de Fluxo de Caixa:**
  - Cadastre receitas e despesas com data, descrição, valor, tipo, categoria e projeto
  - Vincule lançamentos a tarefas (issues) do Redmine
  - Controle o status dos lançamentos (pendente, pago, bloqueado, rejeitado)
  - Rastreie o autor de cada lançamento

- **Visualização e Filtros Avançados:**
  - Tabela paginada com ordenação personalizável
  - Modal de filtros intuitivo com interface moderna
  - Filtre por período, tipo, categoria, projeto, status, tarefa e autor
  - Tags visuais para filtros ativos
  - Pesquisa em tempo real

- **Somatórios e Análises:**
  - Totais de receitas, despesas e saldo geral em tempo real
  - Acompanhamento por projeto e categoria
  - Histórico de mudanças e auditoria

- **Importação/Exportação:**
  - Importe lançamentos via CSV com template pré-definido
  - Exporte dados filtrados com todas as colunas disponíveis
  - Validação de dados na importação

- **Permissões e Segurança:**
  - Controle de acesso por papel (role)
  - Administradores têm acesso total
  - Usuários permanentes com acesso garantido
  - Rastreamento de autoria dos lançamentos

- **Configuração Flexível:**
  - Personalize colunas visíveis na tabela
  - Configure projetos com tabelas próprias
  - Defina usuários com acesso permanente
  - Gerencie categorias de lançamentos
  - Escolha moeda padrão e outras preferências

- **Interface Moderna:**
  - Design responsivo, limpo e intuitivo
  - Grid, cards, botões e tabelas com CSS próprio (sem dependência de Bootstrap)
  - Filtros avançados e tags visuais
  - Campos formatados por tipo (data, moeda, etc)
  - Suporte completo a internacionalização (pt-BR e en)
  - Código HTML e CSS documentado para fácil manutenção

---

## Requisitos

- Redmine 5.0 ou superior
- Ruby 2.7 ou superior
- Rails 6.1 ou superior
- Banco de dados: PostgreSQL, MySQL ou SQLite3
- **Não utiliza Bootstrap** (CSS e JS próprios)

---

## Estrutura de CSS/JS

- `assets/stylesheets/cash_flow_main.css`: CSS principal, unificado, documentado e sem dependências externas.
- `assets/javascripts/cash_flow_main.js`: JS principal para filtros e interações (exceto gráficos).
- `assets/javascripts/cash_flow_dashboard.js`: JS exclusivo para gráficos (Chart.js).

## Instalação, Atualização e Remoção Automatizadas

Utilize os scripts Python disponíveis na raiz do plugin:

- `install_plugin.py`: Instala o plugin (migrações, assets e reinicialização do container).
- `update_plugin.py`: Atualiza o plugin (git pull, migrações, assets e reinicialização).
- `remove_plugin.py`: Remove o plugin (migrações reversas, apaga a pasta e reinicia o container).

Esses scripts utilizam as configurações do arquivo `.config` (nome do container, caminhos, etc). Edite conforme necessário.

**Exemplo de uso:**

```bash
python install_plugin.py
python update_plugin.py
python remove_plugin.py
```

**Atenção:**

- É necessário ter Python instalado no host.
- Os scripts assumem que o Docker Compose está configurado e o container Redmine está acessível.

Se preferir realizar o processo manualmente, siga o passo-a-passo abaixo.

---

## Instalação, Atualização e Remoção Manual (Não recomendado)

---

### Instalação (Docker Compose)

Siga o passo a passo abaixo para instalar o plugin em ambientes Docker:

1. **Acesse a pasta de plugins do Redmine:**

   ```bash
   cd /caminho/para/redmine/plugins
   ```

2. **Clone o repositório do plugin:**
    Substitua `<URL_DO_REPOSITORIO>` pela URL do repositório do plugin.

   ```bash
   git clone <URL_DO_REPOSITORIO>
   ```

3. **Execute as migrações do banco de dados:**
    Certifique-se de que o container do Redmine esteja em execução.

   ```bash
   docker compose exec redmine bundle exec rake redmine:plugins:migrate RAILS_ENV=production
   ```

4. **Publique os assets do plugin:**
    Isso garante que os arquivos estáticos do plugin sejam compilados e estejam disponíveis.

   ```bash
   docker compose exec redmine bundle exec rake redmine:plugins:assets RAILS_ENV=production
   ```

5. **Reinicie o Redmine:**
    Para aplicar as alterações, reinicie o container do Redmine.

   ```bash
   docker compose restart redmine
   ```

Pronto! O plugin estará disponível no seu Redmine.

---

### Atualização do Plugin

Para atualizar o plugin para uma nova versão:

1. **Acesse a pasta do plugin:**

   ```bash
   cd /caminho/para/redmine/plugins/redmine_cash_flow_pro
   ```

2. **Atualize o repositório:**

   ```bash
   git pull origin main
   ```

3. **Reaplique as migrações (se necessário):**

   ```bash
   docker compose exec redmine bundle exec rake redmine:plugins:migrate RAILS_ENV=production
   ```

4. **Republique os assets:**

   ```bash
   docker compose exec redmine bundle exec rake redmine:plugins:assets RAILS_ENV=production
   ```

5. **Reinicie o Redmine:**

   ```bash
   docker compose restart redmine
   ```

---

### Remoção do Plugin

Se precisar remover o plugin:

1. **Remova as migrações do banco de dados:**

   ```bash
   docker compose exec redmine bundle exec rake redmine:plugins:migrate NAME=redmine_cash_flow_pro VERSION=0 RAILS_ENV=production
   ```

2. **Exclua a pasta do plugin:**

   ```bash
   rm -rf /caminho/para/redmine/plugins/redmine_cash_flow_pro
   ```

3. **Reinicie o Redmine:**

   ```bash
   docker compose restart redmine
   ```

---

## Configuração Inicial

Após instalar, siga estes passos para configurar:

- Ative o módulo "Fluxo de Caixa" no projeto desejado (opcional).
- Defina permissões em **Administração > Papéis e Permissões**.
- Ajuste colunas, projetos e usuários em **Administração > Configurações > Fluxo de Caixa**.

---

## Como Usar

- Acesse o menu **Fluxo de Caixa** no topo ou dentro do projeto.
- Clique em **Novo Lançamento** para adicionar receitas ou despesas.
- Utilize os filtros para refinar a visualização dos lançamentos.
- Importe lançamentos via CSV pelo link **Importar CSV**.
- Exporte lançamentos filtrados pelo link **Exportar CSV**.
- Edite ou exclua lançamentos conforme necessário.

---

## Template para Importação

Um template CSV está disponível em:

- `import_template.csv` (na raiz do plugin)

---

## Suporte e Comunidade

Este plugin é desenvolvido e mantido pela comunidade FOTON.
Fique à vontade para abrir issues, sugerir melhorias ou contribuir!

---

### Ferramentas Utilizadas

Utilizamos llms como ferramentas de apoio no desenvolvimento, as seguintes ferramentas foram utilizadas: Github Copilot (GPT 4.1, Gemini, Claude Sonnet 3.5), Gemini, Deepseek R1.

---
