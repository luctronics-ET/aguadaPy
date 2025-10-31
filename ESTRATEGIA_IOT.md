# Estratégia Abrangente de Desenvolvimento IoT
## Projeto CMMS Supervisório Hídrico

**Versão**: 1.0  
**Data**: 2025-10-30  
**Status**: Em Desenvolvimento

---

## 📋 Índice

1. [Visão Geral](#1-visão-geral)
2. [Seleção de Hardware](#2-seleção-de-hardware)
3. [Protocolos de Comunicação](#3-protocolos-de-comunicação)
4. [Integração Software/Firmware](#4-integração-softwarefirmware)
5. [Plano de Testes](#5-plano-de-testes)
6. [Implantação e Manutenção](#6-implantação-e-manutenção)
7. [Análise de Escalabilidade](#7-análise-de-escalabilidade)
8. [Análise de Custos](#8-análise-de-custos)
9. [Desafios e Mitigações](#9-desafios-e-mitigações)
10. [Casos de Uso Práticos](#10-casos-de-uso-práticos)

---

## 1. Visão Geral

### 1.1 Objetivo do Sistema

Desenvolver um sistema IoT inteligente para monitoramento e gestão de rede hídrica com:
- **Aquisição contínua** de dados de nível, pressão e vazão
- **Compressão inteligente** de dados (redução de 90%)
- **Detecção automática** de eventos (vazamento, abastecimento, consumo)
- **Gestão completa** CMMS/BMS integrada (estoque, serviços, manutenção)

### 1.2 Escopo do Projeto

#### Componentes Principais
```
[Camada Física]
   ↓
[Camada IoT - ESP32/Arduino]
   ↓
[Camada de Comunicação - WiFi/ESP-NOW/Ethernet]
   ↓
[Camada de Processamento - Backend API]
   ↓
[Camada de Armazenamento - PostgreSQL]
   ↓
[Camada de Visualização - Dashboard Web/Mobile]
```

#### Funcionalidades-Chave
- ✅ Monitoramento em tempo real
- ✅ Relatórios diários automáticos
- ✅ Alertas inteligentes
- ✅ Calibração manual
- ✅ Gestão de estoque (peças, consumíveis)
- ✅ Ordens de serviço
- ✅ Manutenção preventiva
- ✅ Análise preditiva (futuro)

---

## 2. Seleção de Hardware

### 2.1 Microcontroladores

#### ESP32-C3 Super Mini ⭐ ESCOLHA PRINCIPAL

**Especificações**:
- Processador: RISC-V 160MHz single-core
- RAM: 400KB SRAM
- Flash: 4MB
- WiFi: 802.11 b/g/n (2.4GHz)
- Bluetooth: BLE 5.0
- GPIO: 13 pinos
- ADC: 6 canais (12-bit)
- Consumo: 5µA (deep sleep) / 80mA (ativo)
- Dimensões: 27mm × 13mm
- Custo: **R$ 12-18**

**Vantagens**:
- ✅ Extremamente compacto
- ✅ WiFi nativo (sem módulos externos)
- ✅ Baixo consumo (ideal para bateria)
- ✅ Suporte OTA (update firmware remoto)
- ✅ Comunidade ativa (Arduino / ESP-IDF)
- ✅ Compatível com ESP-NOW (mesh)

**Aplicações no Projeto**:
- Leitura de sensores de nível (ultrassom)
- Leitura de sensores de pressão (analógico)
- Envio de dados via WiFi a cada 30s
- Fallback para ESP-NOW em caso de queda WiFi

**Pinout Sugerido**:
```
GPIO2 → Trigger HC-SR04
GPIO3 → Echo HC-SR04
GPIO4 → LED status
GPIO5 → ADC Pressão (opcional)
GND   → Ground
5V    → Alimentação
```

#### Arduino Nano ⭐ BACKUP/CONTROLE

**Especificações**:
- Processador: ATmega328P 16MHz
- RAM: 2KB SRAM
- Flash: 32KB
- GPIO: 14 digital + 8 analógicos
- Custo: **R$ 20-30**

**Aplicações no Projeto**:
- Controle de relés (bombas/válvulas)
- Aquisição de sinais secundários
- Redundância (se ESP32 falhar)
- Comunicação I²C/1-Wire com sensores

**Vantagens**:
- ✅ Extremamente confiável
- ✅ Baixo consumo
- ✅ Fácil programação
- ✅ Compatível com shields

#### Arduino Micro

**Quando usar**: 
- Espaço extremamente limitado
- Necessidade de USB nativo (HID)
- Menor custo que Nano

---

### 2.2 Sensores

#### 2.2.1 Sensor de Nível: HC-SR04 (Ultrassom) ⭐ PRINCIPAL (usando o aj-sr04 tambem)

**Especificações**:
- Range: 2cm - 400cm
- Precisão: ±3mm
- Ângulo: 15°
- Tensão: 5V
- Consumo: 15mA (ativo)
- Custo: **R$ 7-12**

**Configuração**:
```cpp
#define TRIG_PIN 2
#define ECHO_PIN 3

long duration, distance;

void setup() {
  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
}

void loop() {
  // Dispara pulso
  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);
  
  // Mede tempo de retorno
  duration = pulseIn(ECHO_PIN, HIGH);
  distance = duration * 0.034 / 2; // cm
  
  Serial.println(distance);
  delay(500);
}
```

**Vantagens**:
- ✅ Sem contato com água
- ✅ Baixo custo
- ✅ Fácil instalação
- ✅ Não requer calibração frequente

**Desvantagens**:
- ⚠️ Sensível a espuma/vapor
- ⚠️ Afetado por temperatura extrema
- ⚠️ Não funciona em tanques muito largos (ângulo)

**Mitigações**:
- Usar mediana de 11 leituras (filtrar ruído)
- Instalar em tubo guia (evitar eco lateral)
- Proteção contra condensação

#### 2.2.2 Sensor de Pressão: MPX5700AP

**Especificações**:
- Range: 15-700 kPa (0-7 bar)
- Saída: Analógica 0.2-4.7V
- Precisão: ±2.5%
- Custo: **R$ 30-45**

**Aplicação**: 
- Medição de pressão na saída de bombas
- Detecção de obstrução em rede

**Código de Leitura**:
```cpp
#define PRESSURE_PIN A0

float readPressure() {
  int raw = analogRead(PRESSURE_PIN);
  float voltage = raw * (5.0 / 1023.0);
  float pressure_kPa = (voltage - 0.2) * 700 / 4.5;
  return pressure_kPa / 100.0; // Converter para bar
}
```

#### 2.2.3 Sensor de Vazão: YF-S201

**Especificações**:
- Range: 1-30 L/min
- Precisão: ±10%
- Sinal: Digital (pulsos)
- Custo: **R$ 15-25**

**Aplicação**:
- Medição de consumo real
- Validação de cálculos baseados em nível

#### 2.2.4 Sensor de Temperatura: DS18B20

**Especificações**:
- Range: -55°C a +125°C
- Precisão: ±0.5°C
- Protocolo: 1-Wire
- Custo: **R$ 8-12**

**Aplicação**:
- Compensação de leitura do ultrassom
- Monitoramento de temperatura da água

---

### 2.3 Módulos de Comunicação

#### 2.3.1 WiFi (Nativo ESP32-C3)

**Configuração**:
```cpp
#include <WiFi.h>

const char* ssid = "REDE_AGUADA";
const char* password = "senha123";

void setup() {
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("WiFi conectado!");
  Serial.println(WiFi.localIP());
}
```

**Vantagens**:
- ✅ Longo alcance (50-100m indoor)
- ✅ Alta taxa de transferência
- ✅ Infraestrutura existente

**Desvantagens**:
- ⚠️ Maior consumo de energia
- ⚠️ Depende de roteador/AP

#### 2.3.2 ESP-NOW (Mesh) ⭐ FALLBACK

**Especificações**:
- Range: até 200m (linha de vista)
- Latência: < 10ms
- Sem necessidade de router
- Máx 20 dispositivos pareados

**Configuração**:
```cpp
#include <esp_now.h>
#include <WiFi.h>

uint8_t broadcastAddress[] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF};

typedef struct {
  char sensor_id[10];
  float nivel_cm;
  unsigned long timestamp;
} DataPacket;

DataPacket myData;

void OnDataSent(const uint8_t *mac_addr, esp_now_send_status_t status) {
  Serial.println(status == ESP_NOW_SEND_SUCCESS ? "OK" : "FALHA");
}

void setup() {
  WiFi.mode(WIFI_STA);
  esp_now_init();
  esp_now_register_send_cb(OnDataSent);
  
  esp_now_peer_info_t peerInfo;
  memcpy(peerInfo.peer_addr, broadcastAddress, 6);
  peerInfo.channel = 0;  
  peerInfo.encrypt = false;
  esp_now_add_peer(&peerInfo);
}

void loop() {
  strcpy(myData.sensor_id, "RES001");
  myData.nivel_cm = 145.3;
  myData.timestamp = millis();
  
  esp_now_send(broadcastAddress, (uint8_t *) &myData, sizeof(myData));
  delay(5000);
}
```

**Vantagens**:
- ✅ Não depende de infraestrutura WiFi
- ✅ Baixa latência
- ✅ Baixo consumo
- ✅ Auto-healing (mesh)

**Uso no Projeto**:
- Comunicação entre sensores (gateway)
- Fallback quando WiFi cai
- Expansão futura (50+ sensores)

#### 2.3.3 Ethernet (W5500) ⭐ ALTA CONFIABILIDADE

**Especificações**:
- Velocidade: 10/100 Mbps
- Interface: SPI
- Custo: **R$ 35-50**

**Quando usar**:
- Servidor central / Gateway
- Ambientes com interferência WiFi
- Requisitos de segurança elevados

**Vantagens**:
- ✅ Estabilidade máxima
- ✅ Sem interferência
- ✅ Menor latência

**Desvantagens**:
- ⚠️ Requer cabeamento
- ⚠️ Maior custo de instalação

#### 2.3.4 LoRa (SX1276) - FUTURO

**Especificações**:
- Range: até 10km (rural)
- Consumo: ~10mA (TX)
- Custo: **R$ 40-60**

**Aplicação Futura**:
- Reservatórios remotos (distantes)
- Áreas sem cobertura WiFi

---

### 2.4 Alimentação

#### Opção 1: Fonte 5V (Rede Elétrica)
- Custo: R$ 10-15
- Estabilidade máxima
- Ideal para 90% dos casos

#### Opção 2: Bateria + Solar
- Bateria LiPo 3.7V 2000mAh: R$ 25
- Painel solar 5V 1W: R$ 20
- Controlador de carga TP4056: R$ 5
- **Total**: R$ 50

**Autonomia Estimada**:
```
Consumo ESP32 ativo: 80mA × 2s (leitura) = 160mAh/30min = 7.7mAh/h
Consumo deep sleep: 0.005mA × 28s = 0.14mAh/30min = 0.007mAh/h
Total/dia: ~185mAh

Com bateria 2000mAh: ~10 dias sem sol
Com painel 1W (200mA @ 5h sol/dia): autonomia infinita
```

---

## 3. Protocolos de Comunicação

### 3.1 Comparativo

| Protocolo | Range | Taxa | Consumo | Latência | Custo | Uso no Projeto |
|-----------|-------|------|---------|----------|-------|----------------|
| **WiFi** | 50-100m | 54Mbps | 80mA | 10-50ms | R$ 0 | Principal |
| **ESP-NOW** | 200m | 1Mbps | 20mA | <10ms | R$ 0 | Fallback/Mesh |
| **Ethernet** | 100m | 100Mbps | 50mA | <5ms | R$ 40 | Gateway |
| **Bluetooth** | 10-30m | 2Mbps | 15mA | 20ms | R$ 0 | Config local |
| **I²C** | 1m | 400kbps | Baixo | <1ms | R$ 0 | Sensores locais |
| **1-Wire** | 100m | 16kbps | Muito baixo | <10ms | R$ 0 | DS18B20 |
| **LoRa** | 10km | 50kbps | 10mA | 100-500ms | R$ 50 | Futuro |

### 3.2 Estratégia de Comunicação

#### Arquitetura Hierárquica

```
                   [Servidor Central]
                          │
             ┌────────────┼────────────┐
             │ WiFi       │ Ethernet   │
      ┌──────┴───┐   ┌───┴───┐   ┌───┴───┐
   [Gateway 1] [Gateway 2] [Gateway 3]
       │ESP-NOW    │ESP-NOW    │ESP-NOW
   ┌───┼───┐   ┌───┼───┐   ┌───┼───┐
 [ESP] [ESP] [ESP] [ESP] [ESP] [ESP]
  RES1  RES2  RES3  RES4  RES5  RES6
```

**Lógica de Fallback**:
1. Tentar WiFi direto ao servidor (modo normal)
2. Se falhar → ESP-NOW para gateway mais próximo
3. Gateway retransmite via Ethernet/WiFi estável
4. Buffer local mantém últimas 100 leituras

### 3.3 Formato de Dados

#### Payload WiFi (HTTP POST):
```json
{
  "device_id": "ESP32_RES_CONS",
  "sensor_id": "SEN_RES_CONS",
  "timestamp": 1730304600,
  "readings": [
    {
      "variable": "nivel_cm",
      "value": 245.3,
      "unit": "cm"
    },
    {
      "variable": "temperatura_c",
      "value": 23.5,
      "unit": "C"
    }
  ],
  "rssi": -65,
  "battery_mv": 3700
}
```

#### Payload ESP-NOW (Binário):
```c
struct ESPNowPacket {
  char device_id[10];      // 10 bytes
  uint32_t timestamp;      // 4 bytes
  float nivel_cm;          // 4 bytes
  int8_t rssi;             // 1 byte
  uint16_t battery_mv;     // 2 bytes
  uint8_t checksum;        // 1 byte
} __attribute__((packed)); // Total: 22 bytes
```

**Vantagem**: Pacote pequeno = menor tempo no ar = menor consumo

---

## 4. Integração Software/Firmware

### 4.1 Arquitetura do Firmware ESP32

#### Estrutura de Pastas
```
firmware/esp32_nivel/
├── src/
│   ├── main.cpp
│   ├── sensors/
│   │   ├── ultrasonic.cpp
│   │   ├── pressure.cpp
│   │   └── temperature.cpp
│   ├── communication/
│   │   ├── wifi_manager.cpp
│   │   ├── espnow_manager.cpp
│   │   └── http_client.cpp
│   ├── utils/
│   │   ├── median_filter.cpp
│   │   ├── buffer.cpp
│   │   └── power_manager.cpp
│   └── config.h
├── lib/
├── platformio.ini
└── README.md
```

#### Exemplo: main.cpp
```cpp
#include <Arduino.h>
#include "config.h"
#include "sensors/ultrasonic.h"
#include "communication/wifi_manager.h"
#include "communication/http_client.h"
#include "utils/median_filter.h"

UltrasonicSensor sensor(TRIG_PIN, ECHO_PIN);
WiFiManager wifiMgr(WIFI_SSID, WIFI_PASSWORD);
HTTPClient httpClient(SERVER_URL);
MedianFilter filter(11); // Janela de 11 amostras

unsigned long lastReading = 0;
const unsigned long READ_INTERVAL = 30000; // 30 segundos

void setup() {
  Serial.begin(115200);
  
  sensor.begin();
  wifiMgr.connect();
  
  Serial.println("Sistema iniciado!");
}

void loop() {
  unsigned long now = millis();
  
  if (now - lastReading >= READ_INTERVAL) {
    // Fazer 11 leituras para mediana
    for (int i = 0; i < 11; i++) {
      float reading = sensor.read();
      filter.addSample(reading);
      delay(100);
    }
    
    float median = filter.getMedian();
    
    // Enviar para servidor
    String payload = buildJSON(median);
    bool sent = httpClient.POST(payload);
    
    if (sent) {
      Serial.println("Dados enviados com sucesso!");
    } else {
      Serial.println("Falha no envio, salvando em buffer...");
      // TODO: Implementar buffer local
    }
    
    lastReading = now;
    
    // Deep sleep até próxima leitura
    ESP.deepSleep(READ_INTERVAL * 1000);
  }
}

String buildJSON(float nivel) {
  return "{\"device_id\":\"" + String(DEVICE_ID) + 
         "\",\"sensor_id\":\"" + String(SENSOR_ID) +
         "\",\"timestamp\":" + String(millis() / 1000) +
         ",\"nivel_cm\":" + String(nivel, 2) + "}";
}
```

#### Exemplo: median_filter.cpp
```cpp
#include "median_filter.h"
#include <algorithm>

MedianFilter::MedianFilter(int window_size) {
  this->window_size = window_size;
  samples = new float[window_size];
  count = 0;
}

void MedianFilter::addSample(float value) {
  samples[count % window_size] = value;
  count++;
}

float MedianFilter::getMedian() {
  int n = min(count, window_size);
  float sorted[n];
  
  for (int i = 0; i < n; i++) {
    sorted[i] = samples[i];
  }
  
  std::sort(sorted, sorted + n);
  
  if (n % 2 == 0) {
    return (sorted[n/2-1] + sorted[n/2]) / 2.0;
  } else {
    return sorted[n/2];
  }
}
```

### 4.2 Backend API

#### Stack Recomendado
**Node.js + Express + PostgreSQL**

```
backend/
├── src/
│   ├── api/
│   │   ├── routes/
│   │   │   ├── leituras.js
│   │   │   ├── elementos.js
│   │   │   ├── eventos.js
│   │   │   └── relatorios.js
│   │   ├── controllers/
│   │   ├── middlewares/
│   │   │   ├── auth.js
│   │   │   ├── validation.js
│   │   │   └── rateLimit.js
│   │   └── index.js
│   ├── services/
│   │   ├── sensorService.js
│   │   ├── eventDetector.js
│   │   └── reportGenerator.js
│   ├── models/
│   ├── config/
│   │   ├── database.js
│   │   └── env.js
│   └── utils/
├── tests/
├── package.json
└── .env
```

#### Exemplo: leituras.js (Route)
```javascript
const express = require('express');
const router = express.Router();
const db = require('../config/database');

// POST /api/leituras/raw
router.post('/raw', async (req, res) => {
  try {
    const { device_id, sensor_id, timestamp, readings } = req.body;
    
    // Validação
    if (!sensor_id || !readings || !Array.isArray(readings)) {
      return res.status(400).json({ error: 'Dados inválidos' });
    }
    
    // Buscar elemento_id do sensor
    const sensor = await db.query(
      'SELECT elemento_id FROM supervisorio.sensores WHERE sensor_id = $1',
      [sensor_id]
    );
    
    if (sensor.rows.length === 0) {
      return res.status(404).json({ error: 'Sensor não encontrado' });
    }
    
    const elemento_id = sensor.rows[0].elemento_id;
    
    // Inserir leituras
    for (const reading of readings) {
      await db.query(
        `INSERT INTO supervisorio.leituras_raw 
         (sensor_id, elemento_id, variavel, valor, unidade, fonte, autor, modo, datetime)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, to_timestamp($9))`,
        [
          sensor_id,
          elemento_id,
          reading.variable,
          reading.value,
          reading.unit,
          'sensor',
          device_id,
          'automatica',
          timestamp
        ]
      );
    }
    
    res.status(201).json({ 
      message: 'Leituras recebidas com sucesso',
      count: readings.length 
    });
    
  } catch (error) {
    console.error('Erro ao inserir leituras:', error);
    res.status(500).json({ error: 'Erro interno do servidor' });
  }
});

module.exports = router;
```

---

## 5. Plano de Testes

### 5.1 Testes de Hardware

#### 5.1.1 Teste de Sensor HC-SR04
```
✅ Checklist:
- [ ] Medir distâncias conhecidas (50cm, 100cm, 200cm)
- [ ] Erro < 1% em condições normais
- [ ] Testar em diferentes temperaturas (10°C - 40°C)
- [ ] Testar com vapor/umidade
- [ ] Testar com espuma na superfície
- [ ] Validar mediana de 11 amostras (redução de ruído)
```

#### 5.1.2 Teste de Comunicação WiFi
```
✅ Checklist:
- [ ] Conectar em rede local
- [ ] Medir intensidade do sinal (RSSI > -70dBm)
- [ ] Teste de alcance (até onde funciona?)
- [ ] Tempo de reconexão após queda
- [ ] Envio de payload (< 500ms)
- [ ] Consumo de energia durante transmissão
```

#### 5.1.3 Teste de Autonomia
```
✅ Checklist:
- [ ] Medir corrente em deep sleep (< 10µA)
- [ ] Medir corrente durante leitura (~80mA)
- [ ] Calcular autonomia com bateria 2000mAh
- [ ] Validar carregamento solar (dias nublados)
```

### 5.2 Testes de Software

#### 5.2.1 Testes Unitários (Backend)
```javascript
// test/services/eventDetector.test.js
const { detectarVazamento } = require('../../src/services/eventDetector');

describe('Detecção de Vazamento', () => {
  test('Deve detectar vazamento com queda contínua', () => {
    const leituras = [
      { valor: 250, timestamp: '2025-10-30 08:00' },
      { valor: 248, timestamp: '2025-10-30 09:00' },
      { valor: 246, timestamp: '2025-10-30 10:00' },
      { valor: 244, timestamp: '2025-10-30 11:00' }
    ];
    
    const resultado = detectarVazamento(leituras);
    expect(resultado.detectado).toBe(true);
    expect(resultado.taxa_cm_h).toBeCloseTo(-2.0, 1);
  });
  
  test('Não deve detectar vazamento com oscilação normal', () => {
    const leituras = [
      { valor: 250, timestamp: '2025-10-30 08:00' },
      { valor: 249, timestamp: '2025-10-30 09:00' },
      { valor: 251, timestamp: '2025-10-30 10:00' },
      { valor: 250, timestamp: '2025-10-30 11:00' }
    ];
    
    const resultado = detectarVazamento(leituras);
    expect(resultado.detectado).toBe(false);
  });
});
```

### 5.3 Testes de Integração

#### 5.3.1 Teste End-to-End
```
Cenário: Sensor envia dado → API → BD → Dashboard

1. ESP32 faz leitura (100cm)
2. Envia POST /api/leituras/raw
3. Backend insere em leituras_raw
4. Trigger chama proc_process_sensor_window()
5. Leitura é agregada em leituras_processadas
6. Dashboard atualiza em tempo real (WebSocket)

✅ Validações:
- [ ] Dado chega em < 2s
- [ ] Valor correto no BD
- [ ] Dashboard atualiza automaticamente
- [ ] Log de auditoria gerado
```

### 5.4 Testes de Campo

#### 5.4.1 Teste Piloto (7 dias)
```
Instalação: 2 sensores (RES_CONS + RES_INC)

Métricas a coletar:
- [ ] Uptime (% de leituras bem-sucedidas)
- [ ] Erro médio vs hidrômetro
- [ ] Falsos positivos (vazamento)
- [ ] Tempo de detecção de eventos reais
- [ ] Consumo de energia real
- [ ] Qualidade do sinal WiFi ao longo do dia

Critérios de Sucesso:
- Uptime > 99%
- Erro < 5% comparado com hidrômetro
- Zero falsos positivos críticos
- Detecção de abastecimento < 5min
```

---

## 6. Implantação e Manutenção

### 6.1 Cronograma de Implantação

#### Semana 1-2: Preparação
- [ ] Comprar componentes
- [ ] Configurar servidor (PostgreSQL + Backend)
- [ ] Desenvolver firmware v1.0
- [ ] Criar dashboard básico

#### Semana 3: Instalação Piloto
- [ ] Instalar 2 sensores (RES_CONS, RES_INC)
- [ ] Calibrar com régua física
- [ ] Testar comunicação
- [ ] Validar dados no dashboard

#### Semana 4-5: Monitoramento e Ajustes
- [ ] Coletar métricas
- [ ] Ajustar deadband/thresholds
- [ ] Corrigir bugs
- [ ] Validar detecção de eventos

#### Semana 6-8: Expansão Completa
- [ ] Instalar 4 sensores restantes
- [ ] Configurar rede mesh (ESP-NOW)
- [ ] Treinamento de operadores
- [ ] Documentação final

### 6.2 Plano de Manutenção

#### Manutenção Preventiva

| Atividade | Frequência | Responsável | Tempo |
|-----------|------------|-------------|-------|
| Verificação física dos sensores | Mensal | Técnico | 30min |
| Limpeza de sensores ultrassônicos | Trimestral | Técnico | 1h |
| Calibração com régua/hidrômetro | Trimestral | Operador | 15min |
| Atualização de firmware (OTA) | Conforme necessário | Dev | 10min |
| Backup do banco de dados | Diário (automático) | Sistema | Automático |
| Teste de fallback ESP-NOW | Semestral | Técnico | 1h |
| Substituição preventiva de sensores | 2 anos | Técnico | 30min |

#### Manutenção Corretiva

**Procedimentos para Falhas Comuns**:

1. **Sensor não responde**
   - Verificar alimentação (5V)
   - Verificar conexão WiFi (LED piscando?)
   - Reboot remoto (via dashboard)
   - Se persistir: substituir sensor

2. **Leituras ruidosas**
   - Verificar espuma/condensação no sensor
   - Aumentar window_size (11 → 21 amostras)
   - Recalibrar sensor
   - Verificar interferência eletromagnética

3. **Falsos positivos (vazamento)**
   - Verificar log de bombas/válvulas
   - Ajustar threshold de detecção
   - Analisar padrão de consumo histórico

### 6.3 Procedimento de Calibração

**Frequência**: A cada 3 meses

**Materiais**:
- Régua métrica
- Trena (se profundo)
- Smartphone (para registrar foto)

**Passo a Passo**:
1. Medir distância real com régua (ex: 150cm)
2. Anotar leitura do sensor (ex: 148cm)
3. Calcular erro (150 - 148 = +2cm)
4. Abrir interface de calibração no dashboard
5. Inserir valor real (150cm)
6. Sistema calcula novo offset automaticamente
7. Salvar calibração
8. Validar: nova leitura deve estar correta (±0.5cm)

---

## 7. Análise de Escalabilidade

### 7.1 Cenários de Crescimento

#### Cenário Atual: 6 Reservatórios
```
Sensores: 6
Leituras/dia: 6 × 2880 = 17.280
Armazenamento/mês (raw): ~35 MB
Armazenamento/mês (processado): ~3 MB
Custo hardware: ~R$ 340
```

#### Cenário 2: 20 Reservatórios
```
Sensores: 20
Leituras/dia: 57.600
Armazenamento/mês (raw): ~120 MB
Armazenamento/mês (processado): ~10 MB
Custo hardware: ~R$ 1.200
Infraestrutura: 2 gateways ESP32 (mesh)
```

#### Cenário 3: 50 Reservatórios (Campus/Cidade Pequena)
```
Sensores: 50
Leituras/dia: 144.000
Armazenamento/mês (raw): ~300 MB
Armazenamento/mês (processado): ~25 MB
Custo hardware: ~R$ 3.000
Infraestrutura: 
  - 5 gateways ESP32 (mesh)
  - Servidor dedicado (4GB RAM, 50GB SSD)
  - Migrar para TimescaleDB
```

### 7.2 Limites Técnicos

#### PostgreSQL Puro
- **Leituras/s**: até 10.000 (suficiente para 50+ sensores)
- **Armazenamento**: até 1TB sem problemas
- **Limite prático**: ~100 sensores

#### TimescaleDB (Recomendado para > 20 sensores)
- **Leituras/s**: até 100.000
- **Compressão nativa**: reduz armazenamento em 95%
- **Retenção automática**: deleta dados antigos
- **Limite prático**: ~1000 sensores

### 7.3 Custo de Escalabilidade

| Componente | Atual (6 res.) | Médio (20 res.) | Grande (50 res.) |
|------------|---------------|-----------------|------------------|
| Hardware IoT | R$ 340 | R$ 1.200 | R$ 3.000 |
| Servidor | R$ 0* | R$ 100/mês** | R$ 300/mês*** |
| Energia | R$ 5/mês | R$ 15/mês | R$ 40/mês |
| Manutenção | R$ 50/mês | R$ 150/mês | R$ 400/mês |
| **TOTAL/ANO** | **R$ 1.000** | **R$ 3.180** | **R$ 12.880** |

*Servidor existente  
**VPS 2GB RAM (ex: DigitalOcean)  
***VPS 4GB RAM + backup

---

## 8. Análise de Custos

### 8.1 Investimento Inicial (6 Reservatórios)

#### Hardware
| Item | Qtd | Unit. | Total |
|------|-----|-------|-------|
| ESP32-C3 Super Mini | 6 | R$ 15 | R$ 90 |
| Sensor HC-SR04 | 6 | R$ 8 | R$ 48 |
| Fonte 5V 2A | 6 | R$ 10 | R$ 60 |
| Cabos + Conectores | 6 | R$ 8 | R$ 48 |
| Case proteção IP65 | 6 | R$ 12 | R$ 72 |
| Sensor pressão (opt.) | 2 | R$ 35 | R$ 70 |
| **Subtotal Hardware** | | | **R$ 388** |

#### Infraestrutura
| Item | Custo |
|------|-------|
| Servidor (existente) | R$ 0 |
| Instalação física | R$ 200 |
| Ferramentas (régua, trena) | R$ 50 |
| **Subtotal Infraestrutura** | **R$ 250** |

#### Software/Desenvolvimento
| Item | Custo |
|------|-------|
| Desenvolvimento (40h × R$ 50/h) | R$ 2.000 |
| Testes e ajustes (16h × R$ 50/h) | R$ 800 |
| Treinamento (8h × R$ 50/h) | R$ 400 |
| **Subtotal Software** | **R$ 3.200** |

**INVESTIMENTO TOTAL**: **R$ 3.838**

### 8.2 Custo Operacional (Mensal)

| Item | Custo |
|------|-------|
| Energia elétrica (6 × 24h) | R$ 5 |
| Manutenção preventiva | R$ 30 |
| Reposição sensores (amortizado) | R$ 10 |
| Internet (já existente) | R$ 0 |
| Servidor (já existente) | R$ 0 |
| **TOTAL/MÊS** | **R$ 45** |

### 8.3 ROI (Retorno do Investimento)

#### Economia Estimada

**1. Detecção de Vazamento**:
- Vazamento de 10 L/h não detectado por 30 dias = 7.200 L/mês
- Custo água: R$ 5/m³
- **Economia**: R$ 36/mês

**2. Otimização de Consumo**:
- Redução de 5% no consumo por conscientização
- Consumo médio: 200m³/mês
- **Economia**: 10m³ × R$ 5 = R$ 50/mês

**3. Redução de Horas/Homem**:
- Antes: 2h/dia de leitura manual = R$ 600/mês (salário operador)
- Depois: 15min/dia = R$ 75/mês
- **Economia**: R$ 525/mês

**ECONOMIA TOTAL**: **R$ 611/mês**

**Payback**: R$ 3.838 ÷ R$ 611 = **6.3 meses** ✅

---

## 9. Desafios e Mitigações

### 9.1 Desafios Técnicos

| Desafio | Impacto | Probabilidade | Mitigação |
|---------|---------|---------------|-----------|
| Ruído em leituras ultrassônicas | Médio | Alta | Mediana de 11 amostras + deadband |
| Falha de WiFi | Alto | Média | Fallback ESP-NOW + buffer local |
| Deriva de calibração | Médio | Média | Calibração trimestral obrigatória |
| Sensor danificado (raio, água) | Alto | Baixa | Case IP65 + proteção contra surtos |
| Bateria descarrega (solar) | Médio | Baixa | Dimensionar painel para dias nublados |
| Falso positivo vazamento | Médio | Média | Correlação com bombas/válvulas |

### 9.2 Desafios Operacionais

| Desafio | Mitigação |
|---------|-----------|
| Resistência de operadores | Treinamento + demonstração de benefícios |
| Falta de manutenção | Alertas automáticos + checklist mensal |
| Perda de dados (falha BD) | Backup diário automático + redundância |
| Falta de energia prolongada | UPS no servidor (2h autonomia) |
| Sabotagem/vandalismo | Instalação em local protegido + câmeras |

---

## 10. Casos de Uso Práticos

### 10.1 Caso de Uso 1: Detecção de Vazamento Noturno

**Cenário**:
- Reservatório de consumo perde 500 litros durante a madrugada
- Nenhuma bomba ligada, válvulas fechadas

**Fluxo**:
1. Sensor detecta queda de nível (-2cm/h)
2. Sistema correlaciona: bombas OFF + válvulas FECHADAS
3. Algoritmo classifica como VAZAMENTO (confiança 90%)
4. Gera evento em BD
5. Envia alerta via email/Telegram às 03:00
6. Equipe de emergência acionada
7. Vazamento corrigido em 2h (perda limitada a 1.000 L)

**Sem o sistema**:
- Vazamento descoberto apenas às 08:00 (leitura manual)
- Perda total: 10.000 L (R$ 50)

**Economia**: R$ 45 + tempo de resposta

### 10.2 Caso de Uso 2: Otimização de Abastecimento

**Cenário**:
- Histórico mostra que abastecimento ocorre sempre às 06:00
- Consumo pico é às 11:00

**Análise do Sistema**:
1. Gera gráfico de consumo por hora (últimos 30 dias)
2. Identifica pico às 11:00
3. Sugere abastecer às 05:00 (em vez de 06:00)
4. Evita risco de nível crítico às 11:00

**Resultado**:
- Nível nunca abaixo de 30%
- Redução de estresse da bomba
- Aumento de vida útil

### 10.3 Caso de Uso 3: Relatório Gerencial

**Cenário**:
- Gestor precisa apresentar consumo mensal em reunião

**Fluxo**:
1. Acessa dashboard
2. Seleciona período (01/10 a 30/10)
3. Visualiza:
   - Consumo total: 5.200 m³
   - Média diária: 173 m³
   - Pico: 15/10 (220 m³) - evento especial
   - Perda por vazamento: 150 m³ (2.8%)
4. Exporta PDF profissional
5. Apresenta em reunião

**Sem o sistema**:
- Dados manuais pouco confiáveis
- Impossível detectar picos/anomalias
- Sem rastreabilidade

---

## 11. Próximas Etapas

### Curto Prazo (1 mês)
- [ ] Finalizar banco de dados (executar scripts SQL)
- [ ] Desenvolver firmware ESP32 v1.0
- [ ] Criar API backend (endpoints principais)
- [ ] Comprar componentes hardware
- [ ] Instalar 2 sensores piloto

### Médio Prazo (3 meses)
- [ ] Dashboard web funcional
- [ ] Detecção de eventos automatizada
- [ ] Relatório diário implementado
- [ ] Todos os 6 sensores instalados
- [ ] Sistema em produção

### Longo Prazo (6-12 meses)
- [ ] Machine Learning para predição
- [ ] App mobile
- [ ] Integração com ERP
- [ ] Expansão para 20+ sensores
- [ ] Gestão completa de manutenção (CMMS)

---

## 12. Conclusão

Este documento apresenta uma estratégia completa e prática para desenvolvimento de sistema IoT para gestão hídrica. O foco é:

✅ **Simplicidade**: Hardware comum, firmware leve, arquitetura clara  
✅ **Confiabilidade**: Redundância (ESP-NOW), buffer local, validação  
✅ **Escalabilidade**: Fácil expansão de 6 para 50+ sensores  
✅ **Custo-benefício**: ROI em 6 meses, baixo custo operacional  
✅ **Praticidade**: Manutenção simples, calibração trimestral  

**Próximo passo**: Executar scripts SQL e iniciar desenvolvimento do firmware.

---

**Documento elaborado por**: Sistema CMMS Águada  
**Data**: 2025-10-30  
**Versão**: 1.0  
**Licença**: MIT
