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

O par `(material_id, deposito_id)` é a chave primária de `saldos_iniciais` e `contagens_fisicas`. Em `movimentacoes` e `contagens_fisicas`, as duas colunas formam uma chave estrangeira composta que referencia `saldos_iniciais`. No primeiro print, o resultado de `PRAGMA foreign_key_list('movimentacoes')` mostra as duas colunas com o mesmo `id` e posições `seq` 0 e 1. [Evidência das chaves no DBeaver](Evidências/Validação/validacao-chaves.png)

A conferência parte de `saldos_iniciais` e usa `LEFT JOIN` com `contagens_fisicas` pelas duas colunas da chave. Isso preserva os pares no escopo e permite distinguir uma linha ausente de um campo em branco. [Evidência da população no DBeaver](Evidências/Validação/validacao-populacao.png)

| Depósito | No escopo | Linhas no caderno | Preenchidas | Sem linha | Em branco | Contadas como zero |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Norte | 240 | 240 | 229 | 0 | 11 | 1 |
| Sul | 240 | 240 | 229 | 0 | 11 | 0 |
| **Total** | **480** | **480** | **458** | **0** | **22** | **1** |

A contagem zero do Depósito Norte está incluída nas 458 preenchidas. Os 22 campos em branco ficam pendentes de contagem.

## Conciliação em SQL e validações executadas

O arquivo [analise.sql](Evidências/Análise/analise.sql) contém oito consultas independentes de leitura. No DBeaver, execute cada instrução completa, incluindo seu bloco `WITH`, quando houver. A primeira gera a conciliação detalhada. As demais conferem as classificações, a unicidade, os indicadores por depósito, os três lançamentos de fronteira, o item com saldo zero e os dois casos selecionados com suas movimentações.

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

Foram selecionados intencionalmente dois tipos de exceção no Depósito Norte, que teve 37 divergências. Ambos remetem à folha `INV-01-01`, primeira página do [caderno de contagem](Material%20de%20Contagem/caderno-contagem-estoque.pdf). A ficha mostra campo em branco para MAT-0005 e 604 unidades para MAT-0011. As consultas 7 e 8 do [analise.sql](Evidências/Análise/analise.sql) reproduzem a seleção e listam os movimentos para conferir quantidade e corte.

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

## Exportação validada para o painel

O arquivo [conciliacao-estoque.json](Evidências/Análise/conciliacao-estoque.json) contém 480 registros e 480 pares distintos. Todos os campos e valores foram comparados com a consulta 1 do SQLite. A conferência confirmou 385 conformes, 40 faltas, 33 sobras e 22 sem contagem registrada, preservando números, zeros e valores `null`.

A exportação do DBeaver foi padronizada como uma lista JSON na raiz, com o campo `classificacao`. Esse é o formato a usar na importação do painel.

## Criar e validar o painel no Lovable

1. Inicie um projeto no Lovable e use o prompt abaixo.
2. Use no aplicativo o botão de importação para carregar [conciliacao-estoque.json](Evidências/Análise/conciliacao-estoque.json). O arquivo contém a lista completa de resultados conciliados.
3. Confira os totais sem filtros e depois selecione cada depósito. Teste também a classificação e o botão de limpar filtros.
4. Registre uma captura do painel em `Evidências/Validação` após conferir os resultados.

### Prompt para construir o painel

> Crie um dashboard responsivo em português do Brasil para um projeto de auditoria de estoque com dados fictícios. Use fundo claro, cartões de indicadores e gráficos legíveis. Inclua um botão de importação de arquivo JSON que leia uma lista de registros, valide os campos e mostre uma mensagem clara em caso de formato inválido. Antes da importação, apresente um estado vazio pedindo o arquivo.
>
> Os campos são material_id, sku, deposito_id, deposito, saldo_inicial, movimento_liquido, saldo_esperado, quantidade_contada, folha, diferenca e classificacao. Os números são valores numéricos. quantidade_contada e diferenca podem ser null. Exiba null como "Pendente" e preserve zero como quantidade válida. A chave de cada registro é material_id + deposito_id.
>
> Calcule todos os indicadores com os registros importados. Divergências são apenas as classificações Falta e Sobra. Pendências são Sem contagem registrada. Mostre cartões de pares no escopo, conformes, divergências, contagens pendentes e as taxas de divergência e pendência. O denominador das taxas é o total de pares no recorte selecionado.
>
> Inclua filtros por depósito e classificação, busca por SKU e botão para limpar filtros. Todos os cartões, gráficos e linhas devem acompanhar os filtros. Exiba as contagens junto aos percentuais. Inclua gráfico por classificação e comparação por depósito. Em recorte vazio, exiba taxas como "Sem dados".
>
> Inclua tabela paginada com SKU, depósito, saldo esperado, quantidade contada, diferença, classificação e folha. Destaque faltas, sobras e pendências com rótulos além das cores. Mostre que a data de corte é 30/09/2026 às 18h, horário de Brasília, e que a fonte é uma conciliação SQL de dados fictícios. Para consultar novamente os resultados após recarregar a página, permita importar o mesmo JSON.

### Conferência de aceitação

| Recorte | Pares | Conformes | Divergências | Pendentes | Taxa de divergência | Taxa de pendência |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Sem filtros | 480 | 385 | 73 | 22 | 15,21% | 4,58% |
| Norte | 240 | 192 | 37 | 11 | 15,42% | 4,58% |
| Sul | 240 | 193 | 36 | 11 | 15,00% | 4,58% |

Confira MAT-0001 no Norte com contagem zero e classificação Conforme. MAT-0005 no Norte deve aparecer como Pendente na quantidade e na diferença, com saldo esperado 403. MAT-0011 no Norte deve mostrar saldo 607, contagem 604 e diferença -3. A criação e a validação do painel serão concluídas quando esses testes forem executados no aplicativo.

### Evidências do painel no Lovable

| Captura | Validação observada |
| --- | --- |
| [10 — Visão geral](Evidências/Validação/10-painel-visao-geral.png) | Importação de 480 registros. Cartões com 385 conformes, 73 divergências e 22 pendências. Taxas de 15,21% e 4,58%. |
| [11 — Gráficos](Evidências/Validação/11-painel-graficos.png) | Distribuição com 385 conformes, 40 faltas, 33 sobras e 22 pendências. Norte com 37 divergências em 240 pares e Sul com 36 em 240. |
| [12 — Tabela](Evidências/Validação/12-painel-tabela.png) | MAT-0001 no Norte com contagem zero. MAT-0005 com saldo esperado 403 e quantidade e diferença pendentes. Tabela com código da folha e indicação de 480 registros. |

Os indicadores sem filtros coincidiram com os resultados SQL. As capturas mostram os controles de filtro e paginação. A validação da interação deve conferir a seleção de cada depósito, a classificação, a busca por SKU, a limpeza de filtros e a abertura dos detalhes. Conferir também MAT-0011 no Norte com saldo 607, contagem 604 e diferença -3, e o destino do vínculo da folha.

### Evidências dos testes de interação

| Captura | Resultado observado |
| --- | --- |
| [13 — Filtro Norte](Evidências/Validação/13-filtro-norte.png) | 240 pares, 192 conformes, 37 divergências e 11 pendências. Taxas de 15,42% e 4,58%. |
| [14 — Tabela Norte](Evidências/Validação/14-tabela-norte.png) | Tabela restrita ao Norte, com 240 registros e indicação de 24 páginas. |
| [15 — Filtro Falta](Evidências/Validação/15-filtro-falta.png) | 40 faltas, divididas em 20 por depósito. A taxa de divergência no recorte filtrado é 100%. |
| [16 — Tabela de faltas](Evidências/Validação/16-tabela-faltas.png) | 40 registros e indicação de quatro páginas, com dez linhas na primeira página. |
| [17 — Busca MAT-0011](Evidências/Validação/17-busca-mat0011.png) | Dois pares localizados. Norte com saldo 607, contagem 604 e diferença -3. Sul com saldo 618, contagem 615 e diferença -3. |
| [18 — Filtros limpos](Evidências/Validação/18-filtros-limpos.png) | Retorno aos 480 pares, 385 conformes, 73 divergências e 22 pendências. |
| [19 — Detalhe MAT-0110](Evidências/Validação/19-detalhe-mat0110.png) | Modal do MAT-0110 no Norte com saldo inicial 929, movimento -82, saldo esperado 847, contagem 844, diferença -3 e folha INV-01-03. |

As capturas confirmam o filtro Norte, o filtro Falta, a busca MAT-0011 e o retorno ao total geral. A captura 19 confirma a abertura do detalhe de MAT-0110 e a exibição do código da folha.

| Captura complementar | Resultado observado |
| --- | --- |
| [20 — Filtro Sul](Evidências/Validação/20-filtro-sul.png) | 240 pares, 193 conformes, 36 divergências e 11 pendências. Taxas de 15,00% e 4,58%. |
| [21 — Sobras no Sul](Evidências/Validação/21-sobras-sul.png) | 16 sobras no recorte Sul, com taxa de divergência de 100% entre os registros filtrados. |
| [22 — Pendências no Sul](Evidências/Validação/22-pendencias-sul.png) | 11 registros sem contagem, com taxa de pendência de 100% no recorte. |
| [23 — Primeira página](Evidências/Validação/23-paginacao-primeira.png) | Exibe os registros 1 a 10 das 11 pendências do Sul. |
| [24 — Segunda página](Evidências/Validação/24-paginacao-segunda.png) | Exibe o registro 11, MAT-0240, com saldo esperado 727 e contagem pendente. Os indicadores mantêm o total filtrado de 11 registros. |
| [25 — Detalhes do MAT-0240](Evidências/Validação/25-detalhe-mat0240.png) | Modal com saldo inicial 778, movimento -51, saldo esperado 727, contagem e diferença pendentes e folha INV-02-06. |

Os filtros Sul, Sobra e Sem contagem registrada e a troca de página foram conferidos nas capturas. Conforme o teste relatado, os cliques no material e na folha exibem o modal de detalhes. A captura 25 documenta esse modal e a referência INV-02-06. A consulta à ficha original pode ser feita pelo [caderno de contagem](Material%20de%20Contagem/caderno-contagem-estoque.pdf), na página 12, correspondente a essa folha.

## Relatório de auditoria interna

O [relatório RA-EST-001 em PDF](Relatório%20Final/relatorio-auditoria-estoque.pdf), emitido em 19/11/2026, apresenta introdução, motivo, objetivo, fluxo, procedimento, pontos de melhoria, ponto auditado e evidências selecionadas. A estrutura utiliza as Normas Globais de Auditoria Interna do IIA como referência para o exercício.

**Conclusão.** No recorte simulado, o inventário requer melhoria na conciliação e na completude. Foram identificados 385 pares conformes, 73 divergências quantitativas e 22 contagens pendentes. A recontagem, a investigação do corte e o tratamento documentado das pendências sustentariam eventual ajuste. As causas e as perdas efetivas dependem de evidências adicionais.

O relatório inclui a investigação de MAT-0005 e MAT-0011 no Norte, capturas das consultas e do painel, além de ações propostas. Responsáveis por área e prazos são sugestões para a simulação e dependem de acordo com a gestão. A emissão do documento e sua inclusão no projeto foram concluídas. A publicação externa permanece pendente.

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
- [x] Exportar pelo DBeaver o resultado da consulta de conciliação em JSON. Incluir depósito, material, classificação, saldo esperado, quantidade contada, diferença e código da folha.
- [x] Criar o painel no Lovable a partir do JSON, com cartões para itens no escopo, divergências e contagens pendentes. Incluir filtros por depósito e classificação e exibir o código da folha na tabela.
- [x] Validar o painel sem filtros contra o SQLite. Os resultados esperados são **480 combinações no escopo, 73 divergências (40 faltas e 33 sobras) e 22 contagens pendentes**.
- [x] Conferir o filtro Norte, o filtro Falta, a busca MAT-0011, a limpeza de filtros e a abertura dos detalhes de um item.
- [x] Conferir os filtros Sul, Sobra e Sem contagem registrada, a troca de página e o modal de detalhes com referência à folha.
- [x] Elaborar o relatório de auditoria interna em PDF e incluí-lo no README.
- [ ] Publicar o projeto e o painel e compartilhar um resumo no LinkedIn.

As Normas Globais de Auditoria Interna do IIA orientam a estrutura do exercício, em especial objetivos e escopo (13.3), critérios (13.4), documentação (14.6) e comunicação final (15.1).