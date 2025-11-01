/**
 * ============================================================================
 * AGUADA - Gateway Híbrido Ethernet + ESP-NOW
 * ============================================================================
 * Versão: 2.1 (ESP-NOW + Ethernet APENAS)
 * Hardware: ESP8266 NodeMCU + ENC28J60
 *
 * Para Arduino IDE:
 * - Board: NodeMCU 1.0 (ESP-12E Module)
 * - Upload Speed: 115200
 * - CPU Frequency: 80MHz
 * - Flash Size: 4MB (FS:2MB OTA:~1019KB)
 *
 * Bibliotecas necessárias (Tools → Manage Libraries):
 * - EthernetENC (v2.0.4+) - https://github.com/Networking-for-Arduino/EthernetENC
 * - ESP8266WiFi (incluído no core ESP8266)
 * - ESP8266HTTPClient (incluído no core ESP8266)
 *
 * ============================================================================
 */

#include <Arduino.h>
#include <ESP8266WiFi.h>
#include <espnow.h>
#include <ESP8266HTTPClient.h>
#include <WiFiClient.h>
#include <EthernetENC.h>
#include <SPI.h>

// ============================================================================
// CONFIGURAÇÕES
// ============================================================================

// WiFi Networks (fallback - apenas 2.4GHz)
typedef struct
{
    const char *ssid;
    const char *password;
    const char *description;
} wifi_network_t;

static const wifi_network_t wifi_networks[] = {
    {"GTW-01", "aguada2025", "Gateway ESP32 AP"},
     {"TP-LINK_BE3344", "", "Rede TP-Link sem senha (192.168.1.x)"},
    {"luciano", "19852012", "Rede fallback (192.168.0.x)"},
};

#define NUM_WIFI_NETWORKS (sizeof(wifi_networks) / sizeof(wifi_networks[0]))
sta#define WIFI_CONNECT_TIMEOUT_MS 10000 // ✅ Reduzido para 10s (tenta próxima rede mais rápido)tic int current_network_index = -1;

// Ethernet (ENC28J60)
#define ETH_CS_PIN 15 // D8
byte mac[] = {0xDE, 0xAD, 0xBE, 0xEF, 0xFE, 0xED};
IPAddress ip(192, 168, 0, 150);
IPAddress gateway(192, 168, 0, 1);
IPAddress subnet(255, 255, 255, 0);
IPAddress dnsServer(8, 8, 8, 8);

// Backend Configuration - aguadaPy Docker
#define BACKEND_URL "http://192.168.0.101:3000/api/leituras/raw" // ✅ FastAPI aguadaPy
#define HTTP_TIMEOUT_MS 5000

// Servidor backend
#define SERVER_IP "192.168.0.101"
#define SERVER_PORT 80
#define API_PATH "/aguada/api_gateway.php"

// ESP-NOW
#define ESPNOW_CHANNEL 11

// LED
#define LED_PIN 16
#define LED_BLINK_INTERVAL 30000

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

bool ethernetConnected = false;
bool wifiConnected = false;

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
// INICIALIZAÇÃO WIFI
// ============================================================================

bool initWiFiStaOnly()
{
    Serial.println("\n[WiFi] Modo STA (canal 11 fixo para ESP-NOW)...");

    WiFi.mode(WIFI_STA);
    WiFi.disconnect();

    wifi_set_channel(ESPNOW_CHANNEL);

    Serial.println("[WiFi] ✓ Modo STA ativo no canal 11");
    Serial.println("[WiFi] ⚠️  WiFi HTTP desabilitado (prioridade: Ethernet)");

    wifiConnected = false;
    return true;
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
    return true;
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
                if (line.startsWith("HTTP/1.1 200"))
                {
                    Serial.println("[ETH] ✓ 200 OK");
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
    if (!wifiConnected)
        return false;

    Serial.println("[WiFi] Enviando via WiFi...");

    HTTPClient http;
    String url = "http://" + String(SERVER_IP) + String(API_PATH);

    http.begin(wifiClient, url);
    http.addHeader("Content-Type", "application/json");

    int httpCode = http.POST(jsonPayload);

    if (httpCode == HTTP_CODE_OK)
    {
        Serial.println("[WiFi] ✓ 200 OK");
        http.end();
        return true;
    }
    else
    {
        Serial.printf("[WiFi] ✗ Erro HTTP: %d\n", httpCode);
        http.end();
        return false;
    }
}

bool sendToServer(const String &jsonPayload)
{
    if (ethernetConnected)
    {
        if (sendViaEthernet(jsonPayload))
        {
            return true;
        }
        Serial.println("[!] Ethernet falhou");
    }

    Serial.println("[!] WiFi HTTP desabilitado (ESP-NOW requer canal 11 fixo)");
    Serial.println("[!] Dados perdidos - verifique conexão Ethernet");

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

        Serial.println("\n[HB] Uptime: " + String(millis() / 1000) + "s | " +
                       "RX:" + String(packetsReceived) + " " +
                       "TX:" + String(packetsSent) + " " +
                       "ERR:" + String(packetsError));

        Serial.print("[HB] Conectividade: ");
        if (ethernetConnected)
            Serial.print("ETH✓ ");
        if (wifiConnected)
            Serial.print("WiFi✓ ");
        if (!ethernetConnected && !wifiConnected)
            Serial.print("NENHUMA ");
        Serial.println();
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
    Serial.println("  AGUADA - Gateway Híbrido v2.1");
    Serial.println("========================================");
    Serial.println("WiFi: Modo STA canal 11 (ESP-NOW)");
    Serial.println("ESP-NOW: Canal 11 FIXO");
    Serial.println("Ethernet: ENC28J60 (prioridade)");
    Serial.println("========================================\n");

    pinMode(LED_PIN, OUTPUT);
    digitalWrite(LED_PIN, HIGH);
    blinkLED(1);

    // ORDEM CORRETA: WiFi STA → ESP-NOW → Ethernet
    initWiFiStaOnly();
    initESPNow();
    initEthernet();

    Serial.println("\n========================================");
    Serial.println("✓ Sistema pronto!");
    Serial.println("========================================");
    Serial.println("Prioridade de transmissão:");
    Serial.println("  1º - Ethernet (192.168.0.150)");
    Serial.println("  2º - WiFi HTTP (desabilitado por padrão)");
    Serial.println("");
    Serial.println("ESP-NOW: ✓ Canal 11 FIXO");
    Serial.println("Aguardando pacotes ESP-NOW...\n");

    lastHeartbeat = millis();
    lastLedBlink = millis();
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

    if (millis() - lastLedBlink >= LED_BLINK_INTERVAL)
    {
        lastLedBlink = millis();
        blinkLED(3);
    }

    delay(10);
}
