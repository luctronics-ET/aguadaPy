# 📡 Firmwares Disponíveis - Referência

> **⚠️ ATENÇÃO**: Esta pasta é SOMENTE LEITURA!  
> Firmwares originais estão em: `/opt/lampp/htdocs/aguada/firmware/`  
> **NÃO MODIFICAR** a pasta original. Copie e adapte conforme necessário.

---

## 🗂️ Hardware Disponível

### ✅ Confirmado em Estoque

| Hardware | Quantidade | Componentes | Status |
|----------|------------|-------------|---------|
| ESP32 + Ultrassom | 2× | ESP32-C3 Super Mini + HC-SR04 | ✅ Pronto |
| Arduino Nano + Ethernet + Ultrassom | 1× | Nano + W5500 + HC-SR04 | ✅ Pronto |
| Gateway WiFi | 1× | ESP32-C3 Super Mini | ✅ Pronto |
| Gateway Multi-protocolo | 1× | ESP8266 + ENC28J60 | ✅ Backup |
| Raspberry Pi Pico (backup) | ?× | Pico + ESP + Ethernet | ⚡ Contingência |

---

## 📁 Firmwares Disponíveis em `/aguada/firmware/`

### 🔹 **NODE-01-CON** (ESP32 ESP-NOW)
**Localização**: `/opt/lampp/htdocs/aguada/firmware/node-01-con/`  
**Hardware**: ESP32-C3  
**Protocolo**: ESP-NOW → Gateway  
**Sensores**: HC-SR04 (ultrassom)  

**Características:**
- ✅ ESP-NOW mesh (200m de alcance)
- ✅ Leitura ultrassom com mediana de 11 amostras
- ✅ Deep sleep (economia de energia)
- ✅ Buffer local de 100 leituras
- ✅ Protocolo `sensor_packet_t` (12 bytes)

**Arquivos principais:**
```
node-01-con/
├── src/
│   └── main.cpp           # Firmware completo
├── platformio.ini         # Configuração PlatformIO
└── README.md             # Documentação específica
```

**Uso sugerido**: 
- ✅ **Nós remotos** onde WiFi não alcança
- ✅ **Reduzir consumo de energia** (deep sleep entre leituras)
- ✅ **Redes mesh** com múltiplos sensores

---

### 🔹 **NODE-02-CAV** (Arduino Nano Ethernet)
**Localização**: `/opt/lampp/htdocs/aguada/firmware/node-02-cav/` ou `/node_02-cav/`  
**Hardware**: Arduino Nano + W5500 Ethernet  
**Protocolo**: Ethernet → HTTP POST direto  
**Sensores**: HC-SR04 (ultrassom)  

**Características:**
- ✅ Conexão Ethernet ultra-confiável (100Mbps)
- ✅ Biblioteca EtherCard ou Ethernet.h
- ✅ Leitura ultrassom com NewPing
- ✅ POST direto para API (`/api/gateway`)
- ✅ **100% uptime** (cabo Ethernet)

**Arquivos principais:**
```
node-02-cav/
├── src/
│   └── main.cpp           # Firmware completo
├── platformio.ini         # Configuração PlatformIO
├── README.md             # Documentação
├── CHANGELOG_v1.5.md     # Histórico de versões
├── CHANGELOG_v1.6.md
├── DIAGNOSTICO_NAO_ENVIA.md
└── SOLUCAO_BOOT_LOOP.md  # Troubleshooting
```

**Uso sugerido**:
- ✅ **Reservatórios críticos** que precisam de 100% de confiabilidade
- ✅ **Locais com cabeamento Ethernet** disponível
- ✅ **Evitar problemas de WiFi** (interferência, distância)

**Versões disponíveis:**
- **v1.5**: Correções de compilação
- **v1.6**: Melhorias de conectividade
- **v1.8**: Anti-travamento
- **v1.9**: Fix final

---

### 🔹 **GATEWAY_WIFI** (ESP32 Gateway)
**Localização**: `/opt/lampp/htdocs/aguada/firmware/gateway_wifi/`  
**Hardware**: ESP32-C3 Super Mini ou ESP32 DevKit  
**Protocolo**: ESP-NOW (recebe) + WiFi (envia)  
**Função**: Bridge entre nós ESP-NOW e servidor

**Características:**
- ✅ Recebe pacotes ESP-NOW de múltiplos nós
- ✅ Envia para servidor via WiFi/HTTP
- ✅ Suporta até 20 nós simultâneos
- ✅ Buffer de 250 pacotes
- ✅ Portal de configuração WiFi (WiFiManager)
- ✅ Fallback para Ethernet (opcional)

**Arquivos principais:**
```
gateway_wifi/
├── main/
│   ├── main.c            # Código principal
│   ├── wifi_manager.c    # Gerenciamento WiFi
│   └── esp_now_handler.c # Handler ESP-NOW
├── CMakeLists.txt
├── sdkconfig             # Configuração ESP-IDF
├── README_CONFIGURACAO.md
└── TESTE_PORTAL.md
```

**Uso sugerido**:
- ✅ **Gateway central** para nós ESP-NOW
- ✅ **Converter ESP-NOW → HTTP** para API
- ✅ **Configuração via portal web** (192.168.4.1)

---

### 🔹 **GATEWAY_ESP8266** (Backup)
**Localização**: `/opt/lampp/htdocs/aguada/firmware/gateway_esp8266/`  
**Hardware**: ESP8266 + ENC28J60 (Ethernet)  
**Protocolo**: ESP-NOW + Ethernet  
**Função**: Gateway com Ethernet (caso ESP32 não funcione)

**Características:**
- ✅ ESP8266 como MCU principal
- ✅ Ethernet via ENC28J60 (backup do WiFi)
- ✅ Protocolo ESP-NOW compatível
- ✅ Menor consumo de energia

**Uso sugerido**:
- ⚡ **Backup** se ESP32 gateway falhar
- ✅ **Ethernet obrigatório** em ambientes críticos

---

### 🔹 **NODE_GENERIC** (Template)
**Localização**: `/opt/lampp/htdocs/aguada/firmware/node_generic/`  
**Hardware**: ESP32 genérico  
**Função**: Template para criar novos nós

**Características:**
- ✅ Template base para novos nodes
- ✅ Configurável via ESP-IDF
- ✅ Suporte a múltiplos sensores
- ✅ GPIO configurável

**Uso sugerido**:
- 🔧 **Base para NODE-003, NODE-004, etc.**
- 🔧 **Customização** para sensores especiais

---

## 📋 Arquivos de Configuração Comuns

### **common/sensor_packet.h**
**Protocolo de comunicação obrigatório** (12 bytes)

```c
typedef struct __attribute__((packed)) {
    uint8_t  mac[6];        // MAC address (6 bytes)
    uint8_t  value_id;      // ID do sensor (1 byte)
    uint16_t value_data;    // Dados em cm (2 bytes)
    uint16_t sequence;      // Número sequencial (2 bytes)
    int8_t   rssi;          // RSSI em dBm (1 byte)
    uint8_t  reserved;      // Reservado (1 byte)
} sensor_packet_t; // Total: 12 bytes
```

⚠️ **OBRIGATÓRIO** usar esta estrutura em TODOS os firmwares!

---

### **common/node_definitions.h**
**Definições de todos os nodes cadastrados**

```c
// NODE-001: ESP32 ESP-NOW Consumo
#define NODE_001_MAC {0x34, 0x85, 0x18, 0x9A, 0x2B, 0xF4}
#define NODE_001_ID 1
#define NODE_001_SENSOR_NIVEL_ID 1

// NODE-002: Arduino Nano Ethernet
#define NODE_002_MAC {0xDE, 0xAD, 0xBE, 0xEF, 0xFE, 0x02}
#define NODE_002_ID 2
#define NODE_002_SENSOR_NIVEL_ID 2
```

---

### **common/aguada_config.h**
**Configurações globais do sistema**

```c
// Versão do protocolo
#define PROTOCOL_VERSION "2.1"

// Intervalo de leitura (ms)
#define READING_INTERVAL 30000  // 30 segundos

// WiFi
#define WIFI_SSID "Aguada_AP"
#define WIFI_PASS "aguada2025"

// Servidor
#define API_URL "http://192.168.1.100:3000/api/leituras/raw"
```

---

## 🔧 Adaptação para aguadaPy

### Estratégia de Migração

**1. Copiar firmwares relevantes (não modificar originais):**

```bash
# Criar estrutura em aguadaPy
mkdir -p /opt/lampp/htdocs/aguadaPy/firmware_nodes

# Copiar NODE-02-CAV (Arduino + Ethernet) - PRIORIDADE
cp -r /opt/lampp/htdocs/aguada/firmware/node-02-cav /opt/lampp/htdocs/aguadaPy/firmware_nodes/node_ethernet

# Copiar NODE-01-CON (ESP32 ESP-NOW) - SECUNDÁRIO
cp -r /opt/lampp/htdocs/aguada/firmware/node-01-con /opt/lampp/htdocs/aguadaPy/firmware_nodes/node_espnow

# Copiar Gateway WiFi
cp -r /opt/lampp/htdocs/aguada/firmware/gateway_wifi /opt/lampp/htdocs/aguadaPy/firmware_nodes/gateway

# Copiar arquivos comuns
cp -r /opt/lampp/htdocs/aguada/firmware/common /opt/lampp/htdocs/aguadaPy/firmware_nodes/
```

**2. Adaptar apenas URLs e IPs:**

No arquivo `aguada_config.h` copiado, alterar:

```c
// ANTES (aguada original)
#define API_URL "http://192.168.0.101/aguada/api_gateway.php"

// DEPOIS (aguadaPy com Docker)
#define API_URL "http://192.168.1.100:3000/api/leituras/raw"
```

**3. Testar conectividade:**

```bash
# No ESP32, fazer ping para o servidor
ping 192.168.1.100

# No servidor Docker, monitorar logs
docker logs -f aguada_backend | grep POST
```

---

## 📊 Comparação de Firmwares

| Firmware | Hardware | Protocolo | Alcance | Consumo | Confiabilidade | Uso Sugerido |
|----------|----------|-----------|---------|---------|----------------|--------------|
| **NODE-01-CON** | ESP32 | ESP-NOW | 200m | Baixo (deep sleep) | 95% | Nós remotos |
| **NODE-02-CAV** | Nano+Eth | Ethernet | Ilimitado (cabo) | Médio | 99.9% | Crítico |
| **GATEWAY_WIFI** | ESP32 | WiFi+ESP-NOW | 100m WiFi | Médio | 98% | Gateway |
| **GATEWAY_ESP8266** | ESP8266+ENC | Ethernet | Ilimitado | Baixo | 99% | Backup |

---

## 🎯 Recomendações de Uso

### Para Reservatórios Críticos (RES_CONS, RES_INC)
✅ **NODE-02-CAV** (Arduino Nano + Ethernet)
- Confiabilidade máxima
- Cabo Ethernet já instalado
- Firmware estável (v1.9)

### Para Reservatórios Remotos (ELEV_A, ELEV_B)
✅ **NODE-01-CON** (ESP32 ESP-NOW)
- Longo alcance sem fio
- Economia de energia
- Mesh networking

### Para Gateway Central
✅ **GATEWAY_WIFI** (ESP32)
- Recebe ESP-NOW
- Envia WiFi/Ethernet
- Configuração via portal

---

## 📚 Documentação Adicional

### Documentos Obrigatórios

1. **FIRMWARE_RULES.md** ⭐
   - Regras imutáveis de desenvolvimento
   - Protocolo `sensor_packet_t`
   - Checklist de conformidade
   - **LEITURA OBRIGATÓRIA** antes de modificar firmware!

2. **EXECUTIVE_SUMMARY.md**
   - Visão geral do sistema Aguada V2.1
   - Melhorias implementadas
   - Compatibilidade

3. **IMPROVEMENTS_PROPOSAL.md**
   - Propostas técnicas detalhadas
   - Priorização de melhorias
   - Roadmap

### Documentos de Troubleshooting

- `DIAGNOSTICO_NAO_ENVIA.md` - Sensor não envia dados
- `DIAGNOSTICO_SENSOR_ERRO.md` - Leituras erradas
- `SOLUCAO_BOOT_LOOP.md` - ESP32 reiniciando
- `SOLUCAO_LED_PISCANDO.md` - Problemas de conectividade

---

## ⚠️ Avisos Importantes

### 🚫 NÃO MODIFICAR

**NUNCA modifique diretamente os arquivos em:**
```
/opt/lampp/htdocs/aguada/firmware/
```

Sempre **copie** para `/opt/lampp/htdocs/aguadaPy/firmware_nodes/` e modifique a cópia!

### ✅ SEMPRE RESPEITAR

- Estrutura `sensor_packet_t` (12 bytes)
- `value_id` único por sensor
- MAC address único por node
- Intervalo mínimo de leitura (30s)

### 📝 DOCUMENTAR

Ao criar firmware customizado:
1. Copie `node_generic` como base
2. Documente mudanças em `README.md`
3. Registre `value_id` em `node_definitions.h`
4. Teste antes de deploy em produção

---

## 🔗 Links Úteis

### Firmwares Originais
- `/opt/lampp/htdocs/aguada/firmware/` - **SOMENTE LEITURA**
- Documentação completa em `/aguada/firmware/README.md`
- Índice completo em `/aguada/firmware/INDEX.md`

### Firmwares Adaptados (aguadaPy)
- `/opt/lampp/htdocs/aguadaPy/firmware_nodes/` - Cópias para modificação
- Scripts de build em `/firmware_nodes/scripts/`

### Referências Web
- Sistema original: http://192.168.0.101/aguada/
- Dashboard original: http://192.168.0.101/aguada/dashboard.php
- Sistema novo (Docker): http://192.168.1.100/

---

## 📞 Próximos Passos

1. ✅ Ler `FIRMWARE_RULES.md` (obrigatório)
2. ✅ Copiar firmwares para `/firmware_nodes/`
3. ✅ Adaptar `aguada_config.h` com IP do Docker
4. ✅ Compilar e testar em bancada
5. ✅ Validar conectividade ESP32 → API
6. ✅ Deploy em produção

---

**Última atualização**: 2025-10-30  
**Sistema**: Aguada CMMS/BMS V2.1 → aguadaPy  
**Status**: Firmwares disponíveis e documentados ✅
