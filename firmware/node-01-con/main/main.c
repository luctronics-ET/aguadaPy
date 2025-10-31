/**
 * @file main.c
 * @brief Node Aguada 01 - valor_id=1, HC-SR04 em GPIO0/1
 */

#include <stdio.h>
#include <string.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_system.h"
#include "esp_wifi.h"
#include "esp_event.h"
#include "esp_log.h"
#include "esp_mac.h"
#include "nvs_flash.h"
#include "esp_netif.h"
#include "esp_now.h"
#include "driver/gpio.h"

// Configurações locais
#include "../../common/aguada_config.h"
#include "../../common/sensor_packet.h"
#include "../../common/node_definitions.h"
#include "../../components/hc_sr04/hc_sr04.h"

static const char *TAG = "NODE_01";

static hc_sr04_t sensor;

typedef struct {
    uint8_t my_mac[6];
    uint32_t measurements_count;
    uint32_t errors_count;
    uint32_t send_success;
    uint32_t send_fail;
    uint16_t packet_sequence;    // Número de sequência para detecção de perda
} node_state_t;

static node_state_t g_state = {0};

static void espnow_send_cb(const esp_now_send_info_t *send_info, esp_now_send_status_t status) {
    if (status == ESP_NOW_SEND_SUCCESS) {
        ESP_LOGI(TAG, "✅ ESP-NOW enviado com sucesso");
        g_state.send_success++;
    } else {
        ESP_LOGW(TAG, "❌ ESP-NOW falhou");
        g_state.send_fail++;
    }
}

static void espnow_recv_cb(const esp_now_recv_info_t *recv_info, const uint8_t *data, int len) {
    // Node não recebe
}

static esp_err_t init_espnow(void) {
    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    ESP_ERROR_CHECK(esp_wifi_init(&cfg));
    ESP_ERROR_CHECK(esp_wifi_set_storage(WIFI_STORAGE_RAM));
    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));
    ESP_ERROR_CHECK(esp_wifi_start());

    ESP_ERROR_CHECK(esp_wifi_set_channel(ESP_NOW_CHANNEL, WIFI_SECOND_CHAN_NONE));

    ESP_ERROR_CHECK(esp_now_init());
    ESP_ERROR_CHECK(esp_now_register_send_cb(espnow_send_cb));
    ESP_ERROR_CHECK(esp_now_register_recv_cb(espnow_recv_cb));

    esp_now_peer_info_t peer = {0};
    uint8_t broadcast_mac[6] = {0xFF,0xFF,0xFF,0xFF,0xFF,0xFF};
    memcpy(peer.peer_addr, broadcast_mac, 6);
    peer.channel = ESP_NOW_CHANNEL;
    peer.ifidx = WIFI_IF_STA;
    peer.encrypt = false;
    ESP_ERROR_CHECK(esp_now_add_peer(&peer));
    return ESP_OK;
}

static uint16_t read_sensor(void) {
    float dist_cm = hc_sr04_measure_cm(&sensor);
    if (dist_cm > 0 && dist_cm < 700) {  // Até 7m (margem)
        ESP_LOGI(TAG, "📏 Distância: %.1f cm", dist_cm);
        return (uint16_t)dist_cm;
    }
    ESP_LOGW(TAG, "⚠️  Sensor falhou/ou fora de range");
    return SENSOR_ERROR_VALUE;
}

static esp_err_t send_packet(uint16_t distance_cm, uint8_t value_id) {
    sensor_packet_t packet;
    memcpy(packet.mac, g_state.my_mac, 6);
    packet.value_id = value_id;
    packet.distance_cm = distance_cm;
    packet.sequence = g_state.packet_sequence++;  // Incrementa sequência
    packet.rssi = 0;  // Gateway preenche
    packet.reserved = 0;

    ESP_LOGI(TAG, "📤 Enviando: seq=%u, value_id=%u, dist=%u cm", 
             packet.sequence, value_id, distance_cm);

    uint8_t broadcast_mac[6] = {0xFF,0xFF,0xFF,0xFF,0xFF,0xFF};
    return esp_now_send(broadcast_mac, (uint8_t *)&packet, sizeof(sensor_packet_t));
}

static void measurement_task(void *pvParameters) {
    while (1) {
        uint16_t distance = read_sensor();
        if (distance == SENSOR_ERROR_VALUE) g_state.errors_count++;
        ESP_LOGI(TAG, "Sensor (GPIO0/1) -> value_id=1, distancia=%u cm", distance);
        vTaskDelay(pdMS_TO_TICKS(100));
        send_packet(distance, 1); // value_id = 1
        g_state.measurements_count++;
        ESP_LOGI(TAG, "Medições=%lu, Erros=%lu, OK=%lu, FAIL=%lu",
                 g_state.measurements_count, g_state.errors_count,
                 g_state.send_success, g_state.send_fail);
        vTaskDelay(pdMS_TO_TICKS(MEASUREMENT_INTERVAL_MS));
    }
}

void app_main(void) {
    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ret = nvs_flash_init();
    }
    ESP_ERROR_CHECK(ret);

    esp_efuse_mac_get_default(g_state.my_mac);
    ESP_ERROR_CHECK(esp_netif_init());
    ESP_ERROR_CHECK(esp_event_loop_create_default());

    hc_sr04_config_t sensor_config = {
        .trig_pin = HC_SR04_TRIG_GPIO, // GPIO1
        .echo_pin = HC_SR04_ECHO_GPIO, // GPIO0
        .timeout_us = ULTRASONIC_TIMEOUT_US // 38ms para até 6m
    };
    esp_err_t err = hc_sr04_init(&sensor, &sensor_config);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "Falha ao iniciar HC-SR04: %s", esp_err_to_name(err));
    } else {
        ESP_LOGI(TAG, "HC-SR04 inicializado: ECHO=GPIO0, TRIG=GPIO1");
    }

    init_espnow();

    xTaskCreate(measurement_task, "measurement_task", 4096, NULL, 5, NULL);
}
