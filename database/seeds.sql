-- ===========================================================
-- DADOS DE EXEMPLO (SEEDS)
-- Sistema Supervisório Hídrico IoT
-- ===========================================================

SET search_path = supervisorio;

-- ===========================================================
-- 1. USUÁRIOS
-- ===========================================================

INSERT INTO usuarios (nome, email, login, senha_hash, papel, nivel_acesso, ativo) VALUES
('Administrador Sistema', 'admin@aguada.local', 'admin', '$2a$10$...hash...', 'admin', 'total', TRUE),
('João Silva', 'joao.silva@aguada.local', 'joao', '$2a$10$...hash...', 'operador', 'operacao', TRUE),
('Maria Santos', 'maria.santos@aguada.local', 'maria', '$2a$10$...hash...', 'visualizador', 'leitura', TRUE);

-- ===========================================================
-- 2. ELEMENTOS
-- ===========================================================

-- Reservatórios
INSERT INTO elemento (elemento_id, nome, tipo, descricao, capacidade_litros, altura_base_m, status_operacional) VALUES
('RES_CONS', 'Reservatório de Consumo', 'reservatorio', 'Reservatório principal de consumo diário', 50000.00, 0.0, 'ativo'),
('RES_INC', 'Reservatório de Incêndio', 'reservatorio', 'Reservatório exclusivo para combate a incêndio', 25000.00, 3.0, 'ativo'),
('RES_ELEV_A', 'Reservatório Elevado A', 'reservatorio', 'Reservatório elevado bloco A', 10000.00, 15.0, 'ativo'),
('RES_ELEV_B', 'Reservatório Elevado B', 'reservatorio', 'Reservatório elevado bloco B', 10000.00, 15.0, 'ativo'),
('RES_ABAST', 'Reservatório de Abastecimento', 'reservatorio', 'Reservatório de entrada da rede pública', 30000.00, 0.0, 'ativo'),
('RES_AUX', 'Reservatório Auxiliar', 'reservatorio', 'Reservatório auxiliar/redundância', 15000.00, 0.0, 'ativo');

-- Bombas
INSERT INTO elemento (elemento_id, nome, tipo, descricao, status_operacional) VALUES
('BOMB_CONS_1', 'Bomba Consumo 1', 'bomba', 'Bomba principal de recalque para consumo', 'ativo'),
('BOMB_CONS_2', 'Bomba Consumo 2', 'bomba', 'Bomba reserva de recalque para consumo', 'ativo'),
('BOMB_INC', 'Bomba Incêndio', 'bomba', 'Bomba exclusiva sistema de incêndio', 'ativo'),
('BOMB_ELEV_A', 'Bomba Elevado A', 'bomba', 'Bomba recalque reservatório elevado A', 'ativo'),
('BOMB_ELEV_B', 'Bomba Elevado B', 'bomba', 'Bomba recalque reservatório elevado B', 'ativo'),
('BOMB_ABAST', 'Bomba Abastecimento', 'bomba', 'Bomba de entrada da rede pública', 'ativo');

-- Válvulas
INSERT INTO elemento (elemento_id, nome, tipo, descricao, status_operacional) VALUES
('VALV_CONS_IN', 'Válvula Entrada Consumo', 'valvula', 'Válvula de entrada do reservatório de consumo', 'ativo'),
('VALV_CONS_OUT', 'Válvula Saída Consumo', 'valvula', 'Válvula de saída do reservatório de consumo', 'ativo'),
('VALV_INC_IN', 'Válvula Entrada Incêndio', 'valvula', 'Válvula de entrada do reservatório de incêndio', 'ativo'),
('VALV_INC_OUT', 'Válvula Saída Incêndio', 'valvula', 'Válvula de saída do reservatório de incêndio', 'ativo'),
('VALV_ELEV_A_IN', 'Válvula Entrada Elevado A', 'valvula', 'Válvula de entrada elevado A', 'ativo'),
('VALV_ELEV_B_IN', 'Válvula Entrada Elevado B', 'valvula', 'Válvula de entrada elevado B', 'ativo'),
('VALV_ABAST', 'Válvula Abastecimento Principal', 'valvula', 'Válvula principal da rede pública', 'ativo'),
('VALV_BYPASS', 'Válvula Bypass', 'valvula', 'Válvula de bypass emergencial', 'ativo');

-- Redes
INSERT INTO elemento (elemento_id, nome, tipo, descricao, status_operacional) VALUES
('REDE_PRINCIPAL', 'Rede Principal', 'rede', 'Rede principal de distribuição', 'ativo'),
('REDE_INCENDIO', 'Rede de Incêndio', 'rede', 'Rede separada para combate a incêndio', 'ativo');

-- ===========================================================
-- 3. COORDENADAS (Exemplo de planta técnica)
-- ===========================================================

INSERT INTO coordenada (elemento_id, coord_x, coord_y, coord_z, mapa_layer) 
SELECT id, 
  CASE elemento_id
    WHEN 'RES_CONS' THEN 150.0
    WHEN 'RES_INC' THEN 350.0
    WHEN 'RES_ELEV_A' THEN 100.0
    WHEN 'RES_ELEV_B' THEN 200.0
    WHEN 'RES_ABAST' THEN 50.0
    WHEN 'RES_AUX' THEN 400.0
    WHEN 'BOMB_CONS_1' THEN 180.0
    WHEN 'BOMB_CONS_2' THEN 190.0
    WHEN 'VALV_CONS_IN' THEN 140.0
    WHEN 'VALV_CONS_OUT' THEN 160.0
  END,
  CASE elemento_id
    WHEN 'RES_CONS' THEN 290.0
    WHEN 'RES_INC' THEN 100.0
    WHEN 'RES_ELEV_A' THEN 400.0
    WHEN 'RES_ELEV_B' THEN 400.0
    WHEN 'RES_ABAST' THEN 200.0
    WHEN 'RES_AUX' THEN 300.0
    WHEN 'BOMB_CONS_1' THEN 295.0
    WHEN 'BOMB_CONS_2' THEN 300.0
    WHEN 'VALV_CONS_IN' THEN 280.0
    WHEN 'VALV_CONS_OUT' THEN 305.0
  END,
  0.0,
  'principal'
FROM elemento
WHERE elemento_id IN ('RES_CONS', 'RES_INC', 'RES_ELEV_A', 'RES_ELEV_B', 
                      'RES_ABAST', 'RES_AUX', 'BOMB_CONS_1', 'BOMB_CONS_2',
                      'VALV_CONS_IN', 'VALV_CONS_OUT');

-- ===========================================================
-- 4. CONEXÕES HIDRÁULICAS
-- ===========================================================

INSERT INTO conexao (origem_id, destino_id, porta_origem, porta_destino, tipo, diametro_mm, descricao)
SELECT 
  e1.id, e2.id, 'out01', 'in01', 'hidraulica', 100,
  CONCAT('Conexão: ', e1.nome, ' → ', e2.nome)
FROM elemento e1, elemento e2
WHERE (e1.elemento_id, e2.elemento_id) IN (
  ('RES_ABAST', 'VALV_ABAST'),
  ('VALV_ABAST', 'BOMB_ABAST'),
  ('BOMB_ABAST', 'RES_CONS'),
  ('RES_CONS', 'VALV_CONS_OUT'),
  ('VALV_CONS_OUT', 'BOMB_CONS_1'),
  ('BOMB_CONS_1', 'REDE_PRINCIPAL'),
  ('RES_ABAST', 'BOMB_INC'),
  ('BOMB_INC', 'RES_INC'),
  ('RES_INC', 'REDE_INCENDIO')
);

-- ===========================================================
-- 5. SENSORES
-- ===========================================================

INSERT INTO sensores (sensor_id, elemento_id, tipo, modelo, unidade, precisao, range_min, range_max, freq_padrao_s, estado_operacional)
SELECT 
  CONCAT('SEN_', UPPER(LEFT(elemento_id, 8))),
  id,
  'ultrassom',
  'HC-SR04',
  'cm',
  '±0.5cm',
  2.0,
  400.0,
  30,
  'ativo'
FROM elemento
WHERE tipo = 'reservatorio';

-- Sensores de pressão nas bombas
INSERT INTO sensores (sensor_id, elemento_id, tipo, modelo, unidade, precisao, range_min, range_max, freq_padrao_s, estado_operacional)
SELECT 
  CONCAT('PRESS_', UPPER(LEFT(elemento_id, 8))),
  id,
  'pressao',
  'MPX5700',
  'bar',
  '±2%',
  0.0,
  7.0,
  30,
  'ativo'
FROM elemento
WHERE tipo = 'bomba';

-- ===========================================================
-- 6. ATUADORES
-- ===========================================================

INSERT INTO atuadores (atuador_id, elemento_id, tipo, estado_atual, modo_controle, potencia_kw, vazao_nominal_l_min)
SELECT 
  elemento_id,
  id,
  'bomba',
  'OFF',
  'manual',
  CASE 
    WHEN elemento_id LIKE '%INC%' THEN 7.5
    WHEN elemento_id LIKE '%ELEV%' THEN 3.0
    ELSE 5.5
  END,
  CASE 
    WHEN elemento_id LIKE '%INC%' THEN 500.0
    WHEN elemento_id LIKE '%ELEV%' THEN 150.0
    ELSE 250.0
  END
FROM elemento
WHERE tipo = 'bomba';

INSERT INTO atuadores (atuador_id, elemento_id, tipo, estado_atual, modo_controle)
SELECT 
  elemento_id,
  id,
  'valvula',
  'FECHADA',
  'manual'
FROM elemento
WHERE tipo = 'valvula';

-- ===========================================================
-- 7. CONFIGURAÇÕES DE ATIVOS
-- ===========================================================

INSERT INTO ativo_configs (ativo_id, elemento_id, deadband, window_size, stability_stddev)
SELECT 
  elemento_id,
  id,
  CASE 
    WHEN elemento_id = 'RES_INC' THEN 1.0  -- Incêndio: mais sensível
    ELSE 2.0
  END,
  11,
  0.5
FROM elemento
WHERE tipo = 'reservatorio';

-- ===========================================================
-- 8. LEITURAS RAW DE EXEMPLO (últimas 24h simuladas)
-- ===========================================================

-- Gerar leituras para RES_CONS (consumo com variação ao longo do dia)
INSERT INTO leituras_raw (sensor_id, elemento_id, variavel, valor, unidade, fonte, autor, modo, datetime)
SELECT 
  'SEN_RES_CONS',
  (SELECT id FROM elemento WHERE elemento_id = 'RES_CONS'),
  'nivel_cm',
  -- Simular consumo: nível cai durante o dia, sobe durante abastecimento
  250 + 
  (20 * SIN(EXTRACT(EPOCH FROM timestamp) / 3600.0)) +  -- Variação diária
  (RANDOM() * 2 - 1), -- Ruído
  'cm',
  'sensor',
  'NODE_ESP32_RES_CONS',
  'automatica',
  timestamp
FROM GENERATE_SERIES(
  NOW() - INTERVAL '24 hours',
  NOW(),
  INTERVAL '30 seconds'
) AS timestamp;

-- Leituras para RES_INC (estável, próximo a 70%)
INSERT INTO leituras_raw (sensor_id, elemento_id, variavel, valor, unidade, fonte, autor, modo, datetime)
SELECT 
  'SEN_RES_INC',
  (SELECT id FROM elemento WHERE elemento_id = 'RES_INC'),
  'nivel_cm',
  175 + (RANDOM() * 1 - 0.5), -- Muito estável
  'cm',
  'sensor',
  'NODE_ESP32_RES_INC',
  'automatica',
  timestamp
FROM GENERATE_SERIES(
  NOW() - INTERVAL '24 hours',
  NOW(),
  INTERVAL '30 seconds'
) AS timestamp;

-- ===========================================================
-- 9. HIDRÔMETROS
-- ===========================================================

INSERT INTO hidrometros (identificador, local, elemento_id, leitura_m3, data_leitura, usuario_nome)
VALUES
('HID001', 'Entrada principal', (SELECT id FROM elemento WHERE elemento_id = 'RES_ABAST'), 1250.350, CURRENT_DATE, 'João Silva'),
('HID002', 'Bloco A', (SELECT id FROM elemento WHERE elemento_id = 'RES_ELEV_A'), 850.120, CURRENT_DATE, 'João Silva'),
('HID003', 'Bloco B', (SELECT id FROM elemento WHERE elemento_id = 'RES_ELEV_B'), 920.450, CURRENT_DATE, 'João Silva');

-- ===========================================================
-- 10. EVENTOS DE EXEMPLO
-- ===========================================================

INSERT INTO eventos (tipo, elemento_id, detalhe, causa_provavel, nivel_confianca, severidade, detectado_por, datetime_inicio, datetime_fim)
SELECT 
  'abastecimento',
  (SELECT id FROM elemento WHERE elemento_id = 'RES_CONS'),
  '{"delta_cm": 45, "volume_litros": 22500, "bomba": "BOMB_ABAST"}'::JSONB,
  'Abastecimento programado',
  0.95,
  'info',
  'sistema_automatico',
  NOW() - INTERVAL '8 hours',
  NOW() - INTERVAL '7 hours 30 minutes';

INSERT INTO eventos (tipo, elemento_id, detalhe, causa_provavel, nivel_confianca, severidade, detectado_por, datetime_inicio)
SELECT 
  'consumo',
  (SELECT id FROM elemento WHERE elemento_id = 'RES_CONS'),
  '{"delta_cm": -12, "taxa_cm_h": -1.5}'::JSONB,
  'Consumo normal diurno',
  0.90,
  'info',
  'detectar_eventos',
  NOW() - INTERVAL '4 hours';

-- ===========================================================
-- RESUMO DOS DADOS INSERIDOS
-- ===========================================================

SELECT 'ELEMENTOS CADASTRADOS' as resumo, COUNT(*) as total FROM elemento
UNION ALL
SELECT 'SENSORES', COUNT(*) FROM sensores
UNION ALL
SELECT 'ATUADORES', COUNT(*) FROM atuadores
UNION ALL
SELECT 'CONEXÕES', COUNT(*) FROM conexao
UNION ALL
SELECT 'LEITURAS RAW (últimas 24h)', COUNT(*) FROM leituras_raw
UNION ALL
SELECT 'USUÁRIOS', COUNT(*) FROM usuarios
UNION ALL
SELECT 'HIDRÔMETROS', COUNT(*) FROM hidrometros
UNION ALL
SELECT 'EVENTOS', COUNT(*) FROM eventos;

-- ===========================================================
-- FIM DOS SEEDS
-- ===========================================================

-- Processar as leituras inseridas
-- (Comentado por padrão - descomentar para processar automaticamente)
-- SELECT proc_process_sensor_window('SEN_RES_CONS');
-- SELECT proc_process_sensor_window('SEN_RES_INC');
