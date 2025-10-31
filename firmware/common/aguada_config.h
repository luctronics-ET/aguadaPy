/**
 * @file aguada_config.h
 * @brief Configurações globais do Sistema Aguada V2
 * @author CMASM Team
 * @date 2025-10-13
 */

#ifndef AGUADA_CONFIG_H
#define AGUADA_CONFIG_H

// ============================================
// VERSÃO DO FIRMWARE
// ============================================
#define FIRMWARE_VERSION "2.0.0"
#define PROTOCOL_VERSION 1

// ============================================
// PINOUT ESP32-C3 SUPER MINI
// ============================================
// Referência: https://www.espboards.dev/esp32/esp32-c3-super-mini/
//
// Sensor Ultrassônico HC-SR04 (ÚNICO POR NODE)
#define HC_SR04_ECHO_GPIO 0 // Echo input
#define HC_SR04_TRIG_GPIO 1 // Trigger output

// I2C RESERVADO (expansão futura - sensores adicionais)
// NOTA: GPIO8 tem LED interno, mas está RESERVADO para I2C SDA
#define I2C_SDA_GPIO 8 // ⚠️ RESERVADO - Não utilizar
#define I2C_SCL_GPIO 9 // ⚠️ RESERVADO - Não utilizar

// Outros pinos disponíveis
#define BUTTON_GPIO 10 // Para uso futuro

// ============================================
// ESP-NOW CONFIGURATION
// ============================================
#define ESP_NOW_CHANNEL 11 // ✅ Canal 11 - Mesma rede do gateway (luciano)
#define ESP_NOW_QUEUE_SIZE 10
#define ESP_NOW_MAX_RETRIES 3
#define ESP_NOW_ENCRYPT 0 // Desabilitado inicialmente

// ============================================
// WIFI AP CONFIGURATION (Acesso Técnico)
// ============================================
#define WIFI_AP_SSID_PREFIX "Aguada-" // Completa com node_id
#define WIFI_AP_PASSWORD "aguada2025"
#define WIFI_AP_CHANNEL 11
#define WIFI_AP_MAX_CONNECTIONS 5
#define WIFI_AP_IP "192.168.4.1"

// ============================================
// SENSOR SETTINGS
// ============================================
#define MEASUREMENT_INTERVAL_MS 30000 // 30 segundos entre leituras
#define ULTRASONIC_TIMEOUT_US 38000   // 38ms timeout (máx ~600cm / 6m)

// VALORES DE ERRO
#define SENSOR_ERROR_VALUE 0xFFFF  // Enviado quando HC-SR04 falha/timeout
#define SENSOR_OUT_OF_RANGE 0xFFFE // Opcional: fora de range esperado

// Node SEMPRE envia dados, mesmo com erro
// Backend decide como tratar 0xFFFF (ignorar, alertar, etc)

// ============================================
// GATEWAY SETTINGS
// ============================================
#define GATEWAY_BUFFER_SIZE 32 // Pacotes em buffer
#define HTTP_POST_TIMEOUT_MS 5000
#define HTTP_RETRY_INTERVAL_MS 10000

// URL do backend aguadaPy (pode ser sobrescrito por NVS)
#define DEFAULT_BACKEND_URL "http://192.168.1.100:3000/api/leituras/raw"

// ============================================
// DEBUGGING
// ============================================
#define DEBUG_MODE 1

#if DEBUG_MODE
#define DEBUG_PRINT(tag, fmt, ...) ESP_LOGI(tag, fmt, ##__VA_ARGS__)
#else
#define DEBUG_PRINT(tag, fmt, ...)
#endif

#endif // AGUADA_CONFIG_H
