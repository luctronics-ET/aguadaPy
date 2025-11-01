# Gateway Multifuncional v3.0 - Changelog

## Visão Geral
O Gateway ESP8266 foi atualizado da versão 2.1 para 3.0, consolidando múltiplas funcionalidades em um único dispositivo. Agora ele substitui o GTW-01 (ESP32 WiFi Gateway), economizando hardware.

## Novas Funcionalidades

### 1. WiFi Access Point (AP)
- **SSID**: `aguada`
- **Senha**: `aguada2025`
- **Canal**: 11 (compatível com ESP-NOW)
- **Máximo de clientes**: 8
- **Objetivo**: Permitir que nodes se conectem diretamente ao gateway, eliminando a necessidade do GTW-01

### 2. Modo WiFi Híbrido (AP + STA)
- **AP**: Cria rede "aguada" para receber conexões de nodes
- **STA**: Conecta em redes WiFi externas como fallback para uplink
- **Compatibilidade**: Ambos operam no canal 11 para manter ESP-NOW funcional

### 3. Sensor de Temperatura 1-Wire (DS18B20)
- **Pino**: GPIO2 (D4)
- **Leitura**: A cada 60 segundos
- **Objetivo**: Monitorar temperatura ambiente do gateway
- **Failsafe**: Sistema continua funcionando se sensor não estiver conectado

## Modificações no Código

### Configurações Adicionadas
```cpp
// WiFi Access Point
#define AP_SSID "aguada"
#define AP_PASSWORD "aguada2025"
#define AP_CHANNEL 11
#define AP_MAX_CLIENTS 8

// 1-Wire (DS18B20)
#define ONE_WIRE_BUS 2  // GPIO2 = D4
#define TEMP_READ_INTERVAL 60000  // Ler a cada 60s
```

### Funções Novas

1. **`initWiFiAP()`**
   - Cria o Access Point "aguada"
   - Configura IP estático: 192.168.4.1
   - Exibe informações de conexão

2. **`tryConnectWiFiSTA()`**
   - Tenta conectar em redes WiFi conhecidas (fallback)
   - Timeout de 10 segundos por rede
   - Continua mesmo se falhar (não bloqueia)

3. **`init1Wire()`**
   - Inicializa sensor DS18B20
   - Detecta número de dispositivos
   - Configura resolução para 12 bits

4. **`readTemperature()`**
   - Lê temperatura do sensor
   - Valida leitura (-127°C = erro)
   - Atualiza variável global `currentTemperature`

5. **`periodicTasks()`**
   - Gerencia leitura de temperatura (60s)
   - Pisca LED periodicamente (5s)
   - Centraliza tarefas não-bloqueantes

### Funções Modificadas

1. **`initESPNow()`**
   - Atualizada documentação
   - Agora funciona com WiFi em modo AP+STA
   - Mantém canal 11 fixo

2. **`sendViaWiFi()`**
   - Corrigido para usar `SERVER_PORT` (3000)
   - Funciona tanto em modo STA quanto AP

3. **`sendToServer()`**
   - Prioridade melhorada:
     - 1º: Ethernet (mais confiável)
     - 2º: WiFi STA (se conectado)
     - 3º: AP ativo (mas sem uplink - informativo)

4. **`heartbeat()`**
   - Exibe número de clientes conectados ao AP
   - Mostra temperatura atual
   - Status de todas as interfaces (AP, STA, ETH)

5. **`setup()`**
   - Ordem de inicialização:
     1. WiFi AP (cria rede local)
     2. WiFi STA (conecta em uplink - opcional)
     3. ESP-NOW (recebe dados de nodes)
     4. Ethernet (envia dados ao servidor)
     5. 1-Wire (monitora temperatura)

6. **`loop()`**
   - Agora chama `periodicTasks()`
   - Gerenciamento centralizado de tarefas

## Variáveis Globais Adicionadas

```cpp
// WiFi AP
bool wifiApActive = false;
uint8_t apClientsConnected = 0;

// WiFi STA
bool wifiStaConnected = false;

// 1-Wire
OneWire oneWire(ONE_WIRE_BUS);
DallasTemperature sensors(&oneWire);
float currentTemperature = 0.0;
unsigned long lastTempRead = 0;
int tempSensorCount = 0;
```

## Conexões de Hardware

### Pinos Utilizados
- **D8 (GPIO15)**: CS do Ethernet ENC28J60
- **D4 (GPIO2)**: 1-Wire (DS18B20) com resistor pull-up 4.7kΩ
- **D2 (GPIO4)**: LED de status

### Ethernet ENC28J60 (SPI)
- **MOSI**: D7 (GPIO13)
- **MISO**: D6 (GPIO12)
- **SCK**: D5 (GPIO14)
- **CS**: D8 (GPIO15)

### Sensor DS18B20
- **VCC**: 3.3V
- **GND**: GND
- **DATA**: D4 (GPIO2) com resistor 4.7kΩ para 3.3V

## Vantagens da v3.0

### Economia de Hardware
- ✅ **Elimina necessidade do GTW-01** (ESP32 WiFi Gateway)
- ✅ Libera um ESP32 para outros projetos
- ✅ Reduz consumo de energia (1 dispositivo ao invés de 2)

### Funcionalidades Integradas
- ✅ **WiFi AP**: Nodes podem conectar diretamente
- ✅ **ESP-NOW**: Continua recebendo pacotes de sensores
- ✅ **Ethernet**: Mantém prioridade para envio de dados
- ✅ **1-Wire**: Monitora temperatura do gateway
- ✅ **WiFi STA**: Fallback para uplink sem Ethernet

### Melhorias Operacionais
- ✅ Canal 11 unificado (AP + ESP-NOW compatíveis)
- ✅ Heartbeat detalhado (mostra clientes AP, temperatura)
- ✅ Failsafe em todas as interfaces (continua funcionando se uma falhar)
- ✅ Prioridade inteligente de transmissão

## Migração da v2.1 para v3.0

### Mudanças de Configuração
1. **Remover GTW-01** da lista de redes WiFi
2. **Adicionar bibliotecas**:
   - `#include <OneWire.h>`
   - `#include <DallasTemperature.h>`

### Hardware Adicional (Opcional)
- **Sensor DS18B20**: Conectar em D4 (GPIO2)
- **Resistor 4.7kΩ**: Entre DATA e VCC do DS18B20

### Nodes WiFi
- **Atualizar configuração**: SSID "aguada", senha "aguada2025"
- **Ou manter ESP-NOW**: Continua funcionando normalmente

## Testes Recomendados

1. **Compilação**: Verificar se compila sem erros
2. **WiFi AP**: Verificar se rede "aguada" é criada
3. **Conexão de Clientes**: Testar conectar smartphone ao AP
4. **ESP-NOW**: Confirmar recepção de pacotes de nodes
5. **Ethernet**: Verificar envio de dados ao servidor
6. **Temperatura**: Checar leituras do DS18B20 no monitor serial
7. **Heartbeat**: Observar logs a cada 60 segundos

## Observações

- ⚠️ **Canal 11**: Fundamental manter fixo para ESP-NOW funcionar
- ⚠️ **Memória**: ESP8266 tem RAM limitada, evitar buffers grandes
- ⚠️ **Watchdog**: Não usar delays longos (max 10ms no loop)
- ✅ **Compatibilidade**: Código funciona mesmo sem sensor DS18B20

## Próximos Passos

1. Compilar e fazer upload do firmware
2. Testar todas as interfaces (AP, ESP-NOW, Ethernet, 1-Wire)
3. Atualizar nodes para conectar em "aguada" (se desejado)
4. Desativar GTW-01 (ESP32) e reutilizar em outro projeto
5. Monitorar logs para verificar estabilidade

---

**Data**: 2025
**Autor**: Copilot
**Versão**: 3.0
**Hardware**: NodeMCU ESP8266 + ENC28J60 + DS18B20 (opcional)
