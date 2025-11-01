-- ============================================================================
-- SOLUÇÃO PARA COMPRESSÃO E ATIVIDADES RECENTES
-- ============================================================================

SET search_path = supervisorio, public;

-- 1. Criar view para atividades recentes (apenas mudanças significativas)
CREATE OR REPLACE VIEW v_atividades_recentes AS
SELECT 
    lr.leitura_id,
    e.nome as elemento,
    lr.variavel,
    lr.valor,
    lr.unidade,
    lr.datetime,
    lr.fonte,
    LAG(lr.valor) OVER (PARTITION BY lr.elemento_id, lr.variavel ORDER BY lr.datetime) as valor_anterior,
    LAG(lr.datetime) OVER (PARTITION BY lr.elemento_id, lr.variavel ORDER BY lr.datetime) as datetime_anterior
FROM leituras_raw lr
JOIN elemento e ON e.id = lr.elemento_id
WHERE lr.datetime >= NOW() - INTERVAL '24 hours'  -- Últimas 24h
ORDER BY lr.datetime DESC;

COMMENT ON VIEW v_atividades_recentes IS 
'Atividades recentes com contexto de mudança (valor anterior)';

-- 2. Criar view filtrada (apenas mudanças significativas)
CREATE OR REPLACE VIEW v_atividades_mudancas AS
SELECT 
    elemento,
    variavel,
    valor,
    unidade,
    datetime,
    valor_anterior,
    datetime_anterior,
    ABS(valor - COALESCE(valor_anterior, 0)) as delta,
    EXTRACT(EPOCH FROM (datetime - COALESCE(datetime_anterior, datetime)))/60 as minutos_desde_anterior
FROM v_atividades_recentes
WHERE 
    valor_anterior IS NULL  -- Primeira leitura
    OR ABS(valor - valor_anterior) >= 1.0  -- Mudança significativa (>= 1 unidade)
ORDER BY datetime DESC
LIMIT 50;

COMMENT ON VIEW v_atividades_mudancas IS 
'Apenas atividades com mudanças significativas (>= 1 unidade)';

-- 3. Função para forçar processamento de todas as leituras pendentes
CREATE OR REPLACE FUNCTION force_process_all_pending()
RETURNS TABLE(sensor_id TEXT, leituras_processadas INT, sucesso BOOLEAN) 
LANGUAGE plpgsql AS $$
DECLARE
    sensor_rec RECORD;
    count_processed INT;
BEGIN
    -- Para cada sensor com leituras pendentes
    FOR sensor_rec IN 
        SELECT DISTINCT lr.sensor_id
        FROM supervisorio.leituras_raw lr
        WHERE lr.processed = FALSE
    LOOP
        BEGIN
            -- Processar sensor
            PERFORM supervisorio.proc_process_sensor_window(sensor_rec.sensor_id);
            
            -- Contar quantas foram marcadas como processadas
            SELECT COUNT(*) INTO count_processed
            FROM supervisorio.leituras_raw
            WHERE supervisorio.leituras_raw.sensor_id = sensor_rec.sensor_id
              AND processed = TRUE;
            
            -- Retornar resultado
            sensor_id := sensor_rec.sensor_id;
            leituras_processadas := count_processed;
            sucesso := TRUE;
            RETURN NEXT;
            
        EXCEPTION WHEN OTHERS THEN
            sensor_id := sensor_rec.sensor_id;
            leituras_processadas := 0;
            sucesso := FALSE;
            RETURN NEXT;
        END;
    END LOOP;
END;
$$;

COMMENT ON FUNCTION force_process_all_pending() IS 
'Força processamento de todas as leituras pendentes de todos os sensores';

-- 4. Procedure para limpar leituras antigas (manutenção)
CREATE OR REPLACE PROCEDURE cleanup_old_raw_readings(dias_manter INT DEFAULT 30)
LANGUAGE plpgsql AS $$
DECLARE
    deleted_count INT;
BEGIN
    -- Deletar leituras RAW antigas JÁ PROCESSADAS
    DELETE FROM leituras_raw
    WHERE processed = TRUE
      AND datetime < NOW() - (dias_manter || ' days')::INTERVAL;
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    
    RAISE NOTICE 'Deletadas % leituras RAW antigas (>% dias e já processadas)', 
                 deleted_count, dias_manter;
END;
$$;

COMMENT ON PROCEDURE cleanup_old_raw_readings(INT) IS 
'Remove leituras RAW antigas que já foram processadas (padrão: 30 dias)';

-- ============================================================================
-- EXEMPLOS DE USO
-- ============================================================================

-- Ver atividades recentes (últimas 20 mudanças significativas)
-- SELECT * FROM v_atividades_mudancas LIMIT 20;

-- Forçar processamento de todas as leituras pendentes
-- SELECT * FROM force_process_all_pending();

-- Limpar leituras antigas (manter últimos 30 dias)
-- CALL cleanup_old_raw_readings(30);

-- Ver status de processamento
-- SELECT 
--     sensor_id,
--     COUNT(*) FILTER (WHERE processed = FALSE) as pendentes,
--     COUNT(*) FILTER (WHERE processed = TRUE) as processadas
-- FROM leituras_raw
-- GROUP BY sensor_id;
