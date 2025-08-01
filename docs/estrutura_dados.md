# Estrutura de Dados do Plugin Fluxo de Caixa

Este documento descreve como o plugin "Fluxo de Caixa" armazena, utiliza e manipula os dados na base do Redmine, incluindo os campos envolvidos e exemplos de uso.

## Tabelas e Objetos Envolvidos

- **issues**: Cada lançamento financeiro é um issue (tarefa) do Redmine.
- **projects**: Cada lançamento pode estar vinculado a um projeto.
- **users**: Autor do lançamento.
- **Custom Fields**: O plugin utiliza e/ou cria campos personalizados para armazenar informações específicas do fluxo de caixa.

## Campos Utilizados/Criados

### Campos Padrão do Issue

- `id`: Identificador do lançamento
- `project_id`: Projeto relacionado
- `author_id`: Usuário autor
- `subject`: Descrição do lançamento
- `created_on`, `updated_on`: Datas de criação/atualização

### Campos Personalizados (Custom Fields)

- **Categoria** (`Categoria`): Categoria do lançamento (ex: Receita, Despesa, etc.)
- **Data do Lançamento** (`Data do Lançamento`): Data em que o lançamento ocorreu
- **Tipo de Transação** (`Tipo de Transação`): revenue (Receita) ou expense (Despesa)
- **Status** (`Status`): Situação do lançamento (ex: Pendente, Pago, Cancelado)
- **Valor** (`Valor`): Valor monetário do lançamento
- **Recorrência** (`Recorrência`): Indica se o lançamento é recorrente
- **Issue Relacionada** (`Issue Relacionada`): Para vincular a uma tarefa Redmine

> Os nomes dos campos personalizados podem ser ajustados conforme a configuração do Redmine.

## Exemplo de Lançamento (Issue)

| Campo                | Valor Exemplo         |
|----------------------|----------------------|
| Projeto              | Projeto X            |
| Autor                | João da Silva        |
| Descrição            | Pagamento fornecedor |
| Categoria            | Despesa              |
| Data do Lançamento   | 2025-07-21           |
| Tipo de Transação    | expense              |
| Status               | Pago                 |
| Valor                | 1500.00              |
| Recorrência          | Não                  |
| Issue Relacionada    | #123                 |

## Como os Dados São Adicionados/Editados

- **Novo lançamento**: O usuário preenche o formulário, que cria um novo issue com os campos personalizados preenchidos.
- **Edição**: O usuário pode editar qualquer campo do lançamento, inclusive os custom fields.
- **Importação**: O plugin permite importar lançamentos via CSV, preenchendo os campos conforme o cabeçalho do arquivo.
- **Exportação**: Os dados podem ser exportados em CSV, incluindo todos os campos relevantes.

## Observações

- O plugin não altera dados de issues que não estejam relacionados ao fluxo de caixa.
- Todos os campos personalizados são criados automaticamente na instalação, se não existirem.
- O plugin respeita as permissões de acesso do Redmine para criação, edição e visualização dos lançamentos.

---

Para dúvidas ou sugestões, consulte a documentação principal ou abra uma issue no repositório.
