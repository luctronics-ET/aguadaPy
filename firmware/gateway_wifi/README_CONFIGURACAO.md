# Gateway WiFi - Aguada V2.5
## Sistema de Configuração via Portal Web

### 📋 Visão Geral

Este firmware do gateway ESP32-C3 agora inclui um **portal de configuração web** completo que permite configurar WiFi e servidor backend sem precisar recompilar o código.

### ✨ Funcionalidades

#### 🔧 Modo Setup (Primeira Inicialização)
- **Captive Portal**: Redireciona automaticamente ao conectar no WiFi
- **WiFi Scanner**: Lista todas as redes WiFi disponíveis
- **mDNS Discovery**: Busca servidores Aguada na rede automaticamente
- **Interface Responsiva**: Design moderno e adaptável
- **Configuração Persistente**: Salvamento em NVS (memória não-volátil)

#### 📡 Modo Normal (Operação)
- **Modo APSTA**: Access Point + Station simultâneos
- **ESP-NOW**: Recebe dados dos sensores
- **HTTP POST**: Envia dados para backend configurado
- **Failover**: Continua funcionando como AP se WiFi cair

### 🚀 Como Usar

#### 1️⃣ Primeira Inicialização

1. **Grave o firmware** no ESP32-C3:
   ```bash
   cd /opt/lampp/htdocs/aguada/firmware/gateway_wifi
   pio run --target upload
   pio device monitor
   ```

2. **Conecte ao WiFi do gateway**:
   - SSID: `AGUADA-SETUP`
   - Senha: `aguada2025`

3. **Acesse o portal**:
   - Seu navegador será redirecionado automaticamente
   - Ou acesse manualmente: `http://192.168.4.1`

4. **Configure em 3 passos**:

   **Passo 1: WiFi**
   - Clique em "📡 Buscar Redes" para listar redes disponíveis
   - Selecione sua rede ou digite manualmente
   - Digite a senha WiFi
   - Clique em "Próximo"

   **Passo 2: Servidor**
   - Clique em "🔍 Buscar Servidores" (auto-detecta via mDNS)
   - Ou digite manualmente:
     - URL: `192.168.0.101/aguada/api_gateway.php`
     - Porta: `80`
   - Clique em "Próximo"

   **Passo 3: Confirmar**
   - Revise as configurações
   - Clique em "✅ Salvar e Reiniciar"

5. **Gateway reinicia automaticamente** e conecta ao WiFi configurado!

#### 2️⃣ Operação Normal

Após configurado:
- Gateway conecta automaticamente ao WiFi salvo
- Recebe dados ESP-NOW dos sensores
- Envia para backend configurado
- Mantém AP local para acesso direto (`AGUADA-SETUP`)

#### 3️⃣ Reconfiguração

Para alterar configurações:

**Opção 1: Via API REST**
```bash
# Reset factory (limpa configurações)
curl -X POST http://192.168.4.1/api/reset

# Gateway reinicia em modo setup
```

**Opção 2: Via Serial**
- Apague a partição NVS manualmente e regrave o firmware

### 📡 APIs Disponíveis

| Endpoint | Método | Descrição |
|----------|--------|-----------|
| `/` | GET | Página principal do portal |
| `/api/scan` | GET | Lista redes WiFi disponíveis |
| `/api/discover` | GET | Busca servidores via mDNS |
| `/api/status` | GET | Status atual do gateway |
| `/api/save` | POST | Salva configuração WiFi/Backend |
| `/api/reset` | POST | Factory reset (limpa config) |

### 📂 Estrutura do Código

```
gateway_wifi/
├── main/
│   ├── main.c              # Lógica principal + ESP-NOW
│   ├── config_manager.c/h  # Persistência NVS
│   ├── web_server.c/h      # Servidor HTTP + APIs
│   ├── dns_server.c/h      # DNS server (captive portal)
│   ├── www/
│   │   └── index.html      # Interface web (embedded)
│   └── CMakeLists.txt      # Build config
├── platformio.ini          # PlatformIO config
└── CMakeLists.txt          # CMake root
```

### 🔒 Armazenamento NVS

Configurações salvas permanentemente:

| Chave | Tipo | Descrição |
|-------|------|-----------|
| `wifi_ssid` | string | Nome da rede WiFi |
| `wifi_pass` | string | Senha WiFi |
| `wifi_conf` | bool | Flag de configuração WiFi |
| `backend_url` | string | URL completa do backend |
| `backend_port` | uint16 | Porta do servidor |
| `backend_https` | bool | Usar HTTPS (futuro) |
| `setup_done` | bool | Setup completo |

### 🛠️ Desenvolvimento

#### Compilar
```bash
cd /opt/lampp/htdocs/aguada/firmware/gateway_wifi
pio run
```

#### Gravar
```bash
pio run --target upload
```

#### Monitor Serial
```bash
pio device monitor
# Baudrate: 115200
```

#### Limpar Build
```bash
pio run --target clean
rm -rf build/ .pio/
```

### 📊 Logs Esperados

#### Modo Setup (não configurado):
```
I (1234) GATEWAY: 🔧 Gateway não configurado - entrando em MODO SETUP
I (1245) GATEWAY: ✅ WiFi AP: AGUADA-SETUP (Canal 11)
I (1256) WEB_SERVER: ✅ Servidor web iniciado
I (1267) DNS_SERVER: ✅ DNS server iniciado na porta 53
I (1278) GATEWAY: ========================================
I (1289) GATEWAY: 📱 MODO SETUP ATIVO
I (1290) GATEWAY:    1. Conecte ao WiFi: AGUADA-SETUP
I (1291) GATEWAY:    2. Senha: aguada2025
I (1292) GATEWAY:    3. Acesse: http://192.168.4.1
I (1293) GATEWAY:    4. Configure WiFi e Backend
I (1294) GATEWAY: ========================================
```

#### Modo Normal (configurado):
```
I (1234) GATEWAY: ✅ Configuração encontrada - MODO NORMAL
I (1245) GATEWAY:    WiFi: MinhRede
I (1256) GATEWAY:    Backend: http://192.168.0.101/aguada/api_gateway.php
I (1267) GATEWAY: ✅ WiFi AP: AGUADA-SETUP (Canal 11)
I (1278) GATEWAY: 🔄 Conectando a: MinhaRede
I (1289) GATEWAY: ✅ WiFi conectado! IP: 192.168.0.150
I (1290) GATEWAY: ✅ ESP-NOW inicializado
I (1291) GATEWAY: ✅ Gateway pronto!
```

### 🔧 Configurações Avançadas

#### Alterar SSID/Senha do AP
Edite em `main/main.c`:
```c
#define WIFI_AP_SSID "AGUADA-SETUP"
#define WIFI_AP_PASSWORD "aguada2025"
```

#### Alterar IP do Gateway
Por padrão: `192.168.4.1`

Para alterar, configure DHCP server no `esp_netif`.

#### Timeout de Conexão WiFi
```c
#define WIFI_CONNECT_TIMEOUT_MS 15000  // 15 segundos
```

### ❗ Troubleshooting

#### Gateway não entra em modo setup
- Limpe NVS: `pio run --target erase_flash`
- Regrave firmware completo

#### Captive portal não funciona
- Verifique DNS server nos logs
- Alguns dispositivos Android/iOS demoram a detectar
- Acesse manualmente: `http://192.168.4.1`

#### WiFi scan retorna vazio
- ESP32-C3 suporta apenas 2.4 GHz
- Aumentar `scan_time.active.max` em `web_server.c`

#### Backend não responde
- Verifique URL salva: `curl http://192.168.4.1/api/status`
- Teste backend manualmente:
  ```bash
  curl -X POST http://IP/aguada/api_gateway.php \
    -H "Content-Type: application/json" \
    -d '{"mac_address":"AA:BB:CC:DD:EE:FF","readings":[{"sensor_id":1,"distance_cm":50}]}'
  ```

### 📝 Próximas Melhorias

- [ ] mDNS discovery real (implementação assíncrona)
- [ ] OTA (atualização over-the-air)
- [ ] HTTPS para backend
- [ ] Múltiplas redes WiFi com fallback
- [ ] Logs persistentes em SD card
- [ ] Interface de diagnóstico avançada

### 📄 Licença

Sistema Aguada - CMASM
Versão 2.5 - Outubro 2025
