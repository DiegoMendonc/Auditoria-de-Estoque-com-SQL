# Auditoria de estoque com SQL

**Em construção** · Projeto de portfólio de auditoria interna com dados fictícios.

## Resumo executivo

O projeto simula um inventário da Horizonte Suprimentos. O objetivo é verificar se o saldo registrado no ERP na data de corte coincide com a contagem física feita nos depósitos. As consultas em SQL no SQLite serão usadas para reconstruir os saldos, classificar as diferenças, reconciliar os totais e calcular os indicadores por depósito. Os resultados poderão ser exportados pelo DBeaver em JSON para alimentar o painel no Lovable.

[Norma interna](norma-interna-inventario.md) · [Base do ERP](base.sql) · [Caderno de contagem em PDF](Material%20de%20Contagem/caderno-contagem-estoque.pdf) · [Transcrição da contagem](contagem-fisica.sql)

## Objetivo e escopo

- **Risco avaliado** — saldos incorretos podem afetar o reabastecimento, a disponibilidade de materiais e os registros de estoque.
- **População** — 480 combinações de material e depósito, incluindo saldo zero. Cada combinação representa uma unidade de análise.
- **Depósitos** — Norte e Sul. Todos os materiais usam a unidade UN.
- **Período** — saldo de abertura em 01/09/2026 às 00h e inventário em 30/09/2026 às 18h, no horário de Brasília.
- **Limites** — o exercício testa quantidades e corte de lançamentos. Custos de referência estão disponíveis para uma análise posterior da exposição. As causas e os ajustes dependeriam de evidência complementar.

## Critério de auditoria

A [NOR-EST-001](norma-interna-inventario.md) define como comparar o saldo do ERP com o caderno de contagem. Some entradas e subtraia saídas registradas até o corte, inclusive. Calcule a diferença como **contagem física menos saldo esperado**. Uma diferença negativa é falta e uma positiva é sobra. Campo em branco é contagem pendente. Zero é uma quantidade válida.

Use `registrado_em` para reconstruir o saldo disponível no ERP no instante do inventário. Use `ocorrido_em` para investigar movimentos físicos anteriores ao corte lançados depois dele. Os três lançamentos `MOV-036001`, `MOV-036002` e `MOV-036003` foram incluídos para testar essa distinção.

## Base e evidência

| Fonte | Conteúdo | Registros |
| --- | --- | ---: |
| `materiais` | SKU, descrição, categoria, unidade e custo de referência | 240 |
| `depositos` | Depósitos Norte e Sul | 2 |
| `saldos_iniciais` | Saldo de abertura por material e depósito | 480 |
| `movimentacoes` | Documento, quantidade, tipo e horários de ocorrência e registro | 35.928 |
| `contagens_fisicas` | Quantidade observada e código da folha de origem | 480 |

O PDF simula a ficha preenchida antes do lançamento no ERP. São **12 folhas de 40 itens**, sem indicação de saldo sistêmico. A transcrição em SQL preserva o código da folha e representa campos em branco com `NULL`. Na simulação, os valores físicos foram gerados a partir do saldo reconstruído com diferenças intencionais para exercitar a análise.

## Como carregar no DBeaver

1. Crie uma conexão SQLite para um arquivo vazio chamado `auditoria_estoque.db`.
2. Abra [base.sql](base.sql) nessa conexão e execute o script completo com **Alt+X**.
3. Abra [contagem-fisica.sql](contagem-fisica.sql) na mesma conexão e execute com **Alt+X**. Use cada script uma vez por banco novo.
4. Confira as contagens com **Ctrl+Enter**.

```sql
SELECT
    (SELECT COUNT(*) FROM movimentacoes) AS movimentos,
    COUNT(*) AS linhas_do_caderno,
    COUNT(quantidade_contada) AS contagens_preenchidas
FROM contagens_fisicas;
```

O resultado esperado é **35.928 movimentos, 480 linhas do caderno e 458 contagens preenchidas**. Use estes totais de referência para validar a futura conciliação.

| Classificação | Combinações |
| --- | ---: |
| Conforme | 385 |
| Falta | 40 |
| Sobra | 33 |
| Sem contagem registrada | 22 |
| **Total no escopo** | **480** |

## Validação das chaves e da população

O par `(material_id, deposito_id)` é a chave primária de `saldos_iniciais` e `contagens_fisicas`. Em `movimentacoes` e `contagens_fisicas`, as duas colunas formam uma chave estrangeira composta que referencia `saldos_iniciais`. No primeiro print, o resultado de `PRAGMA foreign_key_list('movimentacoes')` mostra as duas colunas com o mesmo `id` e posições `seq` 0 e 1. [Evidência das chaves no DBeaver](evidencias/validacao-chaves.png)

A conferência parte de `saldos_iniciais` e usa `LEFT JOIN` com `contagens_fisicas` pelas duas colunas da chave. Isso preserva os pares no escopo e permite distinguir uma linha ausente de um campo em branco. [Evidência da população no DBeaver](evidencias/validacao-populacao.png)

| Depósito | No escopo | Linhas no caderno | Preenchidas | Sem linha | Em branco | Contadas como zero |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Norte | 240 | 240 | 229 | 0 | 11 | 1 |
| Sul | 240 | 240 | 229 | 0 | 11 | 0 |
| **Total** | **480** | **480** | **458** | **0** | **22** | **1** |

A contagem zero do Depósito Norte está incluída nas 458 preenchidas. Os 22 campos em branco ficam pendentes de contagem.

## Conciliação em SQL e validações executadas

O arquivo [analise.sql](analise.sql) contém oito consultas independentes de leitura. No DBeaver, execute cada instrução completa, incluindo seu bloco `WITH`, quando houver. A primeira gera a conciliação detalhada. As demais conferem as classificações, a unicidade, os indicadores por depósito, os três lançamentos de fronteira, o item com saldo zero e os dois casos selecionados com suas movimentações.

A análise usa o saldo inicial e os movimentos registrados entre a abertura de cada par e 30/09/2026 às 18h, inclusive. Entradas somam e saídas subtraem. As junções preservam os pares sem movimento ou sem contagem. A diferença é quantidade contada menos saldo esperado. Cada linha inclui o código da folha para rastrear a contagem física.

### Resultados observados no banco local

A consulta retornou **480 linhas e 480 pares distintos**, sem duplicação da unidade de análise. As classificações reconciliaram com a população inicial, com diferença zero.

| Resultado | Pares |
| --- | ---: |
| Conforme | 385 |
| Falta | 40 |
| Sobra | 33 |
| Sem contagem registrada | 22 |
| **Total** | **480** |

| Depósito | Escopo | Divergências | Taxa de divergência | Pendentes | Taxa de pendência |
| --- | ---: | ---: | ---: | ---: | ---: |
| Norte | 240 | 37 | 15,42% | 11 | 4,58% |
| Sul | 240 | 36 | 15,00% | 11 | 4,58% |
| **Total** | **480** | **73** | **15,21%** | **22** | **4,58%** |

As taxas usam todos os pares no escopo do respectivo depósito como denominador. As 73 divergências abrangem faltas e sobras. A taxa de pendência representa os campos de contagem em branco.

### Testes de corte e saldo zero

- `MOV-036001`, entrada de 7 unidades registrada exatamente às 18h, foi incluída.
- `MOV-036002`, entrada de 9 unidades ocorrida às 17h59 e registrada às 18h01, ficou fora do saldo registrado no corte. É um exemplo para investigar o atraso de lançamento com documentos de origem.
- `MOV-036003`, saída de 4 unidades ocorrida às 18h01 e registrada às 18h02, ficou fora do corte.
- `MAT-0001` no Depósito Norte permaneceu no resultado com saldo esperado zero, contagem zero e classificação conforme.

### Conclusão desta etapa

Foram identificadas **73 divergências quantitativas e 22 contagens pendentes** na simulação. O Depósito Norte apresentou uma divergência a mais que o Sul, com a mesma população de 240 pares. As consultas identificam os casos para investigação. A causa das diferenças e a necessidade de ajuste dependeriam de recontagem e documentação dos movimentos. Os testes de corte e a reconciliação das classificações foram concluídos. A investigação de dois casos é a próxima etapa.

## Evidências da execução no DBeaver

As capturas abaixo foram registradas em 18/11/2026 e estão relacionadas na ordem enviada.

| Ordem | Evidência | Resultado visível |
| --- | --- | --- |
| 1 | [Conciliação detalhada](Evidências/Validação/01-conciliacao-detalhada.png) | Exibe a consulta e parte dos saldos e contagens. A grade indica 200 linhas recuperadas nessa visualização. |
| 2 | [Classificações](Evidências/Validação/02-classificacoes.png) | 385 conformes, 40 faltas, 33 sobras e 22 sem contagem registrada. |
| 3 | [Unicidade e população](Evidências/Validação/03-unicidade-populacao.png) | 480 linhas e 480 pares distintos. |
| 4 | [Repetição da validação de unicidade](Evidências/Validação/04-unicidade-populacao-repeticao.png) | Repete a captura anterior com os mesmos totais. |
| 5 | [Indicadores por depósito](Evidências/Validação/05-indicadores-deposito.png) | Norte com 37 divergências (15,42%) e Sul com 36 (15,00%). Ambos têm 11 pendências (4,58%) em 240 pares. |
| 6 | [Fronteira do corte](Evidências/Validação/06-fronteira-corte.png) | MOV-036001 incluído. MOV-036002 e MOV-036003 fora do corte. |
| 7 | [Controle de saldo zero](Evidências/Validação/07-saldo-zero.png) | MAT-0001 no Norte com saldo inicial, movimento líquido, saldo esperado e quantidade contada iguais a zero. |
| 8 | [Casos investigados — consulta 7](Evidências/Validação/08-casos-investigados.png) | MAT-0005 com saldo esperado de 403 e contagem em branco. MAT-0011 com saldo esperado de 607 e contagem de 604. |
| 9 | [Movimentações dos casos — consulta 8](Evidências/Validação/09-movimentos-casos.png) | A grade indica 150 movimentos recuperados e mostra documentos, quantidades, horários e tratamento no corte. |

A captura 3 confirma o total de 480 pares da conciliação. A captura 1 mostra a parcela carregada na grade. As classificações da captura 2 somam a mesma população e os indicadores da captura 5 reconciliam com 73 divergências e 22 pendências.

## Investigação de dois casos

Foram selecionados intencionalmente dois tipos de exceção no Depósito Norte, que teve 37 divergências. Ambos remetem à folha `INV-01-01`, primeira página do [caderno de contagem](caderno-contagem-estoque.pdf). A ficha mostra campo em branco para MAT-0005 e 604 unidades para MAT-0011. As consultas 7 e 8 do [analise.sql](Evidências/Análise/analise.sql) reproduzem a seleção e listam os movimentos para conferir quantidade e corte.

| Caso | Saldo inicial | Movimento líquido no corte | Saldo esperado | Contagem | Diferença |
| --- | ---: | ---: | ---: | ---: | ---: |
| MAT-0005, Norte | 474 | -71 | 403 | Em branco | Indeterminada |
| MAT-0011, Norte | 660 | -53 | 607 | 604 | -3 |

### MAT-0005 — contagem pendente

Foram localizados 75 movimentos, dos quais 66 registrados até o corte. A ficha e a transcrição apresentam a quantidade em branco. A evidência disponível sustenta a pendência de contagem, com saldo sistêmico reconstruído de 403 unidades. A diferença quantitativa depende da realização ou recuperação da contagem.

Solicitar a folha original revisada, o controle de conclusão do inventário e eventual ficha de recontagem independente. Esses registros permitiriam verificar se o item foi omitido na coleta ou se houve uma contagem posterior. A solicitação é simulada e a confirmação permanece pendente.

### MAT-0011 — falta de três unidades

Foram localizados 75 movimentos, dos quais 63 registrados até o corte. O saldo reconstruído é 607 unidades e a ficha registra 604. A diferença de -3 atende ao critério de falta da NOR-EST-001.

Solicitar recontagem independente e comprovantes de entrada e saída próximos ao corte, com identificação do material, depósito, quantidade e horário. Para os dois casos, a base não apresentou eventos ocorridos até o corte e registrados depois. A investigação deve confrontar os registros com os documentos físicos e verificar a completude da extração.

**Conclusão preliminar.** A diferença de três unidades foi confirmada entre os registros disponíveis. Sua causa e eventual ajuste dependem das evidências adicionais. O caso de MAT-0005 permanece pendente de quantidade física. Os dois casos ilustram a investigação e foram selecionados sem objetivo de projeção estatística para a população.

## Checklist

- [x] Definir objetivo, riscos, escopo e data de corte.
- [x] Documentar o critério de inventário na norma fictícia.
- [x] Gerar a base SQLite com lançamentos próximos ao corte.
- [x] Gerar o caderno de contagem e sua transcrição rastreável.
- [x] Mapear as chaves do modelo e conferir a população.
- [x] Escrever a conciliação em SQL, mantendo uma linha por material e depósito.
- [x] Testar os lançamentos de fronteira em SQL e reconciliar as classificações com as 480 combinações no escopo.
- [x] Organizar as consultas de conciliação, reconciliação e indicadores em um script SQL reproduzível.
- [x] Comparar as taxas de divergência e de contagem pendente por depósito usando SQL e investigar dois casos, registrando as evidências adicionais a solicitar.
- [ ] Exportar pelo DBeaver o resultado da consulta de conciliação em JSON. Incluir depósito, material, classificação, saldo esperado, quantidade contada, diferença e código da folha.
- [ ] Criar o painel no Lovable a partir do JSON, com cartões para itens no escopo, divergências e contagens pendentes. Incluir filtros por depósito e classificação e exibir o código da folha na tabela.
- [ ] Validar o painel sem filtros contra o SQLite. Os resultados esperados são **480 combinações no escopo, 73 divergências (40 faltas e 33 sobras) e 22 contagens pendentes**.
- [ ] Publicar o relatório, o painel e um resumo para o LinkedIn.

As Normas Globais de Auditoria Interna do IIA orientam a estrutura do exercício, em especial objetivos e escopo (13.3), critérios (13.4), documentação (14.6) e comunicação final (15.1).