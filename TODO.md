# TODO List - Sistema Supervisório Hídrico IoT

## 📋 Status Geral
- **Projeto**: Sistema CMMS/BMS Hídrico com IoT
- **Fase Atual**: Desenvolvimento Inicial
- **Data Início**: 2025-10-30
- **Última Atualização**: 2025-10-30

---

## ✅ CONCLUÍDO

### Fase 0: Planejamento e Arquitetura
- [x] Definição do modelo conceitual do sistema
- [x] Modelagem de dados (ER Diagram)
- [x] Especificação de requisitos funcionais
- [x] Análise de hardware IoT (ESP32-C3, sensores)
- [x] Definição de protocolos de comunicação
- [x] Criação de schema SQL PostgreSQL completo
- [x] Implementação de funções PL/pgSQL
- [x] Configuração de triggers automáticos
- [x] Dados de exemplo (seeds.sql)
- [x] Documentação inicial (README.md)

---

## 🚧 EM ANDAMENTO

### Nenhuma tarefa em andamento no momento

---

## 📝 PENDENTE

### FASE 1: Infraestrutura de Banco de Dados (Prioridade: ALTA)

#### 1.1 Setup PostgreSQL
- [ ] Instalar PostgreSQL 13+ em servidor/local
- [ ] Criar banco de dados `aguada_cmms`
- [ ] Executar `schema.sql`
- [ ] Executar `functions.sql`
- [ ] Executar `triggers.sql`
- [ ] Executar `seeds.sql` para dados de teste
- [ ] Configurar backup automático diário
- [ ] Testar função `proc_process_sensor_window()`
- [ ] Testar função `detectar_eventos()`
- [ ] Validar triggers em ambiente de testes

**Estimativa**: 3-4 dias  
**Responsável**: DBA / DevOps  
**Dependências**: Servidor disponível

---

### FASE 2: Hardware IoT (Prioridade: ALTA)

#### 2.1 Aquisição de Componentes
- [ ] Comprar 6× ESP32-C3 Super Mini (R$ 90)
- [ ] Comprar 6× HC-SR04 (ultrassom) (R$ 48)
- [ ] Comprar 6× Fonte 5V 2A (R$ 60)
- [ ] Comprar 2× Arduino Nano (backup) (R$ 50)
- [ ] Comprar cabos, conectores, cases (R$ 120)
- [ ] Comprar 2× sensor de pressão MPX5700 (R$ 70)

**Budget Total**: ~R$ 438  
**Fornecedor Sugerido**: MercadoLivre, AliExpress, Baú da Eletrônica

#### 2.2 Desenvolvimento de Firmware ESP32
**Hardware Disponível**: ✅ 2x ESP32+ultrassom, ✅ Nano+Eth+Ultra, ✅ Gateway ESP32-C3 Super Mini, ✅ ESP8266+ENC28J60, ⚡ Pico+ESP+Eth (backup)

**Fonte de Firmwares**: `/opt/lampp/htdocs/aguada/firmware/` (SOMENTE LEITURA - copiar, não modificar)

- [ ] Copiar firmwares relevantes de `/aguada/firmware/` para `/aguadaPy/firmware_nodes/`
- [ ] Adaptar firmware node_02-cav (ESP32 + HC-SR04) para API aguadaPy
- [ ] Configurar ambiente PlatformIO / Arduino IDE
- [ ] Implementar leitura de sensor HC-SR04 - biblioteca NewPing
- [ ] Implementar cálculo de mediana (11 amostras)
- [ ] Implementar envio WiFi para servidor (HTTP POST)
- [ ] Implementar ESP-NOW (mesh)
- [ ] Implementar deep sleep (economia de energia)
- [ ] Implementar buffer local (100 últimas leituras)
- [ ] Implementar watchdog timer
- [ ] Implementar OTA (update firmware over-the-air)
- [ ] Testes de bancada com sensor real

- [ ] Documentar pinout e configuração

**Estimativa**: 5-7 dias  
**Responsável**: Desenvolvedor Embedded  
**Arquivos**: `/firmware/esp32_nivel/`

#### 2.3 Instalação Física
- [ ] Projetar suporte para sensor (evitar interferências)
- [ ] Instalar sensor no RES_CONS (piloto)
- [ ] Instalar sensor no RES_INC
- [ ] Calibrar sensores com régua física
- [ ] Testar comunicação WiFi in-loco
- [ ] Medir intensidade do sinal WiFi
- [ ] Instalar fonte de alimentação (ou solar)
- [ ] Proteção contra intempéries (IP65)
- [ ] Aterramento e proteção elétrica

**Estimativa**: 3-4 dias  
**Responsável**: Técnico de Campo

---

### FASE 3: Backend / API REST (Prioridade: ALTA)

#### 3.1 Setup Ambiente Backend com Docker 🐳
**Deploy**: Sistema roda em PC local (rede local apenas), transferência via pendrive

- [ ] Criar `docker-compose.yml` (PostgreSQL + Backend + Frontend)
- [ ] Criar `Dockerfile` para backend (Node.js ou Python)
- [ ] Criar `Dockerfile` para frontend (Nginx + build estático)
- [ ] Escolher stack (Node.js Express OU Python FastAPI)
- [ ] Configurar estrutura de pastas
- [ ] Configurar variáveis de ambiente (.env)
- [ ] Conectar ao PostgreSQL (pg-promise / psycopg2)
- [ ] Implementar autenticação JWT
- [ ] Implementar middleware de log
- [ ] Script de backup/restore para transferência via pendrive

**Estimativa**: 3 dias  
**Responsável**: Backend Developer

#### 3.2 Endpoints API
- [ ] POST `/api/leituras/raw` - Receber leituras dos sensores
- [ ] GET `/api/leituras/processadas` - Consultar histórico comprimido
- [ ] GET `/api/elementos` - Listar todos os elementos
- [ ] GET `/api/elementos/:id` - Detalhe de elemento
- [ ] GET `/api/eventos` - Listar eventos detectados
- [ ] GET `/api/relatorio/:data` - Relatório diário
- [ ] POST `/api/calibracao` - Registrar calibração manual
- [ ] PUT `/api/atuadores/:id` - Alterar estado de bomba/válvula
- [ ] GET `/api/dashboard/resumo` - Resumo para dashboard
- [ ] GET `/api/mapa/elementos` - Dados para visualização no mapa
- [ ] WebSocket `/ws/realtime` - Stream de dados em tempo real

**Estimativa**: 5-7 dias  
**Responsável**: Backend Developer  
**Arquivos**: `/backend/src/api/`

#### 3.3 Segurança
- [ ] Implementar rate limiting (proteção DDoS)
- [ ] Validação de inputs (SQL injection, XSS)
- [ ] HTTPS obrigatório em produção
- [ ] Logs de auditoria (quem fez o quê, quando)
- [ ] Backup automático de banco (cron diário)

**Estimativa**: 2 dias

---

### FASE 4: Frontend / Dashboard (Prioridade: MÉDIA)

#### 4.1 Setup Frontend
- [ ] Escolher framework (React / Vue.js / Svelte)
- [ ] Configurar bundler (Vite / Webpack)
- [ ] Estrutura de componentes
- [ ] Configurar Tailwind CSS / Material UI
- [ ] Configurar roteamento
- [ ] Integração com API (axios / fetch)

**Estimativa**: 2 dias  
**Responsável**: Frontend Developer

#### 4.2 Páginas Principais
- [ ] **Dashboard**: visão geral (níveis, estados, alertas)
- [ ] **Mapa Interativo**: visualização espacial (Leaflet.js)
- [ ] **Histórico**: gráficos de nível/consumo (Chart.js)
- [ ] **Eventos**: lista de eventos detectados
- [ ] **Calibração**: interface para leituras manuais
- [ ] **Relatórios**: visualização de relatórios diários
- [ ] **Configurações**: ajuste de deadband, usuários
- [ ] **Login/Autenticação**: tela de login

**Estimativa**: 7-10 dias  
**Arquivos**: `/frontend/src/pages/`

#### 4.3 Mapa Interativo
- [ ] Integrar Leaflet.js
- [ ] Renderizar elementos com coordenadas
- [ ] Desenhar conexões hidráulicas (linhas)
- [ ] Cores por estado (verde=OK, vermelho=crítico)
- [ ] Tooltip com informações ao passar mouse
- [ ] Popup com detalhes ao clicar
- [ ] Filtros por tipo de elemento
- [ ] Zoom e pan suaves
- [ ] Layers (planta térreo, subsolo, cobertura)

**Estimativa**: 4 dias

#### 4.4 Gráficos e Visualizações
- [ ] Gráfico de nível ao longo do tempo
- [ ] Gráfico de consumo diário (bar chart)
- [ ] Indicadores de status (gauges)
- [ ] Timeline de eventos
- [ ] Heatmap de vazamentos

**Estimativa**: 3 dias

---

### FASE 5: Lógica de Negócio (Prioridade: ALTA)

#### 5.1 Detecção de Eventos
- [ ] Refinar algoritmo de detecção de ABASTECIMENTO
- [ ] Refinar algoritmo de detecção de VAZAMENTO
- [ ] Implementar correlação com estados de bombas/válvulas
- [ ] Implementar detecção de CONSUMO ANORMAL
- [ ] Implementar detecção de FALHA DE SENSOR
- [ ] Testes com dados reais (7 dias contínuos)
- [ ] Ajuste de thresholds (deadband, taxa variação)

**Estimativa**: 4-5 dias  
**Responsável**: Data Analyst / Backend

#### 5.2 Relatório Diário Automático
- [ ] Criar job agendado (cron) para 06:00
- [ ] Executar função `gerar_relatorio_diario()`
- [ ] Gerar PDF do relatório (wkhtmltopdf / Puppeteer)
- [ ] Enviar por email (nodemailer / sendmail)
- [ ] Enviar notificação Telegram (opcional)
- [ ] Armazenar PDF em pasta compartilhada
- [ ] Log de execução

**Estimativa**: 3 dias  
**Arquivos**: `/backend/src/jobs/relatorio_diario.js`

#### 5.3 Sistema de Alertas
- [ ] Detectar níveis críticos (< 20%, > 95%)
- [ ] Enviar email para equipe técnica
- [ ] Enviar mensagem Telegram/WhatsApp
- [ ] Gerar ticket no CMMS (se integrado)
- [ ] Log de alertas enviados
- [ ] Configuração de destinatários

**Estimativa**: 2 dias

---

### FASE 6: Calibração e Manutenção (Prioridade: MÉDIA)

#### 6.1 Interface de Calibração
- [ ] Formulário para inserir leitura manual
- [ ] Campo para foto do hidrômetro (upload)
- [ ] Comparação sensor vs. manual
- [ ] Cálculo automático de offset/fator
- [ ] Aplicar calibração ao sensor
- [ ] Histórico de calibrações
- [ ] Alerta de próxima calibração (3 meses)

**Estimativa**: 3 dias  
**Arquivos**: `/frontend/src/pages/Calibracao.jsx`

#### 6.2 Manutenção Preventiva
- [ ] Cadastro de equipamentos (bombas, válvulas)
- [ ] Registro de manutenções realizadas
- [ ] Agendamento de manutenções futuras
- [ ] Alertas de manutenção programada
- [ ] Histórico de falhas

**Estimativa**: 4 dias

---

### FASE 7: Testes e Validação (Prioridade: ALTA)

#### 7.1 Testes Unitários
- [ ] Testes de funções PL/pgSQL (pgTAP)
- [ ] Testes de API (Jest / Mocha)
- [ ] Testes de componentes frontend (React Testing Library)
- [ ] Testes de firmware (simulação)
- [ ] Cobertura mínima: 70%

**Estimativa**: 5 dias

#### 7.2 Testes de Integração
- [ ] Teste end-to-end: sensor → API → BD → dashboard
- [ ] Teste de detecção de evento simulado (vazamento)
- [ ] Teste de geração de relatório
- [ ] Teste de calibração
- [ ] Teste de envio de alerta

**Estimativa**: 3 dias

#### 7.3 Testes de Campo
- [ ] Monitoramento contínuo por 7 dias
- [ ] Comparação com hidrômetro (erro < 5%)
- [ ] Validação de eventos detectados
- [ ] Teste de queda de rede (fallback ESP-NOW)
- [ ] Teste de falta de energia (bateria backup)

**Estimativa**: 7 dias (período de observação)

---

### FASE 8: Documentação (Prioridade: MÉDIA)

#### 8.1 Documentação Técnica
- [ ] Diagrama de arquitetura
- [ ] Documentação da API (Swagger / OpenAPI)
- [ ] Documentação do firmware
- [ ] Guia de instalação
- [ ] Guia de troubleshooting

**Estimativa**: 4 dias  
**Arquivos**: `/docs/`

#### 8.2 Manuais de Operação
- [ ] Manual do operador (uso diário)
- [ ] Manual de calibração
- [ ] Procedimentos de emergência
- [ ] FAQ (perguntas frequentes)

**Estimativa**: 3 dias

---

### FASE 9: Deploy e Produção (Prioridade: ALTA)

#### 9.1 Preparação para Deploy via Pendrive 💾
**Ambiente**: PC local isolado (sem internet), apenas rede local

- [ ] Instalar Docker + Docker Compose no PC de destino
- [ ] Criar script `deploy.sh` (iniciar containers)
- [ ] Criar script `backup.sh` (exportar banco + volumes Docker)
- [ ] Criar script `restore.sh` (importar de pendrive)
- [ ] Testar transferência completa via pendrive
- [ ] Documentar IPs fixos da rede local
- [ ] Configurar firewall local (liberar portas 80, 5432, 3000)

**Estimativa**: 2 dias

#### 9.2 Deploy com Docker
- [ ] Copiar projeto completo para pendrive
- [ ] No PC destino: `docker-compose up -d`
- [ ] Executar scripts SQL (via container PostgreSQL)
- [ ] Verificar conectividade ESP32 → API (rede local)
- [ ] Testes em produção
- [ ] Rollback plan (manter imagens Docker antigas)

**Estimativa**: 1 dia

#### 9.3 Monitoramento Pós-Deploy
- [ ] Logs centralizados (ELK / Loki)
- [ ] Alertas de uptime (UptimeRobot)
- [ ] Monitoramento de recursos (CPU, RAM, disco)
- [ ] Backup automático testado

**Estimativa**: 2 dias

---

### FASE 10: Expansões Futuras (Prioridade: BAIXA)

#### 10.1 Machine Learning
- [ ] Coletar dataset (6 meses de dados)
- [ ] Treinar modelo de predição de vazamentos
- [ ] Treinar modelo de predição de consumo
- [ ] Implementar alertas preditivos
- [ ] Dashboard de insights (BI)

**Estimativa**: 15+ dias

#### 10.2 Integrações
- [ ] Integração com ERP (SAP, TOTVS)
- [ ] Integração com sistema financeiro
- [ ] Integração com WhatsApp Business API
- [ ] Integração com sistema de tickets

**Estimativa**: 10 dias por integração

#### 10.3 Mobile App
- [ ] App nativo (React Native / Flutter)
- [ ] Notificações push
- [ ] Visualização de mapas
- [ ] Controle remoto de atuadores

**Estimativa**: 20 dias

---

## 📊 Resumo de Estimativas

| Fase | Dias | Status |
|------|------|--------|
| Fase 0: Planejamento | 3 | ✅ Concluído |
| Fase 1: Banco de Dados | 4 | 📝 Pendente |
| Fase 2: Hardware IoT | 12 | 📝 Pendente |
| Fase 3: Backend/API | 12 | 📝 Pendente |
| Fase 4: Frontend | 17 | 📝 Pendente |
| Fase 5: Lógica de Negócio | 9 | 📝 Pendente |
| Fase 6: Calibração | 7 | 📝 Pendente |
| Fase 7: Testes | 15 | 📝 Pendente |
| Fase 8: Documentação | 7 | 📝 Pendente |
| Fase 9: Deploy | 7 | 📝 Pendente |
| **TOTAL (MVP)** | **~93 dias** | **≈ 4.5 meses** |

---

## 🎯 Próximos Passos Imediatos (Esta Semana)

1. **Instalar PostgreSQL e criar banco de dados**
2. **Executar todos os scripts SQL**
3. **Testar funções de processamento com dados de exemplo**
4. **Comprar componentes IoT (ESP32 + sensores)**
5. **Configurar ambiente de desenvolvimento (backend)**

---

## 📝 Notas e Decisões Técnicas

### Decisões de Arquitetura
- **Banco**: PostgreSQL (escalável, triggers, JSON support)
- **Backend**: Node.js Express (opção 1) ou Python FastAPI (opção 2)
- **Frontend**: React + Vite (moderno, rápido)
- **IoT**: ESP32-C3 (baixo custo, WiFi integrado)
- **Mapa**: Leaflet.js (open source, leve)

### Riscos Identificados
- **Ruído de sensores ultrassônicos** → Mitigação: mediana de 11 amostras
- **Queda de WiFi** → Mitigação: buffer local + ESP-NOW mesh
- **Falso positivo em vazamento** → Mitigação: correlação com bombas/válvulas
- **Deriva de calibração** → Mitigação: calibração trimestral obrigatória

---

## 📞 Contatos

**Responsável Técnico**: [Nome]  
**Email**: [email]  
**Telegram**: @[usuario]

---

**Última atualização**: 2025-10-30  
**Próxima revisão**: [data]
