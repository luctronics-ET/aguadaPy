# Sistema de Provisioning WiFi - Gateway Aguada V2.5

## 🎯 Objetivo

Implementar um sistema completo de configuração WiFi via portal web para o gateway ESP32-C3, eliminando a necessidade de hardcoding de credenciais e permitindo configuração "plug-and-play".

## ✅ Implementação Completa

### 📦 Novos Módulos Criados

#### 1. **Config Manager** (`config_manager.c/h`)
- Gerenciamento de configurações em NVS (Non-Volatile Storage)
- Funções para salvar/carregar WiFi SSID, senha, URL backend, porta
- Factory reset para limpar configurações
- Verificação de estado de configuração

**APIs Principais:**
```c
esp_err_t config_manager_init(void);
esp_err_t config_manager_load(gateway_config_t *config);
esp_err_t config_manager_save(const gateway_config_t *config);
esp_err_t config_manager_reset(void);
bool config_manager_is_configured(void);
esp_err_t config_manager_save_wifi(const char *ssid, const char *password);
esp_err_t config_manager_save_backend(const char *url, uint16_t port, bool use_https);
esp_err_t config_manager_mark_setup_complete(void);
```

#### 2. **Web Server** (`web_server.c/h`)
- Servidor HTTP na porta 80
- APIs REST para configuração
- Captive portal (redireciona todas URLs para setup)
- Páginas HTML embedded no firmware

**Endpoints:**
- `GET /` - Página principal do portal
- `GET /api/scan` - Scanner de redes WiFi (retorna JSON)
- `GET /api/discover` - mDNS discovery de servidores Aguada
- `GET /api/status` - Status atual do gateway
- `POST /api/save` - Salvar configuração (WiFi + Backend)
- `POST /api/reset` - Factory reset

#### 3. **DNS Server** (`dns_server.c/h`)
- Servidor DNS na porta 53
- Responde TODAS as queries com IP do gateway (192.168.4.1)
- Implementação captive portal (Android/iOS auto-detectam)

#### 4. **Interface Web** (`www/index.html`)
- Design moderno com gradiente roxo
- Wizard de 3 passos:
  1. Configuração WiFi (com scanner de redes)
  2. Configuração Backend (com mDNS discovery)
  3. Confirmação e salvamento
- Totalmente responsivo
- Feedback visual de loading/sucesso/erro

### 🔄 Modificações em Arquivos Existentes

#### **main.c**
- Adicionados includes dos novos módulos
- Removido hardcoding de redes WiFi
- Implementada lógica de boot dual:
  - **Modo Setup**: Sem configuração → AP puro + Web server + DNS server
  - **Modo Normal**: Configurado → APSTA + ESP-NOW + HTTP backend
- Nova função `init_wifi_setup_mode()` para AP puro
- Nova função `init_wifi_normal_mode()` para APSTA com config NVS
- Variável global `setup_mode` controla comportamento
- Backend URL agora vem de `g_config.backend.url` (NVS)

#### **CMakeLists.txt** (main/)
- Adicionados novos arquivos fonte: `config_manager.c`, `web_server.c`, `dns_server.c`
- Novos componentes: `esp_http_server`, `mdns`, `lwip`
- Embedded file: `www/index.html` (compilado no firmware)

## 🚀 Fluxo de Operação

### Primeira Inicialização (Sem Config)

```
1. ESP32-C3 liga
2. NVS vazio → config_manager_load() retorna ESP_ERR_NOT_FOUND
3. setup_mode = true
4. WiFi inicia em modo AP puro (AGUADA-SETUP)
5. Web server inicia na porta 80
6. DNS server inicia na porta 53 (captive portal)
7. Usuário conecta ao WiFi AGUADA-SETUP
8. Navegador redireciona automaticamente para http://192.168.4.1
9. Usuário configura WiFi e Backend via wizard
10. POST /api/save → Salva config em NVS
11. Gateway reinicia automaticamente
```

### Operação Normal (Configurado)

```
1. ESP32-C3 liga
2. NVS contém config → config_manager_load() retorna ESP_OK
3. setup_mode = false
4. WiFi inicia em modo APSTA:
   - AP: AGUADA-SETUP (acesso local)
   - STA: Conecta à rede WiFi salva
5. ESP-NOW inicializado (recebe dados dos sensors)
6. Tasks iniciadas (espnow_task, status_task)
7. Envia dados para backend configurado via HTTP POST
```

### Reconfiguração

```
Opção 1: Via API REST
  curl -X POST http://192.168.4.1/api/reset
  → Gateway limpa NVS e reinicia em modo setup

Opção 2: Via Serial
  pio run --target erase_flash
  → Apaga toda flash (incluindo NVS)
```

## 📊 Estrutura de Dados

### NVS Schema

| Namespace | Chave | Tipo | Descrição |
|-----------|-------|------|-----------|
| aguada_gtw | wifi_ssid | string[32] | Nome da rede WiFi |
| aguada_gtw | wifi_pass | string[64] | Senha WiFi |
| aguada_gtw | wifi_conf | uint8 | Flag: WiFi configurado |
| aguada_gtw | backend_url | string[128] | URL completa do backend |
| aguada_gtw | backend_port | uint16 | Porta do servidor |
| aguada_gtw | backend_https | uint8 | Flag: usar HTTPS |
| aguada_gtw | setup_done | uint8 | Flag: setup completo |

### Estruturas C

```c
typedef struct {
    char ssid[MAX_SSID_LEN];      // 32 bytes
    char password[MAX_PASSWORD_LEN]; // 64 bytes
    bool configured;
} wifi_config_data_t;

typedef struct {
    char url[MAX_URL_LEN];  // 128 bytes
    uint16_t port;
    bool use_https;
} backend_config_data_t;

typedef struct {
    wifi_config_data_t wifi;
    backend_config_data_t backend;
    bool setup_complete;
} gateway_config_t;
```

## 🔒 Segurança

### Proteções Implementadas
- ✅ AP com senha WPA2 (aguada2025)
- ✅ Validação de JSON no POST /api/save
- ✅ Tamanho máximo de strings (evita buffer overflow)
- ✅ Commit atômico no NVS (transacional)

### Melhorias Futuras
- [ ] HTTPS para web server (TLS/SSL)
- [ ] Autenticação por token na API REST
- [ ] Rate limiting para APIs
- [ ] Criptografia de senha WiFi no NVS

## 📡 Comunicação com Backend

### Formato JSON (Enviado ao Backend)

```json
{
  "mac_address": "AA:BB:CC:DD:EE:FF",
  "readings": [
    {
      "sensor_id": 1,
      "distance_cm": 50
    }
  ],
  "sequence": 123,
  "rssi": -45
}
```

**Compatível com:**
- `api_gateway.php` (formato antigo e novo)
- `api_gateway_v2.php` (formato novo)

## 🧪 Como Testar

### 1. Compilar e Gravar

```bash
cd /opt/lampp/htdocs/aguada/firmware/gateway_wifi

# Compilar
pio run

# Gravar (primeira vez - apaga NVS)
pio run --target erase_flash
pio run --target upload

# Monitor serial
pio device monitor
```

### 2. Conectar ao Portal

```bash
# No smartphone ou notebook:
1. WiFi → Conectar a "AGUADA-SETUP"
2. Senha: aguada2025
3. Navegador abrirá automaticamente
   (ou acesse http://192.168.4.1)
```

### 3. Testar APIs

```bash
# Executar script de teste
cd /opt/lampp/htdocs/aguada/firmware/gateway_wifi
./test_portal.sh

# Ou manualmente:
curl http://192.168.4.1/api/status
curl http://192.168.4.1/api/scan
curl http://192.168.4.1/api/discover

# Salvar config (exemplo)
curl -X POST http://192.168.4.1/api/save \
  -H "Content-Type: application/json" \
  -d '{
    "wifi_ssid": "MinhaRede",
    "wifi_pass": "senha123",
    "backend_url": "http://192.168.0.101/aguada/api_gateway.php",
    "backend_port": 80
  }'
```

## 📝 Logs Esperados

### Boot em Modo Setup
```
I (312) GATEWAY: 🌊 CMASM - Aguada V2.5 - Gateway
I (323) CONFIG_MGR: ✅ Config Manager inicializado
W (334) CONFIG_MGR: ⚠️  Gateway não configurado
W (345) GATEWAY: 🔧 Gateway não configurado - entrando em MODO SETUP
I (356) GATEWAY: ✅ WiFi AP: AGUADA-SETUP (Canal 11)
I (367) WEB_SERVER: ✅ Servidor web iniciado
I (378) WEB_SERVER:    Acesse: http://192.168.4.1/
I (389) DNS_SERVER: ✅ DNS server iniciado na porta 53
I (400) DNS_SERVER:    Todas queries → 192.168.4.1 (captive portal)
I (411) GATEWAY: ========================================
I (422) GATEWAY: 📱 MODO SETUP ATIVO
I (433) GATEWAY:    1. Conecte ao WiFi: AGUADA-SETUP
I (444) GATEWAY:    2. Senha: aguada2025
I (455) GATEWAY:    3. Acesse: http://192.168.4.1
I (466) GATEWAY:    4. Configure WiFi e Backend
I (477) GATEWAY: ========================================
```

### Boot em Modo Normal
```
I (312) GATEWAY: 🌊 CMASM - Aguada V2.5 - Gateway
I (323) CONFIG_MGR: ✅ Config Manager inicializado
I (334) CONFIG_MGR: 📥 Configuração carregada:
I (345) CONFIG_MGR:    WiFi: MinhaRede
I (356) CONFIG_MGR:    Backend: http://192.168.0.101/aguada/api_gateway.php:80
I (367) GATEWAY: ✅ Configuração encontrada - MODO NORMAL
I (378) GATEWAY:    WiFi: MinhaRede
I (389) GATEWAY:    Backend: http://192.168.0.101/aguada/api_gateway.php
I (400) GATEWAY: 📡 Iniciando WiFi em MODO NORMAL (APSTA)...
I (411) GATEWAY: ✅ WiFi AP: AGUADA-SETUP (Canal 11)
I (422) GATEWAY: 🔄 Conectando a: MinhaRede
I (5433) GATEWAY: ✅ WiFi conectado! IP: 192.168.0.150
I (5444) GATEWAY:    Rede: MinhaRede
I (5455) GATEWAY: ✅ ESP-NOW inicializado
I (5466) GATEWAY: ✅ Gateway pronto!
```

## 🎨 Interface Web - Capturas

### Tela 1: Configuração WiFi
- Botão "Buscar Redes" → API `/api/scan`
- Lista interativa de redes detectadas
- Campo manual para SSID/senha

### Tela 2: Configuração Backend
- Botão "Buscar Servidores" → API `/api/discover`
- Campo URL (auto-preenchido se encontrado)
- Campo porta (padrão: 80)

### Tela 3: Confirmação
- Resumo visual das configurações
- Botão "Salvar e Reiniciar"
- Gateway reinicia em 2 segundos após salvamento

## 🔧 Configurações Customizáveis

### WiFi AP (main/main.c)
```c
#define WIFI_AP_SSID "AGUADA-SETUP"
#define WIFI_AP_PASSWORD "aguada2025"
#define WIFI_AP_MAX_CONNECTIONS 4
#define WIFI_CHANNEL 11
```

### Timeouts
```c
#define WIFI_CONNECT_TIMEOUT_MS 15000  // 15s para conectar ao WiFi
#define HTTP_TIMEOUT_MS 5000           // 5s para HTTP request
```

### NVS
```c
#define NVS_NAMESPACE "aguada_gtw"  // Namespace das configurações
```

## 📚 Dependências ESP-IDF

- `nvs_flash` - Non-volatile storage
- `esp_wifi` - WiFi driver
- `esp_netif` - Network interface
- `esp_http_client` - HTTP client (envio para backend)
- `esp_http_server` - HTTP server (portal web)
- `esp_timer` - Timers
- `json` - cJSON library
- `mdns` - mDNS service discovery
- `lwip` - TCP/IP stack (DNS server)

## 🚀 Próximos Passos

### Melhorias Planejadas

1. **mDNS Discovery Real**
   - Implementar query assíncrona
   - Listar múltiplos servidores
   - Auto-seleção do servidor mais próximo

2. **OTA (Over-The-Air Update)**
   - Upload de firmware via web
   - Rollback automático em caso de falha

3. **Múltiplas Redes WiFi**
   - Salvar até 5 redes com prioridade
   - Failover automático entre redes

4. **Dashboard de Diagnóstico**
   - Visualizar dados ESP-NOW em tempo real
   - Gráficos de RSSI dos sensores
   - Histórico de conexões

5. **HTTPS**
   - Certificados SSL/TLS
   - Backend seguro

## 📄 Arquivos Modificados/Criados

### ✨ Novos Arquivos
```
gateway_wifi/
├── main/
│   ├── config_manager.c        [NOVO]
│   ├── config_manager.h        [NOVO]
│   ├── web_server.c            [NOVO]
│   ├── web_server.h            [NOVO]
│   ├── dns_server.c            [NOVO]
│   ├── dns_server.h            [NOVO]
│   └── www/
│       └── index.html          [NOVO]
├── README_CONFIGURACAO.md      [NOVO]
└── test_portal.sh              [NOVO]
```

### 🔧 Arquivos Modificados
```
gateway_wifi/
├── main/
│   ├── main.c                  [MODIFICADO]
│   └── CMakeLists.txt          [MODIFICADO]
└── CMakeLists.txt              [MODIFICADO]
```

## ✅ Checklist de Funcionalidades

- [x] Persistência de configurações em NVS
- [x] Portal web com captive portal
- [x] WiFi scanner
- [x] DNS server (redireciona tudo para 192.168.4.1)
- [x] API REST completa (/scan, /discover, /save, /reset, /status)
- [x] Interface web responsiva
- [x] Modo dual (Setup / Normal)
- [x] Factory reset via API
- [x] Reinicialização automática após config
- [x] Logs detalhados
- [x] Script de teste
- [x] Documentação completa
- [ ] mDNS discovery funcional (placeholder implementado)
- [ ] OTA update
- [ ] HTTPS

---

**Versão:** 2.5  
**Data:** 28 de Outubro de 2025  
**Autor:** Assistente GitHub Copilot  
**Sistema:** Aguada - CMASM
