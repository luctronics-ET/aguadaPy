-- ===========================================================
-- SISTEMA SUPERVISÓRIO HÍDRICO IoT - SCHEMA COMPLETO
-- Versão: 1.0.0
-- Data: 2025-10-30
-- PostgreSQL 13+
-- ===========================================================

-- Criar schema dedicado
CREATE SCHEMA IF NOT EXISTS supervisorio;
SET search_path = supervisorio;

-- ===========================================================
-- 1. GESTÃO DE USUÁRIOS E AUDITORIA
-- ===========================================================

CREATE TABLE usuarios (
  usuario_id SERIAL PRIMARY KEY,
  nome TEXT NOT NULL,
  email TEXT UNIQUE,
  login VARCHAR(50) UNIQUE NOT NULL,
  senha_hash TEXT NOT NULL,
  papel VARCHAR(20) NOT NULL, -- 'admin', 'operador', 'visualizador'
  nivel_acesso TEXT,
  ativo BOOLEAN DEFAULT TRUE,
  criado_em TIMESTAMPTZ DEFAULT NOW(),
  ultimo_login TIMESTAMPTZ
);

-- ===========================================================
-- 2. ELEMENTOS FÍSICOS DO SISTEMA
-- ===========================================================

CREATE TABLE elemento (
  id SERIAL PRIMARY KEY,
  elemento_id TEXT UNIQUE NOT NULL, -- Ex: 'RES001', 'BOMB001', 'VALV001'
  nome VARCHAR(100) NOT NULL,
  tipo VARCHAR(30) NOT NULL, -- 'reservatorio', 'bomba', 'valvula', 'rede', 'consumidor'
  descricao TEXT,
  fabricante TEXT,
  modelo TEXT,
  instalado_em DATE,
  capacidade_litros DECIMAL(10,2),
  altura_base_m DECIMAL(6,2),
  status_operacional VARCHAR(20) DEFAULT 'ativo', -- 'ativo', 'manutencao', 'inativo'
  localizacao TEXT,
  ativo BOOLEAN DEFAULT TRUE,
  criado_em TIMESTAMPTZ DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ DEFAULT NOW()
);

-- Índices
CREATE INDEX idx_elemento_tipo ON elemento(tipo);
CREATE INDEX idx_elemento_elemento_id ON elemento(elemento_id);
CREATE INDEX idx_elemento_status ON elemento(status_operacional);

-- ===========================================================
-- 3. COORDENADAS ESPACIAIS (MAPA/VISUALIZAÇÃO)
-- ===========================================================

CREATE TABLE coordenada (
  id SERIAL PRIMARY KEY,
  elemento_id INT NOT NULL REFERENCES elemento(id) ON DELETE CASCADE,
  -- Coordenadas locais (planta técnica)
  coord_x DECIMAL(10,3),
  coord_y DECIMAL(10,3),
  coord_z DECIMAL(10,3),
  -- Coordenadas geográficas (GPS)
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  altitude_m DECIMAL(8,2),
  -- Camada do mapa
  mapa_layer VARCHAR(50) DEFAULT 'principal', -- 'principal', 'subsolo', 'cobertura'
  criado_em TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(elemento_id)
);

CREATE INDEX idx_coordenada_elemento ON coordenada(elemento_id);
CREATE INDEX idx_coordenada_layer ON coordenada(mapa_layer);

-- ===========================================================
-- 4. CONEXÕES HIDRÁULICAS (GRAFO)
-- ===========================================================

CREATE TABLE conexao (
  id SERIAL PRIMARY KEY,
  origem_id INT NOT NULL REFERENCES elemento(id) ON DELETE CASCADE,
  destino_id INT NOT NULL REFERENCES elemento(id) ON DELETE CASCADE,
  porta_origem VARCHAR(20), -- Ex: 'out01', 'saida_principal'
  porta_destino VARCHAR(20), -- Ex: 'in01', 'entrada_reservatorio'
  tipo VARCHAR(20) DEFAULT 'hidraulica', -- 'hidraulica', 'eletrica', 'logica'
  diametro_mm INT,
  comprimento_m DECIMAL(8,2),
  descricao TEXT,
  ativo BOOLEAN DEFAULT TRUE,
  criado_em TIMESTAMPTZ DEFAULT NOW(),
  CHECK (origem_id != destino_id),
  UNIQUE(origem_id, porta_origem, destino_id, porta_destino)
);

CREATE INDEX idx_conexao_origem ON conexao(origem_id);
CREATE INDEX idx_conexao_destino ON conexao(destino_id);
CREATE INDEX idx_conexao_tipo ON conexao(tipo);

-- ===========================================================
-- 5. SENSORES
-- ===========================================================

CREATE TABLE sensores (
  sensor_id TEXT PRIMARY KEY, -- Ex: 'SEN001', 'ULTRASSOM_RES001'
  elemento_id INT NOT NULL REFERENCES elemento(id) ON DELETE CASCADE,
  tipo VARCHAR(30) NOT NULL, -- 'ultrassom', 'pressao', 'vazao', 'temperatura', 'corrente'
  modelo TEXT,
  unidade VARCHAR(10), -- 'cm', 'L', 'Pa', 'C', 'A'
  precisao TEXT, -- Ex: '±0.5cm', '±2%'
  range_min DECIMAL(10,3),
  range_max DECIMAL(10,3),
  freq_padrao_s INT DEFAULT 30, -- Frequência de leitura em segundos
  fator_calibracao DECIMAL(10,6) DEFAULT 1.0,
  offset_calibracao DECIMAL(10,3) DEFAULT 0.0,
  estado_operacional VARCHAR(20) DEFAULT 'ativo', -- 'ativo', 'falha', 'manutencao'
  ultima_calibracao TIMESTAMPTZ,
  proxima_calibracao DATE,
  meta JSONB, -- Metadados adicionais
  criado_em TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_sensores_elemento ON sensores(elemento_id);
CREATE INDEX idx_sensores_tipo ON sensores(tipo);
CREATE INDEX idx_sensores_estado ON sensores(estado_operacional);

-- ===========================================================
-- 6. ATUADORES (BOMBAS, VÁLVULAS)
-- ===========================================================

CREATE TABLE atuadores (
  atuador_id TEXT PRIMARY KEY,
  elemento_id INT NOT NULL REFERENCES elemento(id) ON DELETE CASCADE,
  tipo VARCHAR(30) NOT NULL, -- 'bomba', 'valvula'
  modelo TEXT,
  estado_atual VARCHAR(20), -- 'ON', 'OFF', 'ABERTA', 'FECHADA'
  modo_controle VARCHAR(20) DEFAULT 'manual', -- 'manual', 'automatico', 'programado'
  potencia_kw DECIMAL(6,2),
  vazao_nominal_l_min DECIMAL(8,2),
  pressao_nominal_bar DECIMAL(6,2),
  gpio_pin INT, -- Pino de controle
  ultima_atualizacao TIMESTAMPTZ DEFAULT NOW(),
  criado_em TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_atuadores_elemento ON atuadores(elemento_id);
CREATE INDEX idx_atuadores_tipo ON atuadores(tipo);
CREATE INDEX idx_atuadores_estado ON atuadores(estado_atual);

-- ===========================================================
-- 7. CALIBRAÇÕES
-- ===========================================================

CREATE TABLE calibracoes (
  calibracao_id SERIAL PRIMARY KEY,
  sensor_id TEXT REFERENCES sensores(sensor_id),
  elemento_id INT REFERENCES elemento(id),
  responsavel_usuario_id INT REFERENCES usuarios(usuario_id),
  datahora TIMESTAMPTZ DEFAULT NOW(),
  tipo VARCHAR(20), -- 'manual', 'automatica'
  valor_referencia DECIMAL(10,3), -- Valor medido manualmente (régua, hidrômetro)
  valor_sensor DECIMAL(10,3), -- Valor lido pelo sensor
  diferenca DECIMAL(10,3) GENERATED ALWAYS AS (valor_referencia - valor_sensor) STORED,
  ajuste_aplicado TEXT,
  fator_calibracao_novo DECIMAL(10,6),
  offset_calibracao_novo DECIMAL(10,3),
  observacao TEXT,
  criado_em TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_calibracoes_sensor ON calibracoes(sensor_id);
CREATE INDEX idx_calibracoes_data ON calibracoes(datahora);

-- ===========================================================
-- 8. LEITURAS BRUTAS (RAW)
-- ===========================================================

CREATE TABLE leituras_raw (
  leitura_id BIGSERIAL PRIMARY KEY,
  sensor_id TEXT NOT NULL REFERENCES sensores(sensor_id),
  elemento_id INT NOT NULL REFERENCES elemento(id),
  variavel VARCHAR(30) NOT NULL, -- 'nivel_cm', 'pressao_Pa', 'vazao_m3s', etc.
  valor DECIMAL(10,3) NOT NULL,
  unidade VARCHAR(10),
  fonte VARCHAR(30) NOT NULL, -- 'sensor', 'usuario', 'sistema'
  autor TEXT, -- Node_ID, username, nome do processo
  modo VARCHAR(20), -- 'automatica', 'manual'
  observacao TEXT,
  datetime TIMESTAMPTZ NOT NULL,
  processed BOOLEAN DEFAULT FALSE, -- Se já foi agregada
  checksum TEXT, -- Hash para integridade
  criado_em TIMESTAMPTZ DEFAULT NOW()
);

-- Índices otimizados para séries temporais
CREATE INDEX idx_leituras_raw_sensor_datetime ON leituras_raw(sensor_id, datetime DESC);
CREATE INDEX idx_leituras_raw_elemento_datetime ON leituras_raw(elemento_id, datetime DESC);
CREATE INDEX idx_leituras_raw_datetime ON leituras_raw(datetime DESC);
CREATE INDEX idx_leituras_raw_processed ON leituras_raw(processed) WHERE processed = FALSE;
CREATE INDEX idx_leituras_raw_variavel ON leituras_raw(variavel);

-- ===========================================================
-- 9. LEITURAS PROCESSADAS (COMPRIMIDAS)
-- ===========================================================

CREATE TABLE leituras_processadas (
  proc_id BIGSERIAL PRIMARY KEY,
  elemento_id INT NOT NULL REFERENCES elemento(id),
  variavel VARCHAR(30) NOT NULL,
  valor DECIMAL(10,3) NOT NULL, -- Valor mediano/representativo
  unidade VARCHAR(10),
  criterio TEXT, -- Ex: 'mediana_11_amostras_deadband_2cm'
  variacao DECIMAL(10,3), -- Diferença em relação ao anterior
  stddev DECIMAL(10,3), -- Desvio padrão das leituras agregadas
  min_valor DECIMAL(10,3),
  max_valor DECIMAL(10,3),
  n_amostras INT, -- Quantidade de leituras agregadas
  data_inicio TIMESTAMPTZ NOT NULL,
  data_fim TIMESTAMPTZ NOT NULL,
  fonte VARCHAR(30),
  autor TEXT,
  meta JSONB, -- Metadados adicionais (min, max, stddev detalhado)
  criado_em TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_leituras_proc_elemento_datafim ON leituras_processadas(elemento_id, data_fim DESC);
CREATE INDEX idx_leituras_proc_datafim ON leituras_processadas(data_fim DESC);
CREATE INDEX idx_leituras_proc_variavel ON leituras_processadas(variavel);

-- ===========================================================
-- 10. ESTADOS DE ELEMENTOS (HISTÓRICO)
-- ===========================================================

CREATE TABLE estado_elemento (
  id BIGSERIAL PRIMARY KEY,
  elemento_id INT NOT NULL REFERENCES elemento(id),
  tipo_elemento VARCHAR(30), -- 'bomba', 'valvula', 'reservatorio'
  atributo VARCHAR(30), -- 'volume_litros', 'estado', 'pressao_bar'
  valor TEXT,
  valor_numerico DECIMAL(10,3),
  origem VARCHAR(30), -- 'sensor', 'usuario', 'sistema'
  registrado_por TEXT,
  datahora TIMESTAMPTZ NOT NULL,
  criado_em TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_estado_elemento_elemento_data ON estado_elemento(elemento_id, datahora DESC);
CREATE INDEX idx_estado_elemento_atributo ON estado_elemento(atributo);

-- ===========================================================
-- 11. EVENTOS DETECTADOS
-- ===========================================================

CREATE TABLE eventos (
  evento_id BIGSERIAL PRIMARY KEY,
  tipo VARCHAR(50) NOT NULL, -- 'abastecimento', 'vazamento', 'consumo', 'falha_sensor'
  elemento_id INT REFERENCES elemento(id),
  detalhe JSONB, -- Detalhes específicos (volumes, bombas envolvidas, etc.)
  causa_provavel TEXT,
  nivel_confianca DECIMAL(4,2), -- 0.0 a 1.0
  severidade VARCHAR(20) DEFAULT 'info', -- 'critico', 'alerta', 'info'
  detectado_por TEXT, -- Nome da função/algoritmo
  datetime_inicio TIMESTAMPTZ NOT NULL,
  datetime_fim TIMESTAMPTZ,
  duracao_minutos INT GENERATED ALWAYS AS (
    EXTRACT(EPOCH FROM (datetime_fim - datetime_inicio))/60
  ) STORED,
  status VARCHAR(20) DEFAULT 'ativo', -- 'ativo', 'resolvido', 'falso_positivo'
  resolvido_por INT REFERENCES usuarios(usuario_id),
  criado_em TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_eventos_tipo ON eventos(tipo);
CREATE INDEX idx_eventos_elemento ON eventos(elemento_id);
CREATE INDEX idx_eventos_inicio ON eventos(datetime_inicio DESC);
CREATE INDEX idx_eventos_status ON eventos(status);
CREATE INDEX idx_eventos_severidade ON eventos(severidade);

-- ===========================================================
-- 12. ANOMALIAS (MONITORAMENTO)
-- ===========================================================

CREATE TABLE anomalias (
  anomalia_id BIGSERIAL PRIMARY KEY,
  tipo VARCHAR(50), -- 'sensor_ruidoso', 'pressao_baixa', 'consumo_anormal'
  elemento_id INT REFERENCES elemento(id),
  descricao TEXT,
  nivel_alerta VARCHAR(20) DEFAULT 'baixo', -- 'critico', 'alto', 'moderado', 'baixo'
  inicio TIMESTAMPTZ NOT NULL,
  fim TIMESTAMPTZ,
  status VARCHAR(20) DEFAULT 'ativo', -- 'ativo', 'resolvido', 'ignorado'
  detectado_por TEXT,
  acao_tomada TEXT,
  resolvido_por INT REFERENCES usuarios(usuario_id),
  criado_em TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_anomalias_elemento ON anomalias(elemento_id);
CREATE INDEX idx_anomalias_status ON anomalias(status);
CREATE INDEX idx_anomalias_nivel ON anomalias(nivel_alerta);
CREATE INDEX idx_anomalias_inicio ON anomalias(inicio DESC);

-- ===========================================================
-- 13. CONFIGURAÇÕES POR ATIVO
-- ===========================================================

CREATE TABLE ativo_configs (
  ativo_id TEXT PRIMARY KEY,
  elemento_id INT UNIQUE REFERENCES elemento(id),
  deadband DECIMAL(10,3), -- Tolerância para considerar estável (ex: 2cm)
  window_size INT DEFAULT 11, -- Número de leituras para mediana
  stability_stddev DECIMAL(10,3) DEFAULT 0.5, -- Desvio padrão máximo para estável
  min_variacao_evento DECIMAL(10,3), -- Variação mínima para gerar evento
  intervalo_alerta_s INT DEFAULT 3600, -- Tempo sem leitura para gerar alerta
  meta JSONB, -- Configurações adicionais
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_ativo_configs_elemento ON ativo_configs(elemento_id);

-- ===========================================================
-- 14. FILA DE PROCESSAMENTO
-- ===========================================================

CREATE TABLE processing_queue (
  queue_id BIGSERIAL PRIMARY KEY,
  sensor_id TEXT,
  elemento_id INT,
  tipo_processamento VARCHAR(30) DEFAULT 'compressao', -- 'compressao', 'evento', 'relatorio'
  prioridade INT DEFAULT 5, -- 1=alta, 10=baixa
  enqueued_at TIMESTAMPTZ DEFAULT NOW(),
  processed BOOLEAN DEFAULT FALSE,
  processed_at TIMESTAMPTZ,
  error TEXT
);

CREATE INDEX idx_queue_processed ON processing_queue(processed) WHERE processed = FALSE;
CREATE INDEX idx_queue_prioridade ON processing_queue(prioridade, enqueued_at);

-- ===========================================================
-- 15. HIDRÔMETROS (LEITURAS MANUAIS)
-- ===========================================================

CREATE TABLE hidrometros (
  hidrometro_id SERIAL PRIMARY KEY,
  identificador TEXT UNIQUE NOT NULL, -- Número do hidrômetro
  local TEXT,
  elemento_id INT REFERENCES elemento(id),
  leitura_m3 DECIMAL(10,3) NOT NULL,
  leitura_anterior_m3 DECIMAL(10,3),
  consumo_m3 DECIMAL(10,3) GENERATED ALWAYS AS (leitura_m3 - COALESCE(leitura_anterior_m3, leitura_m3)) STORED,
  data_leitura DATE NOT NULL,
  data_leitura_anterior DATE,
  usuario_id INT REFERENCES usuarios(usuario_id),
  usuario_nome TEXT,
  observacao TEXT,
  foto_hidrometro TEXT, -- Path para foto
  criado_em TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_hidrometros_data ON hidrometros(data_leitura DESC);
CREATE INDEX idx_hidrometros_elemento ON hidrometros(elemento_id);

-- ===========================================================
-- 16. RELATÓRIOS DIÁRIOS
-- ===========================================================

CREATE TABLE relatorio_diario (
  relatorio_id SERIAL PRIMARY KEY,
  data DATE UNIQUE NOT NULL,
  volume_consumido_total_l DECIMAL(10,2),
  volume_abastecido_total_l DECIMAL(10,2),
  volume_perdido_l DECIMAL(10,2), -- Vazamentos detectados
  eventos_registrados INT,
  anomalias_detectadas INT,
  alertas_criticos INT,
  resumo TEXT,
  detalhes JSONB, -- JSON com detalhes por reservatório
  gerado_em TIMESTAMPTZ DEFAULT NOW(),
  gerado_por TEXT DEFAULT 'sistema'
);

CREATE INDEX idx_relatorio_data ON relatorio_diario(data DESC);

-- ===========================================================
-- 17. LOG DE EVENTOS DO SISTEMA
-- ===========================================================

CREATE TABLE log_evento (
  log_id BIGSERIAL PRIMARY KEY,
  datahora TIMESTAMPTZ DEFAULT NOW(),
  tipo VARCHAR(30), -- 'alteracao_estado', 'calibracao', 'alerta', 'acesso'
  nivel VARCHAR(10) DEFAULT 'info', -- 'debug', 'info', 'warning', 'error', 'critical'
  descricao TEXT,
  elemento_id INT REFERENCES elemento(id),
  usuario_id INT REFERENCES usuarios(usuario_id),
  dados JSONB, -- Dados adicionais em formato JSON
  ip_origem INET,
  user_agent TEXT
);

CREATE INDEX idx_log_datahora ON log_evento(datahora DESC);
CREATE INDEX idx_log_tipo ON log_evento(tipo);
CREATE INDEX idx_log_nivel ON log_evento(nivel);
CREATE INDEX idx_log_usuario ON log_evento(usuario_id);

-- ===========================================================
-- COMENTÁRIOS NAS TABELAS
-- ===========================================================

COMMENT ON TABLE elemento IS 'Todos os componentes físicos do sistema (reservatórios, bombas, válvulas, etc.)';
COMMENT ON TABLE coordenada IS 'Posicionamento espacial para visualização em mapas';
COMMENT ON TABLE conexao IS 'Grafo hidráulico - quem está conectado a quem';
COMMENT ON TABLE sensores IS 'Sensores instalados nos elementos';
COMMENT ON TABLE leituras_raw IS 'Leituras brutas dos sensores (todas, sem filtro) - 30 em 30s';
COMMENT ON TABLE leituras_processadas IS 'Leituras comprimidas - apenas mudanças significativas';
COMMENT ON TABLE eventos IS 'Eventos detectados automaticamente (abastecimento, vazamento, consumo)';
COMMENT ON TABLE ativo_configs IS 'Configurações de processamento por ativo (deadband, window_size)';
COMMENT ON TABLE relatorio_diario IS 'Relatório automático gerado às 06:00 diariamente';

-- ===========================================================
-- FIM DO SCHEMA
-- ===========================================================
