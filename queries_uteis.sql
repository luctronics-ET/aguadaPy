-- Queries úteis para monitoramento do sistema aguadaPy

-- 1. Ver últimas 10 leituras RAW
SELECT 
    lr.leitura_id,
    s.value_id,
    e.nome_elemento,
    lr.valor AS nivel_cm,
    lr.rssi,
    lr.mac_address,
    lr.timestamp
FROM supervisorio.leituras_raw lr
JOIN supervisorio.sensores s ON lr.sensor_id = s.sensor_id
JOIN supervisorio.elemento e ON s.elemento_id = e.elemento_id
ORDER BY lr.timestamp DESC
LIMIT 10;

-- 2. Ver leituras PROCESSADAS (comprimidas)
SELECT 
    lp.leitura_proc_id,
    s.value_id,
    e.nome_elemento,
    lp.valor_mediana AS nivel_cm,
    lp.num_amostras,
    lp.timestamp_inicio,
    lp.timestamp_fim,
    EXTRACT(EPOCH FROM (lp.timestamp_fim - lp.timestamp_inicio))/60 AS duracao_minutos
FROM supervisorio.leituras_processadas lp
JOIN supervisorio.sensores s ON lp.sensor_id = s.sensor_id
JOIN supervisorio.elemento e ON s.elemento_id = e.elemento_id
ORDER BY lp.timestamp_fim DESC
LIMIT 10;

-- 3. Eventos detectados (vazamentos, abastecimentos)
SELECT 
    ev.evento_id,
    e.nome_elemento,
    ev.tipo_evento,
    ev.variacao_nivel,
    ev.taxa_variacao,
    ev.volume_estimado,
    ev.severidade,
    ev.resolvido,
    ev.timestamp_inicio
FROM supervisorio.eventos ev
JOIN supervisorio.elemento e ON ev.elemento_id = e.elemento_id
ORDER BY ev.timestamp_inicio DESC
LIMIT 10;

-- 4. Status atual de todos os reservatórios
SELECT 
    e.nome_elemento,
    e.capacidade,
    (
        SELECT lp.valor_mediana
        FROM supervisorio.leituras_processadas lp
        JOIN supervisorio.sensores s ON lp.sensor_id = s.sensor_id
        WHERE s.elemento_id = e.elemento_id
          AND s.tipo_sensor = 'NIVEL'
        ORDER BY lp.timestamp_fim DESC
        LIMIT 1
    ) AS nivel_atual_cm,
    e.status
FROM supervisorio.elemento e
WHERE e.tipo = 'RESERVATORIO'
ORDER BY e.nome_elemento;

-- 5. Estatísticas de sensor (últimas 24h)
SELECT 
    s.value_id,
    e.nome_elemento,
    COUNT(*) as total_leituras,
    AVG(lr.valor) as media,
    MIN(lr.valor) as minimo,
    MAX(lr.valor) as maximo,
    STDDEV(lr.valor) as desvio_padrao,
    MAX(lr.timestamp) as ultima_leitura
FROM supervisorio.leituras_raw lr
JOIN supervisorio.sensores s ON lr.sensor_id = s.sensor_id
JOIN supervisorio.elemento e ON s.elemento_id = e.elemento_id
WHERE lr.timestamp > NOW() - INTERVAL '24 hours'
GROUP BY s.value_id, e.nome_elemento
ORDER BY s.value_id;

-- 6. Calibrações recentes
SELECT 
    c.calibracao_id,
    s.value_id,
    e.nome_elemento,
    c.valor_lido,
    c.valor_real,
    c.diferenca,
    c.timestamp,
    c.observacoes
FROM supervisorio.calibracoes c
JOIN supervisorio.sensores s ON c.sensor_id = s.sensor_id
JOIN supervisorio.elemento e ON s.elemento_id = e.elemento_id
ORDER BY c.timestamp DESC
LIMIT 10;

-- 7. Taxa de compressão (redução de dados)
SELECT 
    COUNT(*) FILTER (WHERE DATE(timestamp) = CURRENT_DATE) as leituras_raw_hoje,
    (
        SELECT COUNT(*) 
        FROM supervisorio.leituras_processadas 
        WHERE DATE(timestamp_fim) = CURRENT_DATE
    ) as leituras_processadas_hoje,
    ROUND(
        100.0 * (1.0 - (
            SELECT COUNT(*) 
            FROM supervisorio.leituras_processadas 
            WHERE DATE(timestamp_fim) = CURRENT_DATE
        )::DECIMAL / NULLIF(COUNT(*) FILTER (WHERE DATE(timestamp) = CURRENT_DATE), 0)
        ), 2
    ) || '%' as taxa_compressao
FROM supervisorio.leituras_raw;

-- 8. Listar todos os sensores cadastrados
SELECT 
    s.sensor_id,
    s.value_id,
    e.nome_elemento,
    s.tipo_sensor,
    s.unidade_medida,
    s.valor_min,
    s.valor_max,
    s.status,
    s.ultima_calibracao
FROM supervisorio.sensores s
JOIN supervisorio.elemento e ON s.elemento_id = e.elemento_id
ORDER BY s.value_id;

-- 9. Verificar triggers ativos
SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    action_statement
FROM information_schema.triggers
WHERE trigger_schema = 'supervisorio'
ORDER BY event_object_table, trigger_name;

-- 10. Tamanho das tabelas
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size,
    pg_total_relation_size(schemaname||'.'||tablename) AS size_bytes
FROM pg_tables
WHERE schemaname = 'supervisorio'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
