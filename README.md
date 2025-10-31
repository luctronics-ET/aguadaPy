# Sistema Supervisório Hídrico IoT - CMMS/BMS Água

## Visão Geral

Sistema inteligente de monitoramento e gestão de rede hídrica com foco em:
- **Redução de dados** através de compressão inteligente (delta logging + deadband filtering)
- **Detecção automática** de eventos (abastecimento, consumo, vazamento)
- **Rastreabilidade completa** (sensor/usuário/sistema + timestamp)
- **Visualização espacial** com mapas interativos
- **Relatórios diários** automáticos às 06:00

## Características do Sistema

### Infraestrutura Atual
- **6 reservatórios** (consumo, incêndio, elevados)
- **5-10 bombas** de recalque
- **~20 válvulas** de controle
- **Sensores ultrassônicos** (ESP32) lendo a cada 30s
- **Leituras manuais** de hidrômetros

### Tecnologias Principais

#### Hardware IoT
- **ESP32-C3 Super Mini**: baixo custo, WiFi integrado, ideal para sensores distribuídos
- **Arduino Nano**: controle de atuadores e sensores secundários
- **Sensores**: HC-SR04 (ultrassom), sensores de pressão, vazão

#### Protocolos de Comunicação
- **ESP-NOW**: comunicação mesh entre dispositivos, baixa latência
- **WiFi**: envio de dados ao servidor central
- **Ethernet**: conexão redundante para sistemas críticos
- **I²C/1-Wire**: comunicação com sensores locais

#### Backend
- **PostgreSQL 13+** com extensões:
  - **TimescaleDB**: otimização para séries temporais
  - **PostGIS**: suporte geoespacial (opcional)
- **PL/pgSQL**: lógica de compressão e processamento
- **Node.js/Python**: API REST e processamento assíncrono

#### Frontend
- **Leaflet.js**: mapas interativos com posicionamento de elementos
- **Chart.js/D3.js**: gráficos em tempo real
- **WebSocket**: atualização live de estados

## Arquitetura de Dados

### Modelo de Compressão Inteligente

#### Camada RAW (leituras_raw)
```sql
- Armazena TODAS as leituras brutas
- Campos: sensor_id, timestamp, valor_bruto, origem
- Preserva histórico completo para auditoria
- Média: 2880 registros/dia por sensor (30s)
```

#### Camada PROCESSADA (leituras_processadas)
```sql
- Armazena apenas MUDANÇAS SIGNIFICATIVAS
- Algoritmo:
  * Calcula mediana de N leituras (padrão: 11)
  * Aplica deadband (tolerância: ±2cm ou configurável)
  * Se estável: atualiza timestamp, não cria novo registro
  * Se mudança: insere novo evento
- Redução: ~90% de dados
- Resultado: 5-10 eventos relevantes/dia
```

### Estrutura Principal

```
┌─────────────┐
│  ELEMENTO   │  ← Reservatórios, Bombas, Válvulas
├─────────────┤
│ id          │
│ nome        │
│ tipo        │
│ coord_x/y/z │  ← Posicionamento espacial
│ lat/lon     │  ← Geolocalização
└─────────────┘
      │
      ├──→ CONEXAO (grafo hidráulico)
      ├──→ SENSOR (leituras)
      ├──→ ATUADOR (controle)
      ├──→ ESTADO_ELEMENTO (histórico)
      └──→ COORDENADA (visualização)
```

## Eventos Detectados Automaticamente

### 1. ABASTECIMENTO
```
Condições:
- ΔVolume > +50L
- Bomba = ON
- Válvula entrada = ABERTA
Ação: Registra início, fim, volume total, duração
```

### 2. VAZAMENTO
```
Condições:
- Queda lenta contínua (> 1h)
- Bombas = OFF
- Válvulas consumo = FECHADAS
- Taxa > limiar (ex: -15 L/h)
Ação: Alerta, cálculo de perda estimada
```

### 3. CONSUMO
```
Condições:
- Queda correlacionada com demanda
- Bombas consumo = ON ou padrão horário
Ação: Registra volume consumido
```

### 4. SENSOR RUIDOSO
```
Condições:
- Oscilação > 3× desvio padrão normal
- Valores fora do range físico
Ação: Marca para calibração
```

## Fluxo de Dados

```
[ESP32] --30s--> [leituras_raw] --trigger--> [proc_process_sensor_window()]
                                                    │
                                                    ├─ calcula mediana
                                                    ├─ verifica deadband
                                                    ├─ detecta eventos
                                                    └─ atualiza [leituras_processadas]
                                                           │
                                                           └─> [Dashboard em Tempo Real]
                                                           └─> [Relatório Diário 06:00]
```

## Funcionalidades Principais

### 1. Monitoramento em Tempo Real
- Níveis de todos os reservatórios
- Estados de bombas e válvulas
- Alertas instantâneos
- Histórico de eventos

### 2. Mapa Interativo
- Visualização espacial de todos os elementos
- Cores por estado (verde=OK, amarelo=alerta, vermelho=crítico)
- Conexões hidráulicas desenhadas
- Clique para detalhes e histórico

### 3. Rastreabilidade Total
```sql
Cada registro contém:
- fonte: 'sensor' | 'usuario' | 'sistema'
- autor: identificação (node_id, username, processo)
- datetime: timestamp preciso
- modo: 'automatica' | 'manual'
```

### 4. Calibração
- Interface para leitura manual
- Comparação sensor vs. régua física
- Ajuste de offset e fator
- Log de calibrações

### 5. Relatório Diário (06:00)
```
Conteúdo:
- Volume total consumido
- Volume total abastecido
- Eventos detectados
- Anomalias e alertas
- Níveis mín/máx de cada reservatório
- Tempo de operação de bombas
- Perda estimada (vazamentos)

Formato: PDF + email + inserção em BD
```

## 🐳 Deploy com Docker

O sistema está pronto para deploy via Docker! Veja o **[DOCKER_GUIDE.md](DOCKER_GUIDE.md)** para instruções completas.

### Deploy Rápido (PC isolado via pendrive)

```bash
# No PC atual (desenvolvimento)
./backup.sh /media/pendrive

# Copie para o PC de destino e execute
./restore.sh aguada_backup_YYYYMMDD_HHMMSS.tar.gz

# Pronto! Sistema rodando em:
# - Dashboard: http://localhost
# - API: http://localhost:3000
# - PostgreSQL: localhost:5432
```

### Gerenciar Sistema

```bash
./deploy.sh start    # Iniciar
./deploy.sh stop     # Parar
./deploy.sh restart  # Reiniciar
./deploy.sh logs     # Ver logs
./deploy.sh status   # Status dos containers
```

## 📡 Firmwares Disponíveis

Hardware já disponível (sem necessidade de compra):
- ✅ 2× ESP32 + HC-SR04 ultrassom
- ✅ 1× Arduino Nano + Ethernet + HC-SR04
- ✅ 1× ESP32-C3 Super Mini (gateway WiFi)
- ✅ 1× ESP8266 + ENC28J60 (gateway backup)

Firmwares prontos em `/opt/lampp/htdocs/aguada/firmware/` (**somente leitura**):
- **NODE-01-CON**: ESP32 com ESP-NOW (nós remotos)
- **NODE-02-CAV**: Arduino Nano + Ethernet (crítico)
- **GATEWAY_WIFI**: ESP32 gateway (WiFi + ESP-NOW)

📖 Veja **[FIRMWARES_DISPONIVEIS.md](FIRMWARES_DISPONIVEIS.md)** para detalhes completos.

## 🎯 Próximos Passos

1. **Instalar Docker no PC de destino** (se não tiver)
2. **Executar `./deploy.sh start`** (inicia PostgreSQL + Backend + Frontend)
3. **Copiar e adaptar firmwares** de `/aguada/firmware/` (apenas URLs/IPs)
4. **Configurar ESP32** com IP do servidor Docker
5. **Testar conectividade** sensor → API

## Estratégia de Desenvolvimento IoT

### Hardware Selecionado

| Dispositivo | Uso | Protocolo | Custo Aprox |
|-------------|-----|-----------|-------------|
| ESP32-C3 Super Mini | Sensores nivel | WiFi/ESP-NOW | R$ 15 |
| Arduino Nano | Controle local | I²C/1-Wire | R$ 25 |
| HC-SR04 | Ultrassom | Digital | R$ 8 |
| Sensor Pressão | Rede | Analógico | R$ 35 |

### Topologia de Rede

```
          [Servidor Central]
               │ WiFi
    ┌──────────┼──────────┐
    │          │          │
[ESP32_RES1] [ESP32_RES2] [ESP32_RES3]
    │ESP-NOW   │ESP-NOW   │
[ESP32_RES4] [ESP32_RES5] [ESP32_RES6]
```

### Firmware: Recursos

#### Medição Robusta
```cpp
// Mediana de 11 leituras para filtrar ruído
float mediana = calcularMediana(leituras, 11);

// Enviar apenas se mudança > deadband
if (abs(mediana - ultimaLeitura) > DEADBAND) {
    enviarDados(mediana);
}
```

#### Economia de Energia
- Deep sleep entre leituras (30s)
- Wake on timer
- Consumo: ~5mA em sleep, ~80mA ativo

#### Redundância
- Fallback WiFi → ESP-NOW
- Buffer local (últimas 100 leituras)
- Ressincronização automática

## Plano de Testes

### Fase 1: Unitários
- [ ] Função de mediana
- [ ] Algoritmo de deadband
- [ ] Detecção de eventos
- [ ] Triggers SQL

### Fase 2: Integração
- [ ] ESP32 → API → BD
- [ ] Compressão automática
- [ ] Geração de relatório
- [ ] Calibração manual

### Fase 3: Campo
- [ ] 7 dias de monitoramento contínuo
- [ ] Validação de vazamentos detectados
- [ ] Comparação hidrômetro vs. sensor
- [ ] Stress test (1000 leituras simultâneas)

## Implantação

### Cronograma Sugerido

| Semana | Atividade |
|--------|-----------|
| 1-2 | Setup banco de dados + API básica |
| 3 | Firmware ESP32 + testes bancada |
| 4 | Instalação de 2 sensores piloto |
| 5-6 | Dashboard e visualização |
| 7 | Sistema de eventos e relatórios |
| 8 | Implantação completa (6 reservatórios) |
| 9+ | Monitoramento e ajustes finos |

## Manutenção

### Preventiva
- **Mensal**: Verificação física de sensores
- **Trimestral**: Calibração com régua
- **Semestral**: Limpeza de sensores ultrassônicos

### Corretiva
- Alertas automáticos por email/Telegram
- Dashboard de saúde dos sensores
- Log de erros centralizado

## Escalabilidade

### Atual (6 reservatórios)
- Banco: PostgreSQL 13 em servidor local
- Storage: ~500 MB/ano (com compressão)
- CPU: mínimo (triggers leves)

### Expansão (50+ reservatórios)
- Migrar para TimescaleDB
- Particionamento por mês
- Compressão nativa TimescaleDB
- Cluster multi-node (se necessário)

## Análise de Custos

### Hardware (estimativa para 6 reservatórios)
```
6× ESP32-C3 Super Mini        = R$ 90
6× Sensor HC-SR04            = R$ 48
6× Fonte 5V + case           = R$ 120
Cabeamento e conectores      = R$ 80
                    TOTAL    = R$ 338
```

### Software
- PostgreSQL: gratuito (open source)
- Backend Node.js: gratuito
- Frontend: gratuito
- Servidor: existente

### Economia Estimada
- Redução de 90% em armazenamento
- Detecção precoce de vazamentos → economia de água
- Automatização de relatórios → redução de horas/homem

## Desafios e Soluções

| Desafio | Solução |
|---------|---------|
| Ruído em leituras ultrassônicas | Mediana de 11 amostras + deadband |
| Leituras falsas de vazamento | Correlação com estado de bombas/válvulas |
| Falta de energia em sensores | Deep sleep + buffer local |
| Perda de conectividade WiFi | Fallback ESP-NOW mesh |
| Calibração deriva ao longo do tempo | Interface de calibração manual + log |

## Roadmap Futuro

### Curto Prazo (3 meses)
- [x] Modelo de dados completo
- [ ] Firmware ESP32 funcional
- [ ] API REST básica
- [ ] Dashboard inicial

### Médio Prazo (6 meses)
- [ ] Machine Learning para predição de falhas
- [ ] App mobile (React Native)
- [ ] Integração com sistema de manutenção
- [ ] Alertas inteligentes (Telegram/WhatsApp)

### Longo Prazo (12 meses)
- [ ] Gêmeo digital completo (simulação)
- [ ] Otimização automática de bombas (economia energia)
- [ ] Integração com sistema financeiro (faturamento)
- [ ] Expansão para gestão de energia elétrica

## Estrutura de Diretórios

```
aguadaPy/
├── database/
│   ├── schema.sql              # Estrutura completa do BD
│   ├── functions.sql           # PL/pgSQL (compressão, eventos)
│   ├── triggers.sql            # Triggers automáticos
│   ├── seeds.sql               # Dados de exemplo
│   └── migrations/
├── firmware/
│   ├── esp32_nivel/            # Sensor de nível
│   ├── esp32_gateway/          # Gateway central
│   └── arduino_atuador/        # Controle de bombas/válvulas
├── backend/
│   ├── src/
│   │   ├── api/                # Endpoints REST
│   │   ├── services/           # Lógica de negócio
│   │   ├── models/             # Models do BD
│   │   └── jobs/               # Relatório diário, processamento
│   ├── config/
│   └── tests/
├── frontend/
│   ├── src/
│   │   ├── components/         # Componentes React/Vue
│   │   ├── pages/              # Páginas principais
│   │   ├── services/           # API client
│   │   └── utils/              # Helpers
│   └── public/
├── docs/
│   ├── api.md                  # Documentação da API
│   ├── manual_operacao.md      # Manual do operador
│   └── manual_tecnico.md       # Manual técnico
├── scripts/
│   ├── backup.sh               # Backup automático BD
│   ├── deploy.sh               # Deploy production
│   └── relatorio_diario.py     # Geração de relatório
└── README.md
```

## Contribuindo

Este é um sistema em desenvolvimento contínuo. Sugestões de melhorias:
1. Abrir issue descrevendo o problema/melhoria
2. Fork do projeto
3. Criar branch com feature
4. Pull request com descrição detalhada

## Licença

MIT License - uso livre para fins educacionais e comerciais

## Autores e Contato

**Sistema desenvolvido para gestão hídrica inteligente**

Documentação completa: `/docs`  
Issues: GitHub Issues  
Email: suporte@aguada.local

---

**Versão**: 1.0.0  
**Última atualização**: 2025-10-30  
**Status**: Em desenvolvimento ativo
