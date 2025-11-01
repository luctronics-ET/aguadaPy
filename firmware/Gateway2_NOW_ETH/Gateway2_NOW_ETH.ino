/**
 * ============================================================================
 * AGUADA - Gateway Multifuncional ESP8266
 * ============================================================================
 * Versão: 3.0 (WiFi AP + STA + ESP-NOW + Ethernet + 1-Wire)
 * Hardware: ESP8266 NodeMCU + ENC28J60 + DS18B20
 *
 * FUNCIONALIDADES:
 * - WiFi AP "aguada" (senha: aguada2025) para nodes se conectarem
 * - WiFi STA para conexão com redes externas (fallback)
 * - ESP-NOW canal 11 para receber dados dos sensores
 * - Ethernet ENC28J60 para envio prioritário ao servidor
 * - 1-Wire DS18B20 para monitoramento de temperatura local
 *
 * Para Arduino IDE:
 * - Board: NodeMCU 1.0 (ESP-12E Module)
 * - Upload Speed: 115200
 * - CPU Frequency: 80MHz
 * - Flash Size: 4MB (FS:2MB OTA:~1019KB)
 *
 * Bibliotecas necessárias:
 * - EthernetENC (v2.0.4+)
 * - ESP8266WiFi (core)
 * - ESP8266HTTPClient (core)
 * - OneWire
 * - DallasTemperature
 * ============================================================================
 */

#include <Arduino.h>
#include <ESP8266WiFi.h>
#include <espnow.h>
#include <ESP8266HTTPClient.h>
#include <WiFiClient.h>
#include <EthernetENC.h>
#include <SPI.h>
#include <OneWire.h>
#include <DallasTemperature.h>

// ============================================================================
// CONFIGURAÇÕES WiFi AP
// ============================================================================

#define AP_SSID "aguada"
#define AP_PASSWORD "aguada2025"
#define AP_CHANNEL 11          // Mesmo canal do ESP-NOW
#define AP_MAX_CONNECTIONS 8   // Até 8 devices conectados
#define AP_HIDDEN false        // Rede visível

// IP do AP (gateway para nodes)
IPAddress apIP(192, 168, 4, 1);
IPAddress apGateway(192, 168, 4, 1);
IPAddress apSubnet(255, 255, 255, 0);

// ============================================================================
// CONFIGURAÇÕES WiFi STA (Fallback/Uplink)
// ============================================================================

// WiFi Networks fallback (apenas 2.4GHz)
typedef struct
{
    const char *ssid;
    const char *password;
    const char *description;
} wifi_network_t;

static const wifi_network_t wifi_networks[] = {
    {"TP-LINK_BE3344", "", "Rede TP-Link sem senha (192.168.1.x)"},
    {"luciano", "19852012", "Rede fallback (192.168.0.x)"},
};

#define NUM_WIFI_NETWORKS (sizeof(wifi_networks) / sizeof(wifi_networks[0]))
#define WIFI_CONNECT_TIMEOUT_MS 10000
static int current_network_index = -1;

// ============================================================================
// CONFIGURAÇÕES Ethernet (ENC28J60)
// ============================================================================

#define ETH_CS_PIN 15 // D8
byte mac[] = {0xDE, 0xAD, 0xBE, 0xEF, 0xFE, 0xED};
IPAddress ip(192, 168, 0, 150);
IPAddress gateway(192, 168, 0, 1);
IPAddress subnet(255, 255, 255, 0);
IPAddress dnsServer(8, 8, 8, 8);

// ============================================================================
// CONFIGURAÇÕES 1-Wire (DS18B20)
// ============================================================================

#define ONE_WIRE_BUS 2  // D4 - GPIO2
OneWire oneWire(ONE_WIRE_BUS);
DallasTemperature sensors(&oneWire);
float currentTemperature = 0.0;

// ============================================================================
// CONFIGURAÇÕES Backend
// ============================================================================

#define BACKEND_URL "http://192.168.0.101:3000/api/leituras/raw"
#define HTTP_TIMEOUT_MS 5000
#define SERVER_IP "192.168.0.101"
#define SERVER_PORT 3000
#define API_PATH "/api/leituras/raw"

// ============================================================================
// CONFIGURAÇÕES ESP-NOW
// ============================================================================

#define ESPNOW_CHANNEL 11  // Mesmo canal do AP WiFi

// ============================================================================
// CONFIGURAÇÕES LED e Timing
// ============================================================================

#define LED_PIN 16
#define LED_BLINK_INTERVAL 30000
#define TEMP_READ_INTERVAL 60000  // Ler temperatura a cada 60s

// ============================================================================
// ESTRUTURAS DE DADOS
// ============================================================================

typedef struct
{
    uint8_t sensor_id;
    uint16_t distance_cm;
} SensorReading;

typedef struct
{
    char mac_address[18];
    SensorReading readings[4];
    uint8_t num_readings;
    uint16_t sequence;
    int8_t rssi;
} ESPNowPacket;

// ============================================================================
// VARIÁVEIS GLOBAIS
// ============================================================================

uint32_t packetsReceived = 0;
uint32_t packetsSent = 0;
uint32_t packetsError = 0;
unsigned long lastHeartbeat = 0;
unsigned long lastLedBlink = 0;
unsigned long lastTempRead = 0;

bool ethernetConnected = false;
bool wifiStaConnected = false;
bool wifiApActive = false;
uint8_t apClientsConnected = 0;

EthernetClient ethClient;
WiFiClient wifiClient;

// ============================================================================
// DECLARAÇÕES DE FUNÇÕES
// ============================================================================

void onDataRecv(uint8_t *mac, uint8_t *data, uint8_t len);

// ============================================================================
// FUNÇÕES AUXILIARES
// ============================================================================

void blinkLED(int count)
{
    for (int i = 0; i < count; i++)
    {
        digitalWrite(LED_PIN, LOW);
        delay(100);
        digitalWrite(LED_PIN, HIGH);
        if (i < count - 1)
            delay(100);
    }
}

String macToString(const uint8_t *mac)
{
    char macStr[18];
    snprintf(macStr, sizeof(macStr), "%02X:%02X:%02X:%02X:%02X:%02X",
             mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
    return String(macStr);
}

// ============================================================================
// INICIALIZAÇÃO ETHERNET
// ============================================================================

bool initEthernet()
{
    Serial.println("\n[ETH] Inicializando Ethernet ENC28J60 (EthernetENC)...");

    pinMode(ETH_CS_PIN, OUTPUT);
    digitalWrite(ETH_CS_PIN, HIGH);
    delay(10);

    SPI.begin();
    SPI.setBitOrder(MSBFIRST);
    SPI.setDataMode(SPI_MODE0);
    SPI.setClockDivider(SPI_CLOCK_DIV4);
    delay(50);

    Serial.println("[ETH] Tentando conectar módulo...");

    Ethernet.begin(mac, ip, dnsServer, gateway, subnet);
    delay(1000);

    IPAddress localIP = Ethernet.localIP();
    if (localIP[0] == 0)
    {
        Serial.println("[ETH] ✗ Falha ao inicializar módulo ENC28J60");
        ethernetConnected = false;
        return false;
    }

    Serial.print("[ETH] ✓ Inicializado! IP: ");
    Serial.println(localIP);

    if (Ethernet.linkStatus() == LinkON)
    {
        Serial.println("[ETH] ✓ Link físico detectado (cabo conectado)");
        ethernetConnected = true;
        return true;
    }
    else
    {
        Serial.println("[ETH] ⚠️  Módulo inicializado mas SEM cabo conectado");
        ethernetConnected = false;
        return false;
    }
}

// ============================================================================
// INICIALIZAÇÃO WiFi AP (Access Point)
// ============================================================================

bool initWiFiAP()
{
    Serial.println("\n[WiFi-AP] Criando Access Point 'aguada'...");

    WiFi.mode(WIFI_AP_STA);  // Modo híbrido: AP + STA
    
    // Configurar IP do AP
    WiFi.softAPConfig(apIP, apGateway, apSubnet);
    
    // Criar AP
    bool apStarted = WiFi.softAP(AP_SSID, AP_PASSWORD, AP_CHANNEL, AP_HIDDEN, AP_MAX_CONNECTIONS);
    
    if (apStarted)
    {
        IPAddress myIP = WiFi.softAPIP();
        Serial.println("[WiFi-AP] ✓ AP Criado com sucesso!");
        Serial.println("  SSID: " + String(AP_SSID));
        Serial.println("  Password: " + String(AP_PASSWORD));
        Serial.println("  IP: " + myIP.toString());
        Serial.println("  Canal: " + String(AP_CHANNEL));
        Serial.println("  Max Clients: " + String(AP_MAX_CONNECTIONS));
        wifiApActive = true;
        return true;
    }
    else
    {
        Serial.println("[WiFi-AP] ✗ Falha ao criar AP");
        wifiApActive = false;
        return false;
    }
}

// ============================================================================
// INICIALIZAÇÃO WiFi STA (Station - Fallback)
// ============================================================================

bool tryConnectWiFiSTA()
{
    Serial.println("\n[WiFi-STA] Tentando conectar em redes fallback...");
    
    for (int i = 0; i < NUM_WIFI_NETWORKS; i++)
    {
        Serial.print("[WiFi-STA] Tentando: ");
        Serial.println(wifi_networks[i].ssid);
        
        WiFi.begin(wifi_networks[i].ssid, wifi_networks[i].password);
        
        unsigned long startAttempt = millis();
        while (WiFi.status() != WL_CONNECTED && 
               millis() - startAttempt < WIFI_CONNECT_TIMEOUT_MS)
        {
            delay(100);
        }
        
        if (WiFi.status() == WL_CONNECTED)
        {
            Serial.println("[WiFi-STA] ✓ Conectado!");
            Serial.println("  IP: " + WiFi.localIP().toString());
            Serial.println("  Gateway: " + WiFi.gatewayIP().toString());
            current_network_index = i;
            wifiStaConnected = true;
            return true;
        }
        
        Serial.println("[WiFi-STA] ✗ Timeout");
    }
    
    Serial.println("[WiFi-STA] ⚠️  Nenhuma rede disponível (usando apenas AP)");
    wifiStaConnected = false;
    return false;
}

// ============================================================================
// INICIALIZAÇÃO ESP-NOW
// ============================================================================

bool initESPNow()
{
    Serial.println("\n[ESP-NOW] Inicializando...");

    wifi_set_channel(ESPNOW_CHANNEL);

    if (esp_now_init() != 0)
    {
        Serial.println("[ESP-NOW] ✗ Falha na inicialização");
        return false;
    }

    esp_now_set_self_role(ESP_NOW_ROLE_SLAVE);
    esp_now_register_recv_cb(onDataRecv);

    Serial.println("[ESP-NOW] ✓ Inicializado no canal 11");
    Serial.println("[ESP-NOW] ✓ Compatível com WiFi AP no mesmo canal");
    return true;
}

// ============================================================================
// INICIALIZAÇÃO 1-Wire (DS18B20)
// ============================================================================

bool init1Wire()
{
    Serial.println("\n[1-Wire] Inicializando sensor DS18B20...");
    
    sensors.begin();
    
    int deviceCount = sensors.getDeviceCount();
    
    if (deviceCount > 0)
    {
        Serial.println("[1-Wire] ✓ " + String(deviceCount) + " sensor(es) detectado(s)");
        
        // Ler temperatura inicial
        sensors.requestTemperatures();
        currentTemperature = sensors.getTempCByIndex(0);
        Serial.println("  Temperatura: " + String(currentTemperature) + "°C");
        
        return true;
    }
    else
    {
        Serial.println("[1-Wire] ⚠️  Nenhum sensor DS18B20 detectado");
        return false;
    }
}

// ============================================================================
// LEITURA DE TEMPERATURA
// ============================================================================

void readTemperature()
{
    sensors.requestTemperatures();
    float temp = sensors.getTempCByIndex(0);
    
    if (temp != DEVICE_DISCONNECTED_C && temp != -127.0)
    {
        currentTemperature = temp;
        Serial.println("[1-Wire] Temperatura: " + String(currentTemperature, 1) + "°C");
    }
    else
    {
        Serial.println("[1-Wire] ⚠️  Erro na leitura de temperatura");
    }
}

// ============================================================================
// ENVIO DE DADOS
// ============================================================================

bool sendViaEthernet(const String &jsonPayload)
{
    if (!ethernetConnected)
        return false;

    Serial.println("[ETH] Enviando via Ethernet...");

    if (ethClient.connected())
    {
        ethClient.stop();
        delay(10);
    }

    if (ethClient.connect(SERVER_IP, SERVER_PORT))
    {
        ethClient.println("POST " + String(API_PATH) + " HTTP/1.1");
        ethClient.println("Host: " + String(SERVER_IP));
        ethClient.println("Content-Type: application/json");
        ethClient.print("Content-Length: ");
        ethClient.println(jsonPayload.length());
        ethClient.println("Connection: close");
        ethClient.println();
        ethClient.println(jsonPayload);

        unsigned long timeout = millis() + 3000;
        while (ethClient.connected() && millis() < timeout)
        {
            if (ethClient.available())
            {
                String line = ethClient.readStringUntil('\n');
                if (line.startsWith("HTTP/1.1 200") || line.startsWith("HTTP/1.1 201"))
                {
                    Serial.println("[ETH] ✓ " + line);
                    ethClient.stop();
                    return true;
                }
            }
            delay(5);
        }

        ethClient.stop();
        Serial.println("[ETH] ✗ Timeout ou resposta inválida");
        return false;
    }
    else
    {
        Serial.println("[ETH] ✗ Falha ao conectar ao servidor");
        return false;
    }
}

bool sendViaWiFi(const String &jsonPayload)
{
    if (!wifiStaConnected)
        return false;

    Serial.println("[WiFi-STA] Enviando via WiFi...");

    HTTPClient http;
    String url = "http://" + String(SERVER_IP) + ":" + String(SERVER_PORT) + String(API_PATH);

    http.begin(wifiClient, url);
    http.addHeader("Content-Type", "application/json");

    int httpCode = http.POST(jsonPayload);

    if (httpCode == HTTP_CODE_OK || httpCode == HTTP_CODE_CREATED)
    {
        Serial.println("[WiFi-STA] ✓ " + String(httpCode) + " OK");
        http.end();
        return true;
    }
    else
    {
        Serial.printf("[WiFi-STA] ✗ Erro HTTP: %d\n", httpCode);
        http.end();
        return false;
    }
}

bool sendToServer(const String &jsonPayload)
{
    // Prioridade 1: Ethernet
    if (ethernetConnected)
    {
        if (sendViaEthernet(jsonPayload))
        {
            return true;
        }
        Serial.println("[!] Ethernet falhou, tentando WiFi...");
    }

    // Prioridade 2: WiFi STA
    if (wifiStaConnected)
    {
        if (sendViaWiFi(jsonPayload))
        {
            return true;
        }
        Serial.println("[!] WiFi STA também falhou");
    }

    Serial.println("[!] ✗ Dados perdidos - sem conectividade");
    return false;
}

// ============================================================================
// CALLBACK ESP-NOW
// ============================================================================

void onDataRecv(uint8_t *mac, uint8_t *data, uint8_t len)
{
    blinkLED(2);

    packetsReceived++;

    ESPNowPacket packet;
    memcpy(&packet, data, sizeof(packet));

    int8_t rssi = -50;
    packet.rssi = rssi;

    String jsonPayload = "{";
    jsonPayload += "\"mac_address\":\"" + macToString(mac) + "\",";
    jsonPayload += "\"readings\":[";

    for (uint8_t i = 0; i < packet.num_readings; i++)
    {
        if (i > 0)
            jsonPayload += ",";
        jsonPayload += "{";
        jsonPayload += "\"sensor_id\":" + String(packet.readings[i].sensor_id) + ",";
        jsonPayload += "\"distance_cm\":" + String(packet.readings[i].distance_cm);
        jsonPayload += "}";
    }

    jsonPayload += "],";
    jsonPayload += "\"sequence\":" + String(packet.sequence) + ",";
    jsonPayload += "\"rssi\":" + String(rssi);
    jsonPayload += "}";

    Serial.println("\n[RX] Pacote ESP-NOW recebido:");
    Serial.println("  MAC: " + macToString(mac));
    Serial.println("  Leituras: " + String(packet.num_readings));
    Serial.println("  Sequence: " + String(packet.sequence));
    Serial.println("  RSSI: " + String(rssi) + " dBm");
    Serial.println("  JSON: " + jsonPayload);

    if (sendToServer(jsonPayload))
    {
        packetsSent++;
        Serial.println("[TX] ✓ Enviado com sucesso!");
    }
    else
    {
        packetsError++;
        Serial.println("[TX] ✗ Falha no envio!");
    }
}

// ============================================================================
// HEARTBEAT
// ============================================================================

void heartbeat()
{
    if (millis() - lastHeartbeat >= 10000)
    {
        lastHeartbeat = millis();

        Serial.println("\n[HB] ============================================");
        Serial.println("[HB] Uptime: " + String(millis() / 1000) + "s");
        Serial.println("[HB] Pacotes: RX:" + String(packetsReceived) + 
                       " TX:" + String(packetsSent) + 
                       " ERR:" + String(packetsError));

        Serial.print("[HB] Conectividade: ");
        if (wifiApActive)
        {
            apClientsConnected = WiFi.softAPgetStationNum();
            Serial.print("AP✓(" + String(apClientsConnected) + " clients) ");
        }
        if (wifiStaConnected) Serial.print("STA✓ ");
        if (ethernetConnected) Serial.print("ETH✓ ");
        if (!ethernetConnected && !wifiStaConnected && !wifiApActive) Serial.print("OFFLINE");
        Serial.println();
        
        Serial.println("[HB] Temperatura: " + String(currentTemperature, 1) + "°C");
        Serial.println("[HB] ============================================\n");
    }
}

// ============================================================================
// MONITORAMENTO PERIÓDICO
// ============================================================================

void periodicTasks()
{
    // Ler temperatura a cada TEMP_READ_INTERVAL
    if (millis() - lastTempRead >= TEMP_READ_INTERVAL)
    {
        lastTempRead = millis();
        readTemperature();
    }
    
    // Piscar LED periodicamente
    if (millis() - lastLedBlink >= LED_BLINK_INTERVAL)
    {
        lastLedBlink = millis();
        blinkLED(3);
    }
}

// ============================================================================
// SETUP
// ============================================================================

void setup()
{
    Serial.begin(115200);
    delay(1000);

    Serial.println("\n\n");
    Serial.println("========================================");
    Serial.println("  AGUADA - Gateway Multifuncional v3.0");
    Serial.println("========================================");
    Serial.println("WiFi AP: 'aguada' (senha: aguada2025)");
    Serial.println("WiFi STA: Fallback para uplink");
    Serial.println("ESP-NOW: Canal 11");
    Serial.println("Ethernet: ENC28J60 (prioridade)");
    Serial.println("1-Wire: DS18B20 (temperatura)");
    Serial.println("========================================\n");

    pinMode(LED_PIN, OUTPUT);
    digitalWrite(LED_PIN, HIGH);
    blinkLED(2);

    // ORDEM DE INICIALIZAÇÃO:
    // 1. WiFi AP (cria rede "aguada")
    initWiFiAP();
    
    // 2. WiFi STA (conecta em redes externas - fallback)
    tryConnectWiFiSTA();
    
    // 3. ESP-NOW (mesmo canal do AP)
    initESPNow();
    
    // 4. Ethernet (prioridade para envio)
    initEthernet();
    
    // 5. 1-Wire (sensor de temperatura)
    init1Wire();

    Serial.println("\n========================================");
    Serial.println("✓ Sistema pronto!");
    Serial.println("========================================");
    Serial.println("📡 WiFi AP: aguada (Canal 11)");
    Serial.println("   → Nodes podem conectar diretamente");
    Serial.println("");
    Serial.println("📶 Prioridade de transmissão:");
    Serial.println("   1º - Ethernet (192.168.0.150)");
    Serial.println("   2º - WiFi STA (fallback)");
    Serial.println("");
    Serial.println("📻 ESP-NOW: Canal 11 (compatível com AP)");
    Serial.println("🌡️  Temperatura: " + String(currentTemperature, 1) + "°C");
    Serial.println("");
    Serial.println("Aguardando pacotes ESP-NOW...\n");

    lastHeartbeat = millis();
    lastLedBlink = millis();
    lastTempRead = millis();
}

// ============================================================================
// LOOP
// ============================================================================

void loop()
{
    if (ethernetConnected)
    {
        Ethernet.maintain();

        static unsigned long lastLinkCheck = 0;
        if (millis() - lastLinkCheck > 5000)
        {
            lastLinkCheck = millis();
            if (Ethernet.linkStatus() != LinkON)
            {
                Serial.println("[ETH] ⚠️  Link perdido! Usando WiFi...");
                ethernetConnected = false;
            }
        }
    }
    else
    {
        static unsigned long lastReconnect = 0;
        if (millis() - lastReconnect > 30000)
        {
            lastReconnect = millis();
            if (Ethernet.linkStatus() == LinkON)
            {
                Serial.println("[ETH] Link detectado! Reativando Ethernet...");
                ethernetConnected = true;
            }
        }
    }

    heartbeat();

    // Tarefas periódicas (LED e temperatura)
    periodicTasks();

    delay(10);
}
