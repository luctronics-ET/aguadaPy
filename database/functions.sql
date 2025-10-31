-- ===========================================================
-- FUNÇÕES PL/pgSQL PARA PROCESSAMENTO INTELIGENTE
-- Sistema Supervisório Hídrico IoT
-- ===========================================================

SET search_path = supervisorio;

-- ===========================================================
-- 1. FUNÇÃO DE PROCESSAMENTO DE JANELA DE SENSOR
-- Calcula mediana, aplica deadband e decide se cria novo registro
-- ou estende o anterior
-- ===========================================================

CREATE OR REPLACE FUNCTION proc_process_sensor_window(p_sensor_id TEXT)
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
  rec RECORD;
  v_elemento_id INT;
  v_variavel TEXT;
  cfg RECORD;
  v_window INT := 11;
  v_deadband DECIMAL := 2.0;
  v_stability_stddev DECIMAL := 0.5;
  median_val DECIMAL;
  stddev_val DECIMAL;
  min_val DECIMAL;
  max_val DECIMAL;
  count_val INT;
  last_proc RECORD;
  t_start TIMESTAMPTZ;
  t_end TIMESTAMPTZ := NOW();
BEGIN
  -- Buscar informações do sensor
  SELECT s.elemento_id, e.elemento_id as ativo_id
  INTO rec
  FROM sensores s
  JOIN elemento e ON s.elemento_id = e.id
  WHERE s.sensor_id = p_sensor_id;
  
  IF NOT FOUND THEN
    RAISE NOTICE 'Sensor % não encontrado', p_sensor_id;
    RETURN;
  END IF;
  
  v_elemento_id := rec.elemento_id;

  -- Buscar configuração do ativo
  SELECT ac.* INTO cfg
  FROM ativo_configs ac
  JOIN elemento e ON e.elemento_id = ac.ativo_id
  WHERE e.id = v_elemento_id;
  
  IF FOUND THEN
    IF cfg.window_size IS NOT NULL THEN v_window := cfg.window_size; END IF;
    IF cfg.deadband IS NOT NULL THEN v_deadband := cfg.deadband; END IF;
    IF cfg.stability_stddev IS NOT NULL THEN v_stability_stddev := cfg.stability_stddev; END IF;
  END IF;

  -- Identificar variável predominante não processada
  SELECT variavel INTO v_variavel
  FROM leituras_raw
  WHERE sensor_id = p_sensor_id AND processed = FALSE
  ORDER BY datetime DESC
  LIMIT 1;

  IF v_variavel IS NULL THEN
    RETURN;
  END IF;

  -- Calcular estatísticas das últimas N leituras não processadas
  WITH sel AS (
    SELECT valor, datetime
    FROM leituras_raw
    WHERE sensor_id = p_sensor_id
      AND variavel = v_variavel
      AND processed = FALSE
    ORDER BY datetime DESC
    LIMIT v_window
  )
  SELECT
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY valor) as median,
    STDDEV_POP(valor) as stddev,
    MIN(valor) as min_v,
    MAX(valor) as max_v,
    COUNT(*) as cnt,
    MIN(datetime) as t_first,
    MAX(datetime) as t_last
  INTO median_val, stddev_val, min_val, max_val, count_val, t_start, t_end
  FROM sel;

  -- Se não há leituras suficientes, retornar
  IF count_val < 1 THEN
    RETURN;
  END IF;

  -- Buscar último registro processado para o mesmo elemento/variável
  SELECT * INTO last_proc
  FROM leituras_processadas
  WHERE elemento_id = v_elemento_id 
    AND variavel = v_variavel
  ORDER BY data_fim DESC
  LIMIT 1;

  -- Decidir: estender registro anterior ou criar novo
  IF FOUND AND 
     ABS(median_val - last_proc.valor) <= v_deadband AND 
     (stddev_val IS NULL OR stddev_val <= v_stability_stddev) THEN
    
    -- ESTÁVEL: apenas estender o intervalo
    UPDATE leituras_processadas
    SET 
      data_fim = GREATEST(data_fim, t_end),
      variacao = LEAST(variacao, ABS(median_val - last_proc.valor)),
      n_amostras = n_amostras + count_val,
      meta = JSONB_BUILD_OBJECT(
        'min', LEAST(min_val, (meta->>'min')::DECIMAL),
        'max', GREATEST(max_val, (meta->>'max')::DECIMAL),
        'stddev', stddev_val,
        'ultima_mediana', median_val
      )
    WHERE proc_id = last_proc.proc_id;
    
    RAISE NOTICE 'Sensor %: estendido intervalo estável (mediana=%, stddev=%)', 
                  p_sensor_id, median_val, stddev_val;
  ELSE
    -- MUDANÇA SIGNIFICATIVA: criar novo registro
    INSERT INTO leituras_processadas (
      elemento_id,
      variavel,
      valor,
      unidade,
      criterio,
      variacao,
      stddev,
      min_valor,
      max_valor,
      n_amostras,
      data_inicio,
      data_fim,
      fonte,
      autor,
      meta
    ) VALUES (
      v_elemento_id,
      v_variavel,
      median_val,
      (SELECT unidade FROM sensores WHERE sensor_id = p_sensor_id),
      FORMAT('window=%s deadband=%s stddev_max=%s', v_window, v_deadband, v_stability_stddev),
      CASE WHEN last_proc IS NULL THEN NULL ELSE ABS(median_val - last_proc.valor) END,
      stddev_val,
      min_val,
      max_val,
      count_val,
      t_start,
      t_end,
      'sistema',
      'proc_process_sensor_window',
      JSONB_BUILD_OBJECT(
        'min', min_val,
        'max', max_val,
        'stddev', stddev_val,
        'sensor_id', p_sensor_id
      )
    );
    
    RAISE NOTICE 'Sensor %: novo registro processado (mediana=%, variação=%)', 
                  p_sensor_id, median_val, ABS(median_val - COALESCE(last_proc.valor, median_val));
  END IF;

  -- Marcar leituras como processadas
  UPDATE leituras_raw
  SET processed = TRUE
  WHERE sensor_id = p_sensor_id
    AND variavel = v_variavel
    AND processed = FALSE
    AND datetime BETWEEN t_start AND t_end;

  RETURN;
END;
$$;

COMMENT ON FUNCTION proc_process_sensor_window IS 
'Processa janela de leituras de um sensor: calcula mediana, aplica deadband, estende ou cria registro processado';

-- ===========================================================
-- 2. FUNÇÃO DE DETECÇÃO DE EVENTOS
-- Analisa leituras processadas e identifica eventos
-- ===========================================================

CREATE OR REPLACE FUNCTION detectar_eventos(p_elemento_id INT)
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
  r_atual RECORD;
  r_anterior RECORD;
  delta_volume DECIMAL;
  delta_tempo INTERVAL;
  taxa_variacao DECIMAL;
  bomba_estado TEXT;
  valvula_estado TEXT;
BEGIN
  -- Buscar últimas 2 leituras processadas
  SELECT * INTO r_atual
  FROM leituras_processadas
  WHERE elemento_id = p_elemento_id 
    AND variavel = 'nivel_cm'
  ORDER BY data_fim DESC
  LIMIT 1;
  
  SELECT * INTO r_anterior
  FROM leituras_processadas
  WHERE elemento_id = p_elemento_id 
    AND variavel = 'nivel_cm'
    AND proc_id < r_atual.proc_id
  ORDER BY data_fim DESC
  LIMIT 1;
  
  IF NOT FOUND OR r_anterior IS NULL THEN
    RETURN;
  END IF;
  
  -- Calcular variação
  delta_volume := r_atual.valor - r_anterior.valor;
  delta_tempo := r_atual.data_fim - r_anterior.data_fim;
  taxa_variacao := delta_volume / (EXTRACT(EPOCH FROM delta_tempo) / 3600); -- cm/h
  
  -- EVENTO: ABASTECIMENTO
  -- Condição: delta positivo grande + bomba ligada + válvula aberta
  IF delta_volume > 10 THEN
    -- Verificar estado de bombas e válvulas (simplificado)
    INSERT INTO eventos (
      tipo,
      elemento_id,
      detalhe,
      causa_provavel,
      nivel_confianca,
      detectado_por,
      datetime_inicio,
      datetime_fim,
      severidade
    ) VALUES (
      'abastecimento',
      p_elemento_id,
      JSONB_BUILD_OBJECT(
        'delta_cm', delta_volume,
        'taxa_cm_h', taxa_variacao,
        'valor_final', r_atual.valor
      ),
      'Aumento significativo de nível',
      0.85,
      'detectar_eventos',
      r_anterior.data_fim,
      r_atual.data_fim,
      'info'
    );
    
    RAISE NOTICE 'Evento ABASTECIMENTO detectado: elemento_id=%, delta=%cm', p_elemento_id, delta_volume;
  END IF;
  
  -- EVENTO: VAZAMENTO
  -- Condição: queda lenta contínua sem bombeamento
  IF delta_volume < -5 AND taxa_variacao < -2 THEN
    INSERT INTO eventos (
      tipo,
      elemento_id,
      detalhe,
      causa_provavel,
      nivel_confianca,
      detectado_por,
      datetime_inicio,
      datetime_fim,
      severidade
    ) VALUES (
      'vazamento_suspeito',
      p_elemento_id,
      JSONB_BUILD_OBJECT(
        'delta_cm', delta_volume,
        'taxa_cm_h', taxa_variacao,
        'valor_final', r_atual.valor
      ),
      'Queda lenta e contínua de nível sem bombeamento',
      0.70,
      'detectar_eventos',
      r_anterior.data_fim,
      r_atual.data_fim,
      'alerta'
    );
    
    RAISE NOTICE 'Evento VAZAMENTO detectado: elemento_id=%, taxa=%cm/h', p_elemento_id, taxa_variacao;
  END IF;
  
  -- EVENTO: CONSUMO NORMAL
  IF delta_volume < -1 AND delta_volume > -5 THEN
    INSERT INTO eventos (
      tipo,
      elemento_id,
      detalhe,
      causa_provavel,
      nivel_confianca,
      detectado_por,
      datetime_inicio,
      datetime_fim,
      severidade
    ) VALUES (
      'consumo',
      p_elemento_id,
      JSONB_BUILD_OBJECT(
        'delta_cm', delta_volume,
        'taxa_cm_h', taxa_variacao
      ),
      'Consumo normal de água',
      0.90,
      'detectar_eventos',
      r_anterior.data_fim,
      r_atual.data_fim,
      'info'
    );
  END IF;
  
  RETURN;
END;
$$;

COMMENT ON FUNCTION detectar_eventos IS 
'Detecta eventos automáticos (abastecimento, vazamento, consumo) baseado em variações de nível';

-- ===========================================================
-- 3. FUNÇÃO DE DETECÇÃO DE ANOMALIAS
-- ===========================================================

CREATE OR REPLACE FUNCTION detectar_anomalias(p_sensor_id TEXT)
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
  leituras_recentes INT;
  stddev_recente DECIMAL;
  stddev_historico DECIMAL;
  sensor_rec RECORD;
BEGIN
  -- Buscar sensor
  SELECT * INTO sensor_rec FROM sensores WHERE sensor_id = p_sensor_id;
  
  IF NOT FOUND THEN
    RETURN;
  END IF;
  
  -- Verificar ruído excessivo
  SELECT STDDEV(valor), COUNT(*)
  INTO stddev_recente, leituras_recentes
  FROM leituras_raw
  WHERE sensor_id = p_sensor_id
    AND datetime > NOW() - INTERVAL '1 hour'
    AND processed = FALSE;
  
  -- Comparar com desvio padrão histórico
  SELECT AVG(stddev)
  INTO stddev_historico
  FROM leituras_processadas
  WHERE elemento_id = sensor_rec.elemento_id
    AND data_fim > NOW() - INTERVAL '7 days'
    AND stddev IS NOT NULL;
  
  -- Se ruído atual for 3x maior que histórico
  IF stddev_recente > (3 * COALESCE(stddev_historico, 1.0)) THEN
    INSERT INTO anomalias (
      tipo,
      elemento_id,
      descricao,
      nivel_alerta,
      inicio,
      detectado_por
    ) VALUES (
      'sensor_ruidoso',
      sensor_rec.elemento_id,
      FORMAT('Sensor %s apresenta ruído excessivo (stddev=%.2f, esperado=%.2f)', 
             p_sensor_id, stddev_recente, stddev_historico),
      'moderado',
      NOW(),
      'detectar_anomalias'
    );
    
    -- Atualizar estado do sensor
    UPDATE sensores
    SET estado_operacional = 'falha'
    WHERE sensor_id = p_sensor_id;
    
    RAISE WARNING 'ANOMALIA: Sensor % com ruído excessivo', p_sensor_id;
  END IF;
  
  RETURN;
END;
$$;

COMMENT ON FUNCTION detectar_anomalias IS 
'Detecta anomalias em sensores (ruído, valores fora do range, falta de leitura)';

-- ===========================================================
-- 4. FUNÇÃO DE CÁLCULO DE CONSUMO DIÁRIO
-- ===========================================================

CREATE OR REPLACE FUNCTION calcular_consumo_diario(p_data DATE)
RETURNS TABLE(
  elemento_id INT,
  nome_elemento TEXT,
  consumo_litros DECIMAL,
  abastecimento_litros DECIMAL,
  perda_litros DECIMAL
) LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY
  WITH eventos_dia AS (
    SELECT 
      e.elemento_id,
      el.nome,
      SUM(CASE WHEN e.tipo = 'consumo' THEN 
        ABS((e.detalhe->>'delta_cm')::DECIMAL) * 
        (SELECT capacidade_litros FROM elemento WHERE id = e.elemento_id) / 100
      ELSE 0 END) as consumo,
      SUM(CASE WHEN e.tipo = 'abastecimento' THEN 
        (e.detalhe->>'delta_cm')::DECIMAL * 
        (SELECT capacidade_litros FROM elemento WHERE id = e.elemento_id) / 100
      ELSE 0 END) as abastecimento,
      SUM(CASE WHEN e.tipo = 'vazamento_suspeito' THEN 
        ABS((e.detalhe->>'delta_cm')::DECIMAL) * 
        (SELECT capacidade_litros FROM elemento WHERE id = e.elemento_id) / 100
      ELSE 0 END) as perda
    FROM eventos e
    JOIN elemento el ON e.elemento_id = el.id
    WHERE DATE(e.datetime_inicio) = p_data
      AND el.tipo = 'reservatorio'
    GROUP BY e.elemento_id, el.nome
  )
  SELECT 
    eventos_dia.elemento_id,
    eventos_dia.nome,
    eventos_dia.consumo,
    eventos_dia.abastecimento,
    eventos_dia.perda
  FROM eventos_dia;
END;
$$;

COMMENT ON FUNCTION calcular_consumo_diario IS 
'Calcula consumo, abastecimento e perdas por reservatório em um dia específico';

-- ===========================================================
-- 5. FUNÇÃO DE GERAÇÃO DE RELATÓRIO DIÁRIO
-- Executada automaticamente às 06:00
-- ===========================================================

CREATE OR REPLACE FUNCTION gerar_relatorio_diario()
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
  v_data DATE := CURRENT_DATE - INTERVAL '1 day';
  v_consumo_total DECIMAL := 0;
  v_abastecimento_total DECIMAL := 0;
  v_perda_total DECIMAL := 0;
  v_eventos_count INT;
  v_anomalias_count INT;
  v_alertas_criticos INT;
  v_resumo TEXT;
  v_detalhes JSONB;
BEGIN
  -- Calcular totais
  SELECT 
    SUM(consumo_litros),
    SUM(abastecimento_litros),
    SUM(perda_litros)
  INTO v_consumo_total, v_abastecimento_total, v_perda_total
  FROM calcular_consumo_diario(v_data);
  
  -- Contar eventos
  SELECT COUNT(*) INTO v_eventos_count
  FROM eventos
  WHERE DATE(datetime_inicio) = v_data;
  
  -- Contar anomalias
  SELECT COUNT(*) INTO v_anomalias_count
  FROM anomalias
  WHERE DATE(inicio) = v_data;
  
  -- Contar alertas críticos
  SELECT COUNT(*) INTO v_alertas_criticos
  FROM eventos
  WHERE DATE(datetime_inicio) = v_data
    AND severidade = 'critico';
  
  -- Montar resumo
  v_resumo := FORMAT(
    'Relatório do dia %s: Consumo total de %.2f litros, Abastecimento de %.2f litros. %s eventos registrados.',
    v_data, 
    v_consumo_total, 
    v_abastecimento_total,
    v_eventos_count
  );
  
  -- Detalhes em JSON
  SELECT JSONB_AGG(
    JSONB_BUILD_OBJECT(
      'elemento', nome_elemento,
      'consumo_l', consumo_litros,
      'abastecimento_l', abastecimento_litros,
      'perda_l', perda_litros
    )
  ) INTO v_detalhes
  FROM calcular_consumo_diario(v_data);
  
  -- Inserir relatório
  INSERT INTO relatorio_diario (
    data,
    volume_consumido_total_l,
    volume_abastecido_total_l,
    volume_perdido_l,
    eventos_registrados,
    anomalias_detectadas,
    alertas_criticos,
    resumo,
    detalhes
  ) VALUES (
    v_data,
    v_consumo_total,
    v_abastecimento_total,
    v_perda_total,
    v_eventos_count,
    v_anomalias_count,
    v_alertas_criticos,
    v_resumo,
    v_detalhes
  )
  ON CONFLICT (data) DO UPDATE
  SET 
    volume_consumido_total_l = EXCLUDED.volume_consumido_total_l,
    volume_abastecido_total_l = EXCLUDED.volume_abastecido_total_l,
    volume_perdido_l = EXCLUDED.volume_perdido_l,
    eventos_registrados = EXCLUDED.eventos_registrados,
    anomalias_detectadas = EXCLUDED.anomalias_detectadas,
    alertas_criticos = EXCLUDED.alertas_criticos,
    resumo = EXCLUDED.resumo,
    detalhes = EXCLUDED.detalhes,
    gerado_em = NOW();
  
  RAISE NOTICE 'Relatório diário gerado para %', v_data;
  
  -- Log do evento
  INSERT INTO log_evento (tipo, nivel, descricao, dados)
  VALUES (
    'relatorio_gerado',
    'info',
    FORMAT('Relatório diário gerado para %s', v_data),
    JSONB_BUILD_OBJECT('data', v_data, 'eventos', v_eventos_count)
  );
END;
$$;

COMMENT ON FUNCTION gerar_relatorio_diario IS 
'Gera relatório diário consolidado (executado automaticamente às 06:00)';

-- ===========================================================
-- 6. FUNÇÃO UTILITÁRIA: REPROCESSAR HISTÓRICO
-- ===========================================================

CREATE OR REPLACE FUNCTION proc_reprocessar_elemento(p_elemento_id INT)
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
  r RECORD;
BEGIN
  -- Marcar todas leituras do elemento como não processadas
  UPDATE leituras_raw 
  SET processed = FALSE 
  WHERE elemento_id = p_elemento_id;
  
  -- Limpar leituras processadas (opcional - comentar se quiser manter histórico)
  -- DELETE FROM leituras_processadas WHERE elemento_id = p_elemento_id;
  
  -- Processar cada sensor do elemento
  FOR r IN 
    SELECT sensor_id 
    FROM sensores 
    WHERE elemento_id = p_elemento_id 
      AND estado_operacional = 'ativo'
  LOOP
    PERFORM proc_process_sensor_window(r.sensor_id);
  END LOOP;
  
  RAISE NOTICE 'Elemento % reprocessado', p_elemento_id;
END;
$$;

COMMENT ON FUNCTION proc_reprocessar_elemento IS 
'Reprocessa todo o histórico de leituras de um elemento (útil após mudança de configuração)';

-- ===========================================================
-- 7. FUNÇÃO DE LIMPEZA DE DADOS ANTIGOS
-- ===========================================================

CREATE OR REPLACE FUNCTION limpar_dados_antigos(p_dias INT DEFAULT 90)
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
  v_deleted INT;
BEGIN
  -- Remover leituras RAW antigas (já processadas)
  DELETE FROM leituras_raw
  WHERE datetime < NOW() - (p_dias || ' days')::INTERVAL
    AND processed = TRUE;
  
  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  
  RAISE NOTICE 'Removidas % leituras RAW antigas (> % dias)', v_deleted, p_dias;
  
  -- Log
  INSERT INTO log_evento (tipo, nivel, descricao, dados)
  VALUES (
    'limpeza_dados',
    'info',
    FORMAT('Limpeza automática de dados antigos (> %s dias)', p_dias),
    JSONB_BUILD_OBJECT('linhas_removidas', v_deleted)
  );
END;
$$;

COMMENT ON FUNCTION limpar_dados_antigos IS 
'Remove leituras RAW antigas já processadas (padrão: 90 dias)';

-- ===========================================================
-- FIM DAS FUNÇÕES
-- ===========================================================
