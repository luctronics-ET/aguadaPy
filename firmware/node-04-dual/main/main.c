/**
 * @file main.c
 * @brief Node Aguada 04 - DUAL SENSOR
 * Ultra1: value_id=1, HC-SR04 em GPIO0/1
 * Ultra2: value_id=2, HC-SR04 em GPIO2/3
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

#include "../../common/aguada_config.h"
#include "../../common/sensor_packet.h"
#include "../../common/node_definitions.h"
#include "../../components/hc_sr04/hc_sr04.h"

static const char *TAG = "NODE_04";

static hc_sr04_t sensor1;
static hc_sr04_t sensor2;

typedef struct {
    uint8_t my_mac[6];
    uint32_t measurements_count;
    uint32_t errors_count;
    uint32_t send_success;
    uint32_t send_fail;
    uint16_t packet_sequence;
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

static uint16_t read_sensor(hc_sr04_t *sensor, const char* sensor_name) {
    float dist_cm = hc_sr04_measure_cm(sensor);
    if (dist_cm > 0 && dist_cm < 700) {
        ESP_LOGI(TAG, "📏 %s: %.1f cm", sensor_name, dist_cm);
        return (uint16_t)dist_cm;
    }
    ESP_LOGW(TAG, "⚠️  %s falhou/fora de range", sensor_name);
    return SENSOR_ERROR_VALUE;
}

static esp_err_t send_packet(uint16_t distance_cm, uint8_t value_id) {
    sensor_packet_t packet;
    memcpy(packet.mac, g_state.my_mac, 6);
    packet.value_id = value_id;
    packet.value_data = distance_cm;
    packet.sequence = g_state.packet_sequence++;
    packet.rssi = 0;
    packet.reserved = 0;

    ESP_LOGI(TAG, "📤 Enviando: seq=%u, value_id=%u, dist=%u cm", 
             packet.sequence, value_id, distance_cm);

    uint8_t broadcast_mac[6] = {0xFF,0xFF,0xFF,0xFF,0xFF,0xFF};
    return esp_now_send(broadcast_mac, (uint8_t *)&packet, sizeof(sensor_packet_t));
}

static void measurement_task(void *pvParameters) {
    while (1) {
        // Ler Ultra 1
        uint16_t distance1 = read_sensor(&sensor1, "Ultra1(GPIO0/1)");
        if (distance1 == SENSOR_ERROR_VALUE) g_state.errors_count++;
        ESP_LOGI(TAG, "Sensor1 -> value_id=1, distancia=%u cm", distance1);
        vTaskDelay(pdMS_TO_TICKS(100));
        send_packet(distance1, 1);
        g_state.measurements_count++;
        
        // Ler Ultra 2 (sem delay adicional)
        uint16_t distance2 = read_sensor(&sensor2, "Ultra2(GPIO2/3)");
        if (distance2 == SENSOR_ERROR_VALUE) g_state.errors_count++;
        ESP_LOGI(TAG, "Sensor2 -> value_id=2, distancia=%u cm", distance2);
        vTaskDelay(pdMS_TO_TICKS(100));
        send_packet(distance2, 2);
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

    // Inicializar Ultra 1 (GPIO0/1)
    hc_sr04_config_t sensor1_config = {
        .trig_pin = 1,
        .echo_pin = 0,
        .timeout_us = ULTRASONIC_TIMEOUT_US
    };
    esp_err_t err1 = hc_sr04_init(&sensor1, &sensor1_config);
    if (err1 != ESP_OK) {
        ESP_LOGE(TAG, "Falha ao iniciar HC-SR04 Ultra1: %s", esp_err_to_name(err1));
    } else {
        ESP_LOGI(TAG, "HC-SR04 Ultra1 inicializado: ECHO=GPIO0, TRIG=GPIO1");
    }

    // Inicializar Ultra 2 (GPIO2/3)
    hc_sr04_config_t sensor2_config = {
        .trig_pin = 3,
        .echo_pin = 2,
        .timeout_us = ULTRASONIC_TIMEOUT_US
    };
    esp_err_t err2 = hc_sr04_init(&sensor2, &sensor2_config);
    if (err2 != ESP_OK) {
        ESP_LOGE(TAG, "Falha ao iniciar HC-SR04 Ultra2: %s", esp_err_to_name(err2));
    } else {
        ESP_LOGI(TAG, "HC-SR04 Ultra2 inicializado: ECHO=GPIO2, TRIG=GPIO3");
    }

    init_espnow();

    xTaskCreate(measurement_task, "measurement_task", 4096, NULL, 5, NULL);
}
