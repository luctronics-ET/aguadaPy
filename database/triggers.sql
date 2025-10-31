-- ===========================================================
-- TRIGGERS AUTOMÁTICOS
-- Sistema Supervisório Hídrico IoT
-- ===========================================================

SET search_path = supervisorio;

-- ===========================================================
-- 1. TRIGGER: PROCESSAR LEITURAS RAW AUTOMATICAMENTE
-- Acionado após inserção de nova leitura
-- ===========================================================

CREATE OR REPLACE FUNCTION trg_after_insert_leituras_raw()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  unread_count INT;
  cfg RECORD;
  v_window INT := 11;
  v_ativo_id TEXT;
BEGIN
  -- Buscar ativo_id do elemento
  SELECT e.elemento_id INTO v_ativo_id
  FROM supervisorio.elemento e
  WHERE e.id = NEW.elemento_id;
  
  -- Buscar configuração do ativo
  SELECT * INTO cfg 
  FROM supervisorio.ativo_configs 
  WHERE ativo_id = v_ativo_id;
  
  IF FOUND AND cfg.window_size IS NOT NULL THEN
    v_window := cfg.window_size;
  END IF;

  -- Contar leituras não processadas deste sensor
  SELECT COUNT(*) INTO unread_count
  FROM supervisorio.leituras_raw
  WHERE sensor_id = NEW.sensor_id 
    AND variavel = NEW.variavel
    AND processed = FALSE;

  -- Se atingiu o tamanho da janela, processar
  IF unread_count >= v_window THEN
    PERFORM proc_process_sensor_window(NEW.sensor_id);
    
    -- Detectar eventos após processamento
    PERFORM detectar_eventos(NEW.elemento_id);
    
    -- Detectar anomalias
    PERFORM detectar_anomalias(NEW.sensor_id);
  ELSE
    -- Enfileirar para processamento posterior
    INSERT INTO supervisorio.processing_queue(sensor_id, elemento_id, tipo_processamento)
    VALUES (NEW.sensor_id, NEW.elemento_id, 'compressao')
    ON CONFLICT DO NOTHING;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER after_insert_leituras_raw
AFTER INSERT ON leituras_raw
FOR EACH ROW
EXECUTE FUNCTION trg_after_insert_leituras_raw();

COMMENT ON TRIGGER after_insert_leituras_raw ON leituras_raw IS 
'Processa automaticamente leituras quando atinge tamanho da janela (window_size)';

-- ===========================================================
-- 2. TRIGGER: ATUALIZAR TIMESTAMP DE ELEMENTO
-- ===========================================================

CREATE OR REPLACE FUNCTION trg_update_elemento_timestamp()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.atualizado_em = NOW();
  RETURN NEW;
END;
$$;

CREATE TRIGGER update_elemento_timestamp
BEFORE UPDATE ON elemento
FOR EACH ROW
EXECUTE FUNCTION trg_update_elemento_timestamp();

-- ===========================================================
-- 3. TRIGGER: ATUALIZAR ESTADO DE ATUADOR
-- Registra mudanças de estado (ON/OFF, ABERTA/FECHADA)
-- ===========================================================

CREATE OR REPLACE FUNCTION trg_after_update_atuador()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  -- Se houve mudança de estado, registrar no histórico
  IF OLD.estado_atual != NEW.estado_atual THEN
    INSERT INTO supervisorio.estado_elemento (
      elemento_id,
      tipo_elemento,
      atributo,
      valor,
      origem,
      registrado_por,
      datahora
    ) VALUES (
      NEW.elemento_id,
      NEW.tipo,
      'estado',
      NEW.estado_atual,
      'sistema',
      'trigger_atuador',
      NOW()
    );
    
    -- Log
    INSERT INTO supervisorio.log_evento (tipo, nivel, descricao, elemento_id, dados)
    VALUES (
      'alteracao_estado',
      'info',
      FORMAT('%s %s mudou de estado: %s → %s', 
             INITCAP(NEW.tipo), 
             NEW.atuador_id, 
             OLD.estado_atual, 
             NEW.estado_atual),
      NEW.elemento_id,
      JSONB_BUILD_OBJECT(
        'atuador_id', NEW.atuador_id,
        'estado_anterior', OLD.estado_atual,
        'estado_novo', NEW.estado_atual,
        'tipo', NEW.tipo
      )
    );
  END IF;
  
  RETURN NEW;
END;
$$;

CREATE TRIGGER after_update_atuador
AFTER UPDATE ON atuadores
FOR EACH ROW
EXECUTE FUNCTION trg_after_update_atuador();

COMMENT ON TRIGGER after_update_atuador ON atuadores IS 
'Registra mudanças de estado de atuadores (bombas/válvulas) no histórico';

-- ===========================================================
-- 4. TRIGGER: VALIDAR LEITURAS RAW
-- Verifica se leitura está dentro do range do sensor
-- ===========================================================

CREATE OR REPLACE FUNCTION supervisorio.trg_validate_leitura_raw()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  sensor_rec RECORD;
BEGIN
  -- Buscar informações do sensor
  SELECT * INTO sensor_rec
  FROM supervisorio.sensores
  WHERE sensor_id = NEW.sensor_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Sensor % não encontrado', NEW.sensor_id;
  END IF;
  
  -- Validar range (se configurado)
  IF sensor_rec.range_min IS NOT NULL AND NEW.valor < sensor_rec.range_min THEN
    RAISE WARNING 'Leitura abaixo do mínimo: sensor=%, valor=%, min=%', 
                  NEW.sensor_id, NEW.valor, sensor_rec.range_min;
    
    INSERT INTO supervisorio.anomalias (
      tipo,
      elemento_id,
      descricao,
      nivel_alerta,
      inicio,
      detectado_por
    ) VALUES (
      'leitura_fora_range',
      sensor_rec.elemento_id,
      FORMAT('Sensor %s: leitura %.2f abaixo do mínimo %.2f', 
             NEW.sensor_id, NEW.valor, sensor_rec.range_min),
      'alto',
      NEW.datetime,
      'trigger_validate_leitura'
    );
  END IF;
  
  IF sensor_rec.range_max IS NOT NULL AND NEW.valor > sensor_rec.range_max THEN
    RAISE WARNING 'Leitura acima do máximo: sensor=%, valor=%, max=%', 
                  NEW.sensor_id, NEW.valor, sensor_rec.range_max;
    
    INSERT INTO supervisorio.anomalias (
      tipo,
      elemento_id,
      descricao,
      nivel_alerta,
      inicio,
      detectado_por
    ) VALUES (
      'leitura_fora_range',
      sensor_rec.elemento_id,
      FORMAT('Sensor %s: leitura %.2f acima do máximo %.2f', 
             NEW.sensor_id, NEW.valor, sensor_rec.range_max),
      'alto',
      NEW.datetime,
      'trigger_validate_leitura'
    );
  END IF;
  
  RETURN NEW;
END;
$$;

CREATE TRIGGER validate_leitura_raw
BEFORE INSERT ON supervisorio.leituras_raw
FOR EACH ROW
EXECUTE FUNCTION supervisorio.trg_validate_leitura_raw();

COMMENT ON TRIGGER validate_leitura_raw ON leituras_raw IS 
'Valida leituras antes de inserir (range, consistência)';

-- ===========================================================
-- 5. TRIGGER: ALERTAR NÍVEIS CRÍTICOS
-- ===========================================================

CREATE OR REPLACE FUNCTION trg_check_nivel_critico()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  elemento_rec RECORD;
  nivel_percent DECIMAL;
BEGIN
  -- Buscar elemento
  SELECT * INTO elemento_rec
  FROM supervisorio.elemento
  WHERE id = NEW.elemento_id
    AND tipo = 'reservatorio';
  
  IF NOT FOUND THEN
    RETURN NEW;
  END IF;
  
  -- Calcular percentual (assumindo que NEW.valor está em cm)
  nivel_percent := (NEW.valor / (elemento_rec.capacidade_litros / 100.0)) * 100;
  
  -- Verificar nível crítico baixo
  IF nivel_percent < 20 THEN
    INSERT INTO supervisorio.eventos (
      tipo,
      elemento_id,
      detalhe,
      causa_provavel,
      nivel_confianca,
      severidade,
      detectado_por,
      datetime_inicio
    ) VALUES (
      'nivel_critico_baixo',
      NEW.elemento_id,
      JSONB_BUILD_OBJECT(
        'nivel_percent', nivel_percent,
        'nivel_cm', NEW.valor
      ),
      'Reservatório com nível abaixo de 20%',
      1.0,
      'critico',
      'trigger_nivel_critico',
      NEW.data_fim
    );
    
    RAISE WARNING 'NÍVEL CRÍTICO: Reservatório % em %.1f%%', 
                  elemento_rec.nome, nivel_percent;
  END IF;
  
  -- Verificar nível crítico alto (overflow)
  IF nivel_percent > 95 THEN
    INSERT INTO supervisorio.eventos (
      tipo,
      elemento_id,
      detalhe,
      causa_provavel,
      nivel_confianca,
      severidade,
      detectado_por,
      datetime_inicio
    ) VALUES (
      'nivel_critico_alto',
      NEW.elemento_id,
      JSONB_BUILD_OBJECT(
        'nivel_percent', nivel_percent,
        'nivel_cm', NEW.valor
      ),
      'Reservatório próximo ao transbordamento',
      1.0,
      'alerta',
      'trigger_nivel_critico',
      NEW.data_fim
    );
    
    RAISE WARNING 'NÍVEL ALTO: Reservatório % em %.1f%%', 
                  elemento_rec.nome, nivel_percent;
  END IF;
  
  RETURN NEW;
END;
$$;

CREATE TRIGGER check_nivel_critico
AFTER INSERT OR UPDATE ON leituras_processadas
FOR EACH ROW
WHEN (NEW.variavel = 'nivel_cm')
EXECUTE FUNCTION trg_check_nivel_critico();

COMMENT ON TRIGGER check_nivel_critico ON leituras_processadas IS 
'Gera alertas quando níveis críticos (< 20% ou > 95%) são detectados';

-- ===========================================================
-- 6. TRIGGER: ATUALIZAR LEITURA ANTERIOR DE HIDRÔMETRO
-- ===========================================================

CREATE OR REPLACE FUNCTION trg_update_hidrometro_anterior()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  ultima_leitura RECORD;
BEGIN
  -- Buscar última leitura do mesmo hidrômetro
  SELECT leitura_m3, data_leitura
  INTO ultima_leitura
  FROM supervisorio.hidrometros
  WHERE identificador = NEW.identificador
    AND hidrometro_id != NEW.hidrometro_id
  ORDER BY data_leitura DESC
  LIMIT 1;
  
  IF FOUND THEN
    NEW.leitura_anterior_m3 := ultima_leitura.leitura_m3;
    NEW.data_leitura_anterior := ultima_leitura.data_leitura;
  END IF;
  
  RETURN NEW;
END;
$$;

CREATE TRIGGER update_hidrometro_anterior
BEFORE INSERT ON hidrometros
FOR EACH ROW
EXECUTE FUNCTION trg_update_hidrometro_anterior();

COMMENT ON TRIGGER update_hidrometro_anterior ON hidrometros IS 
'Preenche automaticamente leitura anterior para cálculo de consumo';

-- ===========================================================
-- 7. TRIGGER: LOG DE CALIBRAÇÕES
-- ===========================================================

CREATE OR REPLACE FUNCTION trg_after_calibracao()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  -- Atualizar sensor com novos valores de calibração
  UPDATE supervisorio.sensores
  SET 
    ultima_calibracao = NEW.datahora,
    fator_calibracao = COALESCE(NEW.fator_calibracao_novo, fator_calibracao),
    offset_calibracao = COALESCE(NEW.offset_calibracao_novo, offset_calibracao),
    proxima_calibracao = NEW.datahora::DATE + INTERVAL '3 months'
  WHERE sensor_id = NEW.sensor_id;
  
  -- Log
  INSERT INTO supervisorio.log_evento (tipo, nivel, descricao, usuario_id, dados)
  VALUES (
    'calibracao',
    'info',
    FORMAT('Sensor %s calibrado: diferença de %.2fcm', 
           NEW.sensor_id, NEW.diferenca),
    NEW.responsavel_usuario_id,
    JSONB_BUILD_OBJECT(
      'sensor_id', NEW.sensor_id,
      'diferenca', NEW.diferenca,
      'tipo', NEW.tipo
    )
  );
  
  RETURN NEW;
END;
$$;

CREATE TRIGGER after_calibracao
AFTER INSERT ON calibracoes
FOR EACH ROW
EXECUTE FUNCTION trg_after_calibracao();

COMMENT ON TRIGGER after_calibracao ON calibracoes IS 
'Atualiza sensor após calibração e registra log';

-- ===========================================================
-- 8. TRIGGER: NOTIFICAR EVENTOS CRÍTICOS (via NOTIFY)
-- Para integração com aplicações externas
-- ===========================================================

CREATE OR REPLACE FUNCTION trg_notify_evento_critico()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  payload JSON;
BEGIN
  IF NEW.severidade IN ('critico', 'alerta') THEN
    payload := JSON_BUILD_OBJECT(
      'evento_id', NEW.evento_id,
      'tipo', NEW.tipo,
      'severidade', NEW.severidade,
      'elemento_id', NEW.elemento_id,
      'datetime', NEW.datetime_inicio,
      'detalhe', NEW.detalhe
    );
    
    PERFORM PG_NOTIFY('evento_critico', payload::TEXT);
  END IF;
  
  RETURN NEW;
END;
$$;

CREATE TRIGGER notify_evento_critico
AFTER INSERT ON eventos
FOR EACH ROW
EXECUTE FUNCTION trg_notify_evento_critico();

COMMENT ON TRIGGER notify_evento_critico ON eventos IS 
'Envia notificação PostgreSQL para eventos críticos (LISTEN/NOTIFY pattern)';

-- ===========================================================
-- 9. TRIGGER: PREVENIR EXCLUSÃO DE LEITURAS PROCESSADAS
-- ===========================================================

CREATE OR REPLACE FUNCTION trg_prevent_delete_processadas()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'Exclusão de leituras processadas não permitida. Use arquivamento.';
  RETURN NULL;
END;
$$;

CREATE TRIGGER prevent_delete_processadas
BEFORE DELETE ON leituras_processadas
FOR EACH ROW
EXECUTE FUNCTION trg_prevent_delete_processadas();

COMMENT ON TRIGGER prevent_delete_processadas ON leituras_processadas IS 
'Previne exclusão acidental de dados processados (segurança)';

-- ===========================================================
-- 10. TRIGGER: CHECKSUM AUTOMÁTICO PARA LEITURAS RAW
-- ===========================================================

CREATE OR REPLACE FUNCTION trg_generate_checksum()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  -- Gerar checksum simples baseado nos dados principais
  NEW.checksum := MD5(
    CONCAT(
      NEW.sensor_id, '|',
      NEW.variavel, '|',
      NEW.valor::TEXT, '|',
      EXTRACT(EPOCH FROM NEW.datetime)::TEXT
    )
  );
  
  RETURN NEW;
END;
$$;

CREATE TRIGGER generate_checksum
BEFORE INSERT ON leituras_raw
FOR EACH ROW
EXECUTE FUNCTION trg_generate_checksum();

COMMENT ON TRIGGER generate_checksum ON leituras_raw IS 
'Gera checksum MD5 para integridade de dados';

-- ===========================================================
-- FIM DOS TRIGGERS
-- ===========================================================
