# Arquivos Criados - Sistema Supervisório Hídrico IoT

## 📁 Estrutura de Arquivos Gerada

```
aguadaPy/
├── README.md                      ✅ Documentação principal do projeto
├── TODO.md                        ✅ Lista detalhada de tarefas (93 dias estimados)
├── ESTRATEGIA_IOT.md             ✅ Estratégia completa de desenvolvimento IoT
├── chatgptAguada30OUT.txt        ✅ Arquivo original com conversas
│
└── database/                      ✅ Scripts de banco de dados
    ├── schema.sql                 ✅ Estrutura completa do PostgreSQL (17 tabelas)
    ├── functions.sql              ✅ 7 funções PL/pgSQL (processamento, eventos)
    ├── triggers.sql               ✅ 10 triggers automáticos
    └── seeds.sql                  ✅ Dados de exemplo (6 reservatórios, sensores)
```

---

## 📄 Detalhamento dos Arquivos

### 1. README.md (Principal)

**Conteúdo**:
- Visão geral do sistema
- Arquitetura de dados (camada RAW + PROCESSADA)
- Modelo de compressão inteligente (90% redução)
- Fluxo de dados completo
- Estratégia de desenvolvimento IoT
  - Hardware: ESP32-C3, Arduino Nano, sensores
  - Protocolos: WiFi, ESP-NOW, Ethernet, I²C
- Plano de testes e implantação
- Análise de escalabilidade e custos
- ROI: **6.3 meses**
- Estrutura de diretórios do projeto

**Destaques**:
- ✅ Instalação passo a passo
- ✅ Cronograma de implantação (8 semanas)
- ✅ Tabela de custos detalhada
- ✅ Roadmap futuro (ML, mobile app)

---

### 2. TODO.md (Lista de Tarefas)

**Conteúdo**:
- **Fase 0**: Planejamento ✅ CONCLUÍDO
- **Fase 1**: Banco de Dados (4 dias)
- **Fase 2**: Hardware IoT (12 dias)
- **Fase 3**: Backend/API (12 dias)
- **Fase 4**: Frontend/Dashboard (17 dias)
- **Fase 5**: Lógica de Negócio (9 dias)
- **Fase 6**: Calibração (7 dias)
- **Fase 7**: Testes (15 dias)
- **Fase 8**: Documentação (7 dias)
- **Fase 9**: Deploy (7 dias)
- **Fase 10**: Expansões Futuras

**Total estimado**: **~93 dias (4.5 meses para MVP)**

**Próximos passos imediatos**:
1. Instalar PostgreSQL
2. Executar scripts SQL
3. Comprar componentes IoT
4. Configurar ambiente backend

---

### 3. ESTRATEGIA_IOT.md (Estratégia Completa)

**Seções**:

#### 2. Seleção de Hardware
- **ESP32-C3 Super Mini** (R$ 15) - Principal ⭐
- **Arduino Nano** (R$ 25) - Backup
- **HC-SR04** (R$ 8) - Sensor ultrassom
- **MPX5700AP** (R$ 35) - Sensor pressão
- **YF-S201** (R$ 20) - Sensor vazão
- **DS18B20** (R$ 10) - Sensor temperatura

#### 3. Protocolos de Comunicação
| Protocolo | Range | Taxa | Consumo | Uso |
|-----------|-------|------|---------|-----|
| WiFi | 100m | 54Mbps | 80mA | Principal |
| ESP-NOW | 200m | 1Mbps | 20mA | Fallback |
| Ethernet | 100m | 100Mbps | 50mA | Gateway |
| I²C | 1m | 400kbps | Baixo | Sensores |

#### 4. Integração Software/Firmware
- **Firmware ESP32**: Estrutura completa com exemplos de código
  - Leitura de sensores
  - Cálculo de mediana
  - Envio WiFi + fallback ESP-NOW
  - Deep sleep (economia de energia)
- **Backend API**: Node.js Express
  - Endpoints REST
  - Autenticação JWT
  - WebSocket tempo real

#### 5. Plano de Testes
- Testes de hardware (sensor, WiFi, autonomia)
- Testes unitários (Jest/Mocha)
- Testes de integração (end-to-end)
- Testes de campo (7 dias piloto)

#### 6. Implantação e Manutenção
- Cronograma de 8 semanas
- Manutenção preventiva (mensal, trimestral)
- Procedimentos de calibração
- Tratamento de falhas comuns

#### 7. Análise de Escalabilidade
- **Atual**: 6 reservatórios (~R$ 1.000/ano)
- **Médio**: 20 reservatórios (~R$ 3.180/ano)
- **Grande**: 50 reservatórios (~R$ 12.880/ano)

#### 8. Análise de Custos
- **Investimento inicial**: R$ 3.838
- **Custo operacional**: R$ 45/mês
- **Economia estimada**: R$ 611/mês
- **ROI**: **6.3 meses** ✅

#### 10. Casos de Uso Práticos
- Detecção de vazamento noturno
- Otimização de abastecimento
- Relatórios gerenciais

---

### 4. database/schema.sql

**17 Tabelas criadas**:

1. **usuarios** - Gestão de usuários e permissões
2. **elemento** - Todos os componentes físicos (reservatórios, bombas, válvulas)
3. **coordenada** - Posicionamento espacial (mapas)
4. **conexao** - Grafo hidráulico (quem conecta a quem)
5. **sensores** - Sensores instalados
6. **atuadores** - Bombas e válvulas (controle)
7. **calibracoes** - Histórico de calibrações
8. **leituras_raw** - Leituras brutas (todas, 30 em 30s)
9. **leituras_processadas** - Leituras comprimidas (apenas mudanças)
10. **estado_elemento** - Histórico de estados
11. **eventos** - Eventos detectados (abastecimento, vazamento, etc.)
12. **anomalias** - Anomalias identificadas
13. **ativo_configs** - Configurações por ativo (deadband, window_size)
14. **processing_queue** - Fila de processamento
15. **hidrometros** - Leituras manuais de hidrômetros
16. **relatorio_diario** - Relatórios automáticos (06:00)
17. **log_evento** - Log de eventos do sistema

**Destaques**:
- ✅ Índices otimizados para séries temporais
- ✅ Chaves estrangeiras e constraints
- ✅ Campos JSONB para flexibilidade
- ✅ Comentários explicativos

---

### 5. database/functions.sql

**7 Funções PL/pgSQL**:

1. **proc_process_sensor_window(sensor_id)** ⭐ CORE
   - Calcula mediana de N leituras
   - Aplica deadband
   - Estende registro anterior OU cria novo
   - Marca leituras como processadas
   
2. **detectar_eventos(elemento_id)**
   - Detecta ABASTECIMENTO (delta > +10cm)
   - Detecta VAZAMENTO (queda lenta < -2cm/h)
   - Detecta CONSUMO (-1 a -5cm)
   
3. **detectar_anomalias(sensor_id)**
   - Ruído excessivo (stddev > 3× normal)
   - Marca sensor como "falha"
   
4. **calcular_consumo_diario(data)**
   - Retorna consumo, abastecimento e perdas por reservatório
   
5. **gerar_relatorio_diario()** ⭐ AUTOMÁTICO 06:00
   - Consolida métricas do dia anterior
   - Insere em relatorio_diario
   - Envia log
   
6. **proc_reprocessar_elemento(elemento_id)**
   - Reprocessa histórico completo (útil após mudança de config)
   
7. **limpar_dados_antigos(dias)**
   - Remove leituras RAW antigas (já processadas)

---

### 6. database/triggers.sql

**10 Triggers automáticos**:

1. **after_insert_leituras_raw** ⭐ CORE
   - Acionado após nova leitura
   - Conta leituras não processadas
   - Se >= window_size → chama proc_process_sensor_window()
   - Detecta eventos e anomalias
   
2. **update_elemento_timestamp**
   - Atualiza campo atualizado_em automaticamente
   
3. **after_update_atuador**
   - Registra mudanças de estado (bomba ON→OFF)
   - Insere em estado_elemento e log_evento
   
4. **validate_leitura_raw**
   - Valida se leitura está dentro do range do sensor
   - Gera anomalia se fora do range
   
5. **check_nivel_critico**
   - Alerta se nível < 20% (crítico baixo)
   - Alerta se nível > 95% (overflow)
   
6. **update_hidrometro_anterior**
   - Preenche leitura_anterior para cálculo de consumo
   
7. **after_calibracao**
   - Atualiza sensor com novos valores
   - Registra log
   
8. **notify_evento_critico**
   - Envia notificação PostgreSQL (LISTEN/NOTIFY)
   - Para eventos críticos/alertas
   
9. **prevent_delete_processadas**
   - Previne exclusão acidental de dados processados
   
10. **generate_checksum**
    - Gera MD5 para integridade de dados

---

### 7. database/seeds.sql

**Dados de exemplo inseridos**:

- ✅ 3 usuários (admin, operador, visualizador)
- ✅ 6 reservatórios (CONS, INC, ELEV_A, ELEV_B, ABAST, AUX)
- ✅ 6 bombas
- ✅ 8 válvulas
- ✅ 2 redes (principal, incêndio)
- ✅ Coordenadas espaciais (mapa)
- ✅ 9 conexões hidráulicas
- ✅ 6 sensores de nível (HC-SR04)
- ✅ 6 sensores de pressão (bombas)
- ✅ 12 atuadores (bombas + válvulas)
- ✅ Configurações de ativos (deadband, window_size)
- ✅ **Leituras simuladas (últimas 24h)**:
  - RES_CONS: ~2880 leituras (consumo com variação)
  - RES_INC: ~2880 leituras (estável 70%)
- ✅ 3 hidrômetros
- ✅ 2 eventos de exemplo

**Total de dados inseridos**: ~6.000 registros

---

## 🎯 Como Utilizar

### Passo 1: Instalar PostgreSQL
```bash
sudo apt update
sudo apt install postgresql postgresql-contrib
```

### Passo 2: Criar Banco
```bash
sudo -u postgres psql
CREATE DATABASE aguada_cmms;
\q
```

### Passo 3: Executar Scripts
```bash
cd /opt/lampp/htdocs/aguadaPy/database
psql -U postgres -d aguada_cmms -f schema.sql
psql -U postgres -d aguada_cmms -f functions.sql
psql -U postgres -d aguada_cmms -f triggers.sql
psql -U postgres -d aguada_cmms -f seeds.sql
```

### Passo 4: Validar
```sql
-- Verificar tabelas criadas
\dt supervisorio.*

-- Ver dados de exemplo
SELECT * FROM supervisorio.elemento;
SELECT * FROM supervisorio.sensores;
SELECT COUNT(*) FROM supervisorio.leituras_raw;

-- Testar função de processamento
SELECT supervisorio.proc_process_sensor_window('SEN_RES_CONS');

-- Ver resultado processado
SELECT * FROM supervisorio.leituras_processadas ORDER BY data_fim DESC;
```

---

## 📊 Estatísticas do Projeto

| Métrica | Valor |
|---------|-------|
| Arquivos criados | 7 |
| Linhas de código SQL | ~2.500 |
| Tabelas no banco | 17 |
| Funções PL/pgSQL | 7 |
| Triggers | 10 |
| Documentação (páginas A4) | ~50 |
| Tempo estimado MVP | 93 dias |
| Custo hardware (6 res.) | R$ 388 |
| ROI | 6.3 meses |

---

## 🚀 Próximos Passos

1. ✅ **Concluído**: Modelagem e documentação
2. ⏳ **Próximo**: Executar scripts SQL no PostgreSQL
3. ⏳ **Próximo**: Desenvolver firmware ESP32
4. ⏳ **Próximo**: Criar API backend
5. ⏳ **Próximo**: Comprar hardware IoT

---

## 📞 Suporte

Para dúvidas sobre implementação:
- Consultar `README.md` para visão geral
- Consultar `TODO.md` para tarefas detalhadas
- Consultar `ESTRATEGIA_IOT.md` para aspectos técnicos
- Verificar comentários nos scripts SQL

---

**Sistema pronto para desenvolvimento!** 🎉

Todos os fundamentos estão estabelecidos:
- ✅ Arquitetura definida
- ✅ Banco de dados modelado
- ✅ Lógica de processamento implementada
- ✅ Documentação completa
- ✅ Estratégia de IoT detalhada
- ✅ Plano de testes e implantação

**Basta executar os scripts SQL e iniciar o desenvolvimento do firmware e backend!**
