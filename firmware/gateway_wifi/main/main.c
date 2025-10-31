/*
 * Gateway ESP32-C3 - Aguada V2
 *
 * Funcionalidades:
 * - Recebe dados via ESP-NOW dos nodes
 * - Conecta ao WiFi (múltiplas redes com failover)
 * - Envia dados para backend Flask via HTTP POST
 * - Access Point local para configuração
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/event_groups.h"
#include "freertos/queue.h"
#include "esp_system.h"
#include "esp_wifi.h"
#include "esp_event.h"
#include "esp_log.h"
#include "esp_now.h"
#include "esp_netif.h"
#include "esp_http_client.h"
#include "nvs_flash.h"
#include "esp_timer.h"
#include "cJSON.h"
#include "../../common/node_definitions.h"
#include "../../common/sensor_packet.h"

#define TAG "GATEWAY"

// ==================== CONFIGURAÇÕES ====================

// WiFi Networks (from old working code)
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
static int current_network_index = -1;

// WiFi Configuration
#define WIFI_CHANNEL 11
#define WIFI_CONNECT_TIMEOUT_MS 10000 // ✅ Reduzido para 10s (tenta próxima rede mais rápido)
#define WIFI_AP_SSID "GTW-01"
#define WIFI_AP_PASSWORD "aguada2025"
#define WIFI_AP_MAX_CONNECTIONS 6

// Backend Configuration - aguadaPy Docker
#define BACKEND_URL "http://192.168.0.101:3000/api/leituras/raw" // ✅ FastAPI aguadaPy
#define HTTP_TIMEOUT_MS 5000

// ESP-NOW
#define ESPNOW_QUEUE_SIZE 10

// ==================== ESTRUTURAS ====================

// Usa o sensor_packet_t comum (com value_id)

// Gateway state
typedef struct
{
    bool wifi_connected;
    bool backend_available;
    uint32_t packets_rx;
    uint32_t packets_tx;
    uint32_t errors;
} gateway_state_t;

// ==================== VARIÁVEIS GLOBAIS ====================

static gateway_state_t g_state = {0};
static EventGroupHandle_t s_wifi_event_group;
static QueueHandle_t s_espnow_queue;

#define WIFI_CONNECTED_BIT BIT0
#define WIFI_FAIL_BIT BIT1

// ==================== FUNÇÕES WiFi ====================

/**
 * WiFi event handler
 */
static void wifi_event_handler(void *arg, esp_event_base_t event_base,
                               int32_t event_id, void *event_data)
{
    if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_DISCONNECTED)
    {
        g_state.wifi_connected = false;
        g_state.backend_available = false;
        ESP_LOGW(TAG, "WiFi STA desconectado, reconectando...");
        esp_wifi_connect();
    }
    else if (event_base == IP_EVENT && event_id == IP_EVENT_STA_GOT_IP)
    {
        ip_event_got_ip_t *event = (ip_event_got_ip_t *)event_data;
        ESP_LOGI(TAG, "✅ WiFi conectado! IP: " IPSTR, IP2STR(&event->ip_info.ip));
        if (current_network_index >= 0)
        {
            ESP_LOGI(TAG, "   Rede: %s", wifi_networks[current_network_index].ssid);
        }
        g_state.wifi_connected = true;
        g_state.backend_available = true;
        xEventGroupSetBits(s_wifi_event_group, WIFI_CONNECTED_BIT);
    }
}

/**
 * Try to connect to a specific WiFi network
 */
static esp_err_t try_connect_network(int network_index)
{
    if (network_index >= NUM_WIFI_NETWORKS)
    {
        return ESP_ERR_INVALID_ARG;
    }

    const wifi_network_t *network = &wifi_networks[network_index];

    wifi_config_t wifi_config_sta = {0};
    strncpy((char *)wifi_config_sta.sta.ssid, network->ssid,
            sizeof(wifi_config_sta.sta.ssid) - 1);
    strncpy((char *)wifi_config_sta.sta.password, network->password,
            sizeof(wifi_config_sta.sta.password) - 1);
    wifi_config_sta.sta.threshold.authmode =
        (strlen(network->password) == 0) ? WIFI_AUTH_OPEN : WIFI_AUTH_WPA2_PSK;

    ESP_LOGI(TAG, "🔄 Conectando a: %s", network->ssid);

    // Ensure any previous connection attempt is cancelled before reconfiguring STA
    esp_wifi_disconnect();
    vTaskDelay(pdMS_TO_TICKS(300));

    ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_STA, &wifi_config_sta));
    esp_wifi_connect();

    // Wait for connection
    EventBits_t bits = xEventGroupWaitBits(
        s_wifi_event_group, WIFI_CONNECTED_BIT | WIFI_FAIL_BIT,
        pdTRUE, pdFALSE, pdMS_TO_TICKS(WIFI_CONNECT_TIMEOUT_MS));

    if (bits & WIFI_CONNECTED_BIT)
    {
        current_network_index = network_index;
        return ESP_OK;
    }

    ESP_LOGW(TAG, "❌ Falha: %s", network->ssid);
    return ESP_FAIL;
}

/**
 * Initialize WiFi in APSTA mode
 */
static esp_err_t init_wifi(void)
{
    ESP_LOGI(TAG, "Inicializando WiFi APSTA...");

    s_wifi_event_group = xEventGroupCreate();

    // Create both AP and STA interfaces
    esp_netif_create_default_wifi_ap();
    esp_netif_create_default_wifi_sta();

    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    ESP_ERROR_CHECK(esp_wifi_init(&cfg));

    // Register event handlers
    ESP_ERROR_CHECK(esp_event_handler_register(WIFI_EVENT, ESP_EVENT_ANY_ID,
                                               &wifi_event_handler, NULL));
    ESP_ERROR_CHECK(esp_event_handler_register(IP_EVENT, IP_EVENT_STA_GOT_IP,
                                               &wifi_event_handler, NULL));

    // Configure AP
    wifi_config_t wifi_config_ap = {
        .ap = {
            .ssid = WIFI_AP_SSID,
            .ssid_len = strlen(WIFI_AP_SSID),
            .channel = WIFI_CHANNEL,
            .password = WIFI_AP_PASSWORD,
            .max_connection = WIFI_AP_MAX_CONNECTIONS,
            .authmode = WIFI_AUTH_WPA2_PSK,
        },
    };

    // CRITICAL: APSTA mode for ESP-NOW + Internet
    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_APSTA));
    ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_AP, &wifi_config_ap));
    ESP_ERROR_CHECK(esp_wifi_start());

    uint8_t channel;
    wifi_second_chan_t second;
    esp_wifi_get_channel(&channel, &second);
    ESP_LOGI(TAG, "✅ WiFi AP: %s (Canal %d)", WIFI_AP_SSID, channel);

    // Try to connect to WiFi networks
    for (int i = 0; i < NUM_WIFI_NETWORKS; i++)
    {
        if (try_connect_network(i) == ESP_OK)
        {
            break;
        }
    }

    if (current_network_index < 0)
    {
        ESP_LOGW(TAG, "⚠️  Sem internet - apenas AP local");
    }

    return ESP_OK;
}

// ==================== ESP-NOW ====================

/**
 * ESP-NOW receive callback - Captura RSSI
 */
static void espnow_recv_cb(const esp_now_recv_info_t *recv_info, const uint8_t *data, int len)
{
    if (len == sizeof(sensor_packet_t))
    {
        sensor_packet_t packet;
        memcpy(&packet, data, sizeof(sensor_packet_t));

        // ✅ CAPTURA RSSI DO SINAL RECEBIDO
        packet.rssi = recv_info->rx_ctrl->rssi;

        ESP_LOGI(TAG, "📥 RX: MAC=%02X:%02X:%02X:%02X:%02X:%02X, seq=%u, value_id=%u, dist=%u cm, RSSI=%d dBm",
                 packet.mac[0], packet.mac[1], packet.mac[2],
                 packet.mac[3], packet.mac[4], packet.mac[5],
                 packet.sequence, packet.value_id, packet.value_data, packet.rssi);

        // Send to queue for processing
        if (xQueueSend(s_espnow_queue, &packet, 0) != pdTRUE)
        {
            ESP_LOGW(TAG, "ESP-NOW queue full!");
            g_state.errors++;
        }
        else
        {
            g_state.packets_rx++;
        }
    }
    else
    {
        ESP_LOGW(TAG, "Pacote inválido: %d bytes (esperado %d)", len, sizeof(sensor_packet_t));
        g_state.errors++;
    }
}

/**
 * Initialize ESP-NOW
 */
static esp_err_t init_espnow(void)
{
    ESP_LOGI(TAG, "Inicializando ESP-NOW...");

    s_espnow_queue = xQueueCreate(ESPNOW_QUEUE_SIZE, sizeof(sensor_packet_t));
    if (s_espnow_queue == NULL)
    {
        ESP_LOGE(TAG, "Falha ao criar queue");
        return ESP_FAIL;
    }

    ESP_ERROR_CHECK(esp_now_init());
    ESP_ERROR_CHECK(esp_now_register_recv_cb(espnow_recv_cb));

    // Set primary master key (optional)
    uint8_t pmk[16] = {0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77,
                       0x88, 0x99, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF};
    ESP_ERROR_CHECK(esp_now_set_pmk(pmk));

    ESP_LOGI(TAG, "✅ ESP-NOW inicializado");
    return ESP_OK;
}

// ==================== HTTP ====================

/**
 * Send sensor data to backend
 */
static esp_err_t send_to_backend(sensor_packet_t *packet, int rssi)
{
    // ALWAYS try to send - retry logic for backend reconnection

    // Build JSON para api_gateway_v2.php
    cJSON *json = cJSON_CreateObject();

    char mac_str[18];
    snprintf(mac_str, sizeof(mac_str), "%02X:%02X:%02X:%02X:%02X:%02X",
             packet->mac[0], packet->mac[1], packet->mac[2],
             packet->mac[3], packet->mac[4], packet->mac[5]);

    // Formato para api_gateway_v2.php: {mac_address, readings[], sequence, rssi}
    cJSON_AddStringToObject(json, "mac_address", mac_str);

    // Array de readings (por enquanto 1 sensor por pacote)
    cJSON *readings = cJSON_CreateArray();
    cJSON *reading = cJSON_CreateObject();
    cJSON_AddNumberToObject(reading, "sensor_id", packet->value_id);
    cJSON_AddNumberToObject(reading, "distance_cm", packet->value_data);
    cJSON_AddItemToArray(readings, reading);
    cJSON_AddItemToObject(json, "readings", readings);

    cJSON_AddNumberToObject(json, "sequence", packet->sequence);
    cJSON_AddNumberToObject(json, "rssi", packet->rssi);

    char *json_str = cJSON_PrintUnformatted(json);

    ESP_LOGI(TAG, "📤 HTTP POST: %s", json_str);

    // HTTP client config
    esp_http_client_config_t config = {
        .url = BACKEND_URL,
        .timeout_ms = HTTP_TIMEOUT_MS,
    };

    esp_http_client_handle_t client = esp_http_client_init(&config);
    esp_http_client_set_method(client, HTTP_METHOD_POST);
    esp_http_client_set_header(client, "Content-Type", "application/json");
    esp_http_client_set_post_field(client, json_str, strlen(json_str));

    esp_err_t err = esp_http_client_perform(client);

    if (err == ESP_OK)
    {
        int status = esp_http_client_get_status_code(client);
        if (status == 200)
        {
            ESP_LOGI(TAG, "✅ Backend: OK (200)");
            g_state.packets_tx++;
            g_state.backend_available = true; // Mark backend as available on success
        }
        else
        {
            ESP_LOGW(TAG, "⚠️  Backend: status %d", status);
            g_state.errors++;
            g_state.backend_available = false;
        }
    }
    else
    {
        ESP_LOGW(TAG, "❌ HTTP falhou: %s", esp_err_to_name(err));
        g_state.errors++;
        g_state.backend_available = false;
        // Don't give up - will retry on next packet
    }

    esp_http_client_cleanup(client);
    free(json_str);
    cJSON_Delete(json);

    return err;
}

// ==================== TASKS ====================

/**
 * Process ESP-NOW packets
 */
static void espnow_task(void *pvParameter)
{
    sensor_packet_t packet;

    while (1)
    {
        if (xQueueReceive(s_espnow_queue, &packet, portMAX_DELAY) == pdTRUE)
        {

            ESP_LOGI(TAG, "📡 ESP-NOW recebido:");
            ESP_LOGI(TAG, "   MAC: %02X:%02X:%02X:%02X:%02X:%02X",
                     packet.mac[0], packet.mac[1], packet.mac[2],
                     packet.mac[3], packet.mac[4], packet.mac[5]);
            ESP_LOGI(TAG, "   Sequence: %u", packet.sequence); // ✅ Número de sequência
            ESP_LOGI(TAG, "   value_id: %u", packet.value_id);
            ESP_LOGI(TAG, "   Distância: %u cm", packet.value_data);
            ESP_LOGI(TAG, "   RSSI: %d dBm", packet.rssi); // ✅ Qualidade do sinal

            if (packet.value_data == 0xFFFF)
            {
                ESP_LOGW(TAG, "   ⚠️  Node reportou ERRO no sensor!");
            }

            // Send to backend (RSSI já está no packet)
            send_to_backend(&packet, packet.rssi);
        }
    }
}

/**
 * Status monitoring task
 */
static void status_task(void *pvParameter)
{
    while (1)
    {
        ESP_LOGI(TAG, "📊 Status Gateway:");
        ESP_LOGI(TAG, "   WiFi: %s", g_state.wifi_connected ? "ON" : "OFF");
        ESP_LOGI(TAG, "   Backend: %s", g_state.backend_available ? "ONLINE" : "OFFLINE");
        ESP_LOGI(TAG, "   Packets RX: %lu", g_state.packets_rx);
        ESP_LOGI(TAG, "   Packets TX: %lu", g_state.packets_tx);
        ESP_LOGI(TAG, "   Erros: %lu", g_state.errors);
        ESP_LOGI(TAG, "   Free heap: %lu bytes", esp_get_free_heap_size());

        vTaskDelay(pdMS_TO_TICKS(30000)); // 30 seconds
    }
}

// ==================== MAIN ====================

void app_main(void)
{
    ESP_LOGI(TAG, "==============================================");
    ESP_LOGI(TAG, "🌊 CMASM - Aguada V2 - Gateway");
    ESP_LOGI(TAG, "==============================================");

    // Initialize NVS
    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND)
    {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ret = nvs_flash_init();
    }
    ESP_ERROR_CHECK(ret);

    // Initialize network
    ESP_ERROR_CHECK(esp_netif_init());
    ESP_ERROR_CHECK(esp_event_loop_create_default());

    // Initialize WiFi
    ESP_ERROR_CHECK(init_wifi());

    // Initialize ESP-NOW
    ESP_ERROR_CHECK(init_espnow());

    // Create tasks
    xTaskCreate(espnow_task, "espnow_task", 4096, NULL, 5, NULL);
    xTaskCreate(status_task, "status_task", 2048, NULL, 3, NULL);

    ESP_LOGI(TAG, "✅ Gateway pronto!");
    ESP_LOGI(TAG, "   AP: %s", WIFI_AP_SSID);
    ESP_LOGI(TAG, "   Backend: %s", BACKEND_URL);
    ESP_LOGI(TAG, "   ESP-NOW: Canal %d", WIFI_CHANNEL);
}
