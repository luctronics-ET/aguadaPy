-- ============================================================================
-- PROCESSAMENTO MANUAL SIMPLIFICADO DE LEITURAS
-- Solução direta sem depender das funções complexas com bugs de schema
-- ============================================================================

SET search_path = supervisorio, public;

-- PASSO 1: Processar leituras de NODE-01
WITH stats AS (
    SELECT 
        'SEN_NODE01_NIVEL' as sensor_id,
        27 as elemento_id,
        'nivel' as variavel,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY valor) as median_valor,
        STDDEV(valor) as stddev_valor,
        MIN(valor) as min_valor,
        MAX(valor) as max_valor,
        COUNT(*) as n_amostras,
        MIN(datetime) as data_inicio,
        MAX(datetime) as data_fim,
        MAX(fonte) as fonte,
        MAX(unidade) as unidade
    FROM leituras_raw
    WHERE sensor_id = 'SEN_NODE01_NIVEL'
      AND variavel = 'nivel'
      AND processed = FALSE
)
INSERT INTO leituras_processadas (
    elemento_id,
    variavel,
    valor,
    unidade,
    criterio,
    stddev,
    min_valor,
    max_valor,
    n_amostras,
    data_inicio,
    data_fim,
    fonte
)
SELECT 
    elemento_id,
    variavel,
    median_valor,
    unidade,
    'mediana_manual',
    stddev_valor,
    min_valor,
    max_valor,
    n_amostras,
    data_inicio,
    data_fim,
    fonte
FROM stats
WHERE n_amostras > 0;

-- Marcar como processadas
UPDATE leituras_raw
SET processed = TRUE
WHERE sensor_id = 'SEN_NODE01_NIVEL'
  AND variavel = 'nivel'
  AND processed = FALSE;

-- PASSO 2: Processar leituras de NODE-03
WITH stats AS (
    SELECT 
        'SEN_NODE03_NIVEL' as sensor_id,
        28 as elemento_id,
        'nivel' as variavel,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY valor) as median_valor,
        STDDEV(valor) as stddev_valor,
        MIN(valor) as min_valor,
        MAX(valor) as max_valor,
        COUNT(*) as n_amostras,
        MIN(datetime) as data_inicio,
        MAX(datetime) as data_fim,
        MAX(fonte) as fonte,
        MAX(unidade) as unidade
    FROM leituras_raw
    WHERE sensor_id = 'SEN_NODE03_NIVEL'
      AND variavel = 'nivel'
      AND processed = FALSE
)
INSERT INTO leituras_processadas (
    elemento_id,
    variavel,
    valor,
    unidade,
    criterio,
    stddev,
    min_valor,
    max_valor,
    n_amostras,
    data_inicio,
    data_fim,
    fonte
)
SELECT 
    elemento_id,
    variavel,
    median_valor,
    unidade,
    'mediana_manual',
    stddev_valor,
    min_valor,
    max_valor,
    n_amostras,
    data_inicio,
    data_fim,
    fonte
FROM stats
WHERE n_amostras > 0;

-- Marcar como processadas
UPDATE leituras_raw
SET processed = TRUE
WHERE sensor_id = 'SEN_NODE03_NIVEL'
  AND variavel = 'nivel'
  AND processed = FALSE;

-- PASSO 3: Processar leituras de NODE-02
WITH stats AS (
    SELECT 
        'SEN_NODE02_NIVEL' as sensor_id,
        29 as elemento_id,
        'nivel' as variavel,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY valor) as median_valor,
        STDDEV(valor) as stddev_valor,
        MIN(valor) as min_valor,
        MAX(valor) as max_valor,
        COUNT(*) as n_amostras,
        MIN(datetime) as data_inicio,
        MAX(datetime) as data_fim,
        MAX(fonte) as fonte,
        MAX(unidade) as unidade
    FROM leituras_raw
    WHERE sensor_id = 'SEN_NODE02_NIVEL'
      AND variavel = 'nivel'
      AND processed = FALSE
)
INSERT INTO leituras_processadas (
    elemento_id,
    variavel,
    valor,
    unidade,
    criterio,
    stddev,
    min_valor,
    max_valor,
    n_amostras,
    data_inicio,
    data_fim,
    fonte
)
SELECT 
    elemento_id,
    variavel,
    median_valor,
    unidade,
    'mediana_manual',
    stddev_valor,
    min_valor,
    max_valor,
    n_amostras,
    data_inicio,
    data_fim,
    fonte
FROM stats
WHERE n_amostras > 0;

-- Marcar como processadas
UPDATE leituras_raw
SET processed = TRUE
WHERE sensor_id = 'SEN_NODE02_NIVEL'
  AND variavel = 'nivel'
  AND processed = FALSE;

-- Ver resultado
SELECT 
    'Leituras Processadas' as tipo,
    COUNT(*) as total
FROM leituras_processadas
UNION ALL
SELECT 
    'Leituras RAW Pendentes' as tipo,
    COUNT(*) as total
FROM leituras_raw
WHERE processed = FALSE;
