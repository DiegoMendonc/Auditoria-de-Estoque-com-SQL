-- Consultas de leitura. Execute cada instrução completa, incluindo seu WITH.

-- 1. Conciliação detalhada
WITH saldos AS (
    SELECT
        s.material_id,
        s.deposito_id,
        s.quantidade AS saldo_inicial,
        COALESCE(SUM(CASE WHEN v.tipo = 'ENTRADA' THEN v.quantidade ELSE -v.quantidade END), 0) AS movimento_liquido
    FROM saldos_iniciais AS s
    LEFT JOIN movimentacoes AS v
        ON v.material_id = s.material_id
       AND v.deposito_id = s.deposito_id
       AND v.registrado_em >= s.data_base
       AND v.registrado_em <= '2026-09-30 18:00:00'
    GROUP BY s.material_id, s.deposito_id, s.quantidade
),
conciliacao AS (
    SELECT
        s.material_id, m.sku, s.deposito_id, d.nome AS deposito,
        s.saldo_inicial, s.movimento_liquido,
        s.saldo_inicial + s.movimento_liquido AS saldo_esperado,
        c.quantidade_contada, c.folha,
        c.quantidade_contada - (s.saldo_inicial + s.movimento_liquido) AS diferenca,
        CASE
            WHEN c.quantidade_contada IS NULL THEN 'Sem contagem registrada'
            WHEN c.quantidade_contada < s.saldo_inicial + s.movimento_liquido THEN 'Falta'
            WHEN c.quantidade_contada > s.saldo_inicial + s.movimento_liquido THEN 'Sobra'
            ELSE 'Conforme'
        END AS classificacao
    FROM saldos AS s
    JOIN materiais AS m ON m.id = s.material_id
    JOIN depositos AS d ON d.id = s.deposito_id
    LEFT JOIN contagens_fisicas AS c
        ON c.material_id = s.material_id AND c.deposito_id = s.deposito_id
)
SELECT * FROM conciliacao ORDER BY deposito_id, material_id;

-- 2. Reconciliação das classificações
WITH saldos AS (
    SELECT
        s.material_id,
        s.deposito_id,
        s.quantidade AS saldo_inicial,
        COALESCE(SUM(CASE WHEN v.tipo = 'ENTRADA' THEN v.quantidade ELSE -v.quantidade END), 0) AS movimento_liquido
    FROM saldos_iniciais AS s
    LEFT JOIN movimentacoes AS v
        ON v.material_id = s.material_id
       AND v.deposito_id = s.deposito_id
       AND v.registrado_em >= s.data_base
       AND v.registrado_em <= '2026-09-30 18:00:00'
    GROUP BY s.material_id, s.deposito_id, s.quantidade
),
conciliacao AS (
    SELECT
        s.material_id, m.sku, s.deposito_id, d.nome AS deposito,
        s.saldo_inicial, s.movimento_liquido,
        s.saldo_inicial + s.movimento_liquido AS saldo_esperado,
        c.quantidade_contada, c.folha,
        c.quantidade_contada - (s.saldo_inicial + s.movimento_liquido) AS diferenca,
        CASE
            WHEN c.quantidade_contada IS NULL THEN 'Sem contagem registrada'
            WHEN c.quantidade_contada < s.saldo_inicial + s.movimento_liquido THEN 'Falta'
            WHEN c.quantidade_contada > s.saldo_inicial + s.movimento_liquido THEN 'Sobra'
            ELSE 'Conforme'
        END AS classificacao
    FROM saldos AS s
    JOIN materiais AS m ON m.id = s.material_id
    JOIN depositos AS d ON d.id = s.deposito_id
    LEFT JOIN contagens_fisicas AS c
        ON c.material_id = s.material_id AND c.deposito_id = s.deposito_id
)
SELECT classificacao, COUNT(*) AS total FROM conciliacao GROUP BY classificacao ORDER BY classificacao;

-- 3. Validação da unicidade e população
WITH saldos AS (
    SELECT
        s.material_id,
        s.deposito_id,
        s.quantidade AS saldo_inicial,
        COALESCE(SUM(CASE WHEN v.tipo = 'ENTRADA' THEN v.quantidade ELSE -v.quantidade END), 0) AS movimento_liquido
    FROM saldos_iniciais AS s
    LEFT JOIN movimentacoes AS v
        ON v.material_id = s.material_id
       AND v.deposito_id = s.deposito_id
       AND v.registrado_em >= s.data_base
       AND v.registrado_em <= '2026-09-30 18:00:00'
    GROUP BY s.material_id, s.deposito_id, s.quantidade
),
conciliacao AS (
    SELECT
        s.material_id, m.sku, s.deposito_id, d.nome AS deposito,
        s.saldo_inicial, s.movimento_liquido,
        s.saldo_inicial + s.movimento_liquido AS saldo_esperado,
        c.quantidade_contada, c.folha,
        c.quantidade_contada - (s.saldo_inicial + s.movimento_liquido) AS diferenca,
        CASE
            WHEN c.quantidade_contada IS NULL THEN 'Sem contagem registrada'
            WHEN c.quantidade_contada < s.saldo_inicial + s.movimento_liquido THEN 'Falta'
            WHEN c.quantidade_contada > s.saldo_inicial + s.movimento_liquido THEN 'Sobra'
            ELSE 'Conforme'
        END AS classificacao
    FROM saldos AS s
    JOIN materiais AS m ON m.id = s.material_id
    JOIN depositos AS d ON d.id = s.deposito_id
    LEFT JOIN contagens_fisicas AS c
        ON c.material_id = s.material_id AND c.deposito_id = s.deposito_id
)
SELECT COUNT(*) AS total_linhas, COUNT(DISTINCT printf('%d/%d', material_id, deposito_id)) AS pares_distintos FROM conciliacao;

-- 4. Indicadores por depósito
WITH saldos AS (
    SELECT
        s.material_id,
        s.deposito_id,
        s.quantidade AS saldo_inicial,
        COALESCE(SUM(CASE WHEN v.tipo = 'ENTRADA' THEN v.quantidade ELSE -v.quantidade END), 0) AS movimento_liquido
    FROM saldos_iniciais AS s
    LEFT JOIN movimentacoes AS v
        ON v.material_id = s.material_id
       AND v.deposito_id = s.deposito_id
       AND v.registrado_em >= s.data_base
       AND v.registrado_em <= '2026-09-30 18:00:00'
    GROUP BY s.material_id, s.deposito_id, s.quantidade
),
conciliacao AS (
    SELECT
        s.material_id, m.sku, s.deposito_id, d.nome AS deposito,
        s.saldo_inicial, s.movimento_liquido,
        s.saldo_inicial + s.movimento_liquido AS saldo_esperado,
        c.quantidade_contada, c.folha,
        c.quantidade_contada - (s.saldo_inicial + s.movimento_liquido) AS diferenca,
        CASE
            WHEN c.quantidade_contada IS NULL THEN 'Sem contagem registrada'
            WHEN c.quantidade_contada < s.saldo_inicial + s.movimento_liquido THEN 'Falta'
            WHEN c.quantidade_contada > s.saldo_inicial + s.movimento_liquido THEN 'Sobra'
            ELSE 'Conforme'
        END AS classificacao
    FROM saldos AS s
    JOIN materiais AS m ON m.id = s.material_id
    JOIN depositos AS d ON d.id = s.deposito_id
    LEFT JOIN contagens_fisicas AS c
        ON c.material_id = s.material_id AND c.deposito_id = s.deposito_id
)
SELECT deposito,
    COUNT(*) AS escopo,
    SUM(CASE WHEN classificacao IN ('Falta', 'Sobra') THEN 1 ELSE 0 END) AS divergencias,
    SUM(CASE WHEN classificacao = 'Sem contagem registrada' THEN 1 ELSE 0 END) AS pendentes,
    ROUND(100.0 * SUM(CASE WHEN classificacao IN ('Falta', 'Sobra') THEN 1 ELSE 0 END) / COUNT(*), 2) AS taxa_divergencias_pct,
    ROUND(100.0 * SUM(CASE WHEN classificacao = 'Sem contagem registrada' THEN 1 ELSE 0 END) / COUNT(*), 2) AS taxa_pendencias_pct
FROM conciliacao GROUP BY deposito_id, deposito ORDER BY deposito_id;

-- 5. Fronteira do corte
SELECT documento, tipo, quantidade, ocorrido_em, registrado_em,
    CASE WHEN registrado_em <= '2026-09-30 18:00:00' THEN 'Incluído' ELSE 'Fora do corte' END AS tratamento
FROM movimentacoes WHERE id IN (36001, 36002, 36003) ORDER BY id;

-- 6. Controle com saldo zero
WITH saldos AS (
    SELECT
        s.material_id,
        s.deposito_id,
        s.quantidade AS saldo_inicial,
        COALESCE(SUM(CASE WHEN v.tipo = 'ENTRADA' THEN v.quantidade ELSE -v.quantidade END), 0) AS movimento_liquido
    FROM saldos_iniciais AS s
    LEFT JOIN movimentacoes AS v
        ON v.material_id = s.material_id
       AND v.deposito_id = s.deposito_id
       AND v.registrado_em >= s.data_base
       AND v.registrado_em <= '2026-09-30 18:00:00'
    GROUP BY s.material_id, s.deposito_id, s.quantidade
),
conciliacao AS (
    SELECT
        s.material_id, m.sku, s.deposito_id, d.nome AS deposito,
        s.saldo_inicial, s.movimento_liquido,
        s.saldo_inicial + s.movimento_liquido AS saldo_esperado,
        c.quantidade_contada, c.folha,
        c.quantidade_contada - (s.saldo_inicial + s.movimento_liquido) AS diferenca,
        CASE
            WHEN c.quantidade_contada IS NULL THEN 'Sem contagem registrada'
            WHEN c.quantidade_contada < s.saldo_inicial + s.movimento_liquido THEN 'Falta'
            WHEN c.quantidade_contada > s.saldo_inicial + s.movimento_liquido THEN 'Sobra'
            ELSE 'Conforme'
        END AS classificacao
    FROM saldos AS s
    JOIN materiais AS m ON m.id = s.material_id
    JOIN depositos AS d ON d.id = s.deposito_id
    LEFT JOIN contagens_fisicas AS c
        ON c.material_id = s.material_id AND c.deposito_id = s.deposito_id
)
SELECT * FROM conciliacao WHERE material_id = 1 AND deposito_id = 1;

-- 7. Dois casos selecionados intencionalmente no Depósito Norte
WITH saldos AS (
    SELECT
        s.material_id,
        s.deposito_id,
        s.quantidade AS saldo_inicial,
        COALESCE(SUM(CASE WHEN v.tipo = 'ENTRADA' THEN v.quantidade ELSE -v.quantidade END), 0) AS movimento_liquido
    FROM saldos_iniciais AS s
    LEFT JOIN movimentacoes AS v
        ON v.material_id = s.material_id
       AND v.deposito_id = s.deposito_id
       AND v.registrado_em >= s.data_base
       AND v.registrado_em <= '2026-09-30 18:00:00'
    GROUP BY s.material_id, s.deposito_id, s.quantidade
),
conciliacao AS (
    SELECT
        s.material_id, m.sku, s.deposito_id, d.nome AS deposito,
        s.saldo_inicial, s.movimento_liquido,
        s.saldo_inicial + s.movimento_liquido AS saldo_esperado,
        c.quantidade_contada, c.folha,
        c.quantidade_contada - (s.saldo_inicial + s.movimento_liquido) AS diferenca,
        CASE
            WHEN c.quantidade_contada IS NULL THEN 'Sem contagem registrada'
            WHEN c.quantidade_contada < s.saldo_inicial + s.movimento_liquido THEN 'Falta'
            WHEN c.quantidade_contada > s.saldo_inicial + s.movimento_liquido THEN 'Sobra'
            ELSE 'Conforme'
        END AS classificacao
    FROM saldos AS s
    JOIN materiais AS m ON m.id = s.material_id
    JOIN depositos AS d ON d.id = s.deposito_id
    LEFT JOIN contagens_fisicas AS c
        ON c.material_id = s.material_id AND c.deposito_id = s.deposito_id
)
SELECT * FROM conciliacao
WHERE deposito_id = 1 AND material_id IN (5, 11)
ORDER BY material_id;

-- 8. Movimentos dos casos para conferir quantidade e corte
SELECT documento, material_id, deposito_id, tipo, quantidade, ocorrido_em, registrado_em,
    CASE WHEN registrado_em <= '2026-09-30 18:00:00' THEN 'Incluído' ELSE 'Fora do corte' END AS tratamento
FROM movimentacoes
WHERE deposito_id = 1 AND material_id IN (5, 11)
ORDER BY material_id, registrado_em, id;