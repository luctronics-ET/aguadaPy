/**
 * @file node_definitions.h
 * @brief Definições de Gateways e Nodes - Sistema Aguada V2
 * @date 2025-01-18
 */

#ifndef NODE_DEFINITIONS_H
#define NODE_DEFINITIONS_H

#include <stdint.h>

// ============================================
// GATEWAY 01 - ESP32-C3 Super Mini (Principal)
// ============================================
#define GATEWAY_ID "GTW-01"
#define GATEWAY_ALIAS "GTW01"
#define GATEWAY_MAC_STR "20:6E:F1:6A:B3:28"
static const uint8_t gateway_mac[] = {0x20, 0x6E, 0xF1, 0x6A, 0xB3, 0x28};
#define GATEWAY_CHANNEL 11
#define GATEWAY_LOCATION "Servidor Principal"

// ============================================
// NODE-001 - CON (Castelo de Consumo) - ESP32-C3
// ============================================
#define NODE_001_ID "NODE-001"
#define NODE_001_ALIAS "CON"
#define NODE_001_MAC_STR "DC:06:75:67:6A:CC"
static const uint8_t node_001_mac[] = {0xDC, 0x06, 0x75, 0x67, 0x6A, 0xCC};
#define NODE_001_BOARD "ESP32-C3 Super Mini"
#define NODE_001_LOCATION "Castelo de Consumo"
#define NODE_001_SENSOR "N_01_ULTRA_1"
#define NODE_001_GPIO_TRIG 1
#define NODE_001_GPIO_ECHO 0
#define NODE_001_FIRMWARE_VERSION "v2.0"

// ============================================
// NODE-002 - CAV (Castelo de Incendio) - Arduino Nano + ENC28J60
// ============================================
#define NODE_002_ID "NODE-002"
#define NODE_002_ALIAS "CAV"
#define NODE_002_MAC_STR "AA:BB:CC:DD:EE:02"
static const uint8_t node_002_mac[] = {0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0x02};
#define NODE_002_BOARD "Arduino Nano + ENC28J60"
#define NODE_002_LOCATION "Castelo de Incendio"
#define NODE_002_SENSOR "N_01_ULTRA_2"
#define NODE_002_PIN_TRIG 6 // D6
#define NODE_002_PIN_ECHO 5 // D5
#define NODE_002_IP "192.168.0.202"
#define NODE_002_FIRMWARE_VERSION "v1.0"

// ============================================
// NODE-003 - B03 (Mesmo reservatório CON) - ESP32-C3
// ============================================
#define NODE_003_ID "NODE-003"
#define NODE_003_ALIAS "B03"
#define NODE_003_MAC_STR "20:6E:F1:6B:77:58"
static const uint8_t node_003_mac[] = {0x20, 0x6E, 0xF1, 0x6B, 0x77, 0x58};
#define NODE_003_BOARD "ESP32-C3 Super Mini"
#define NODE_003_LOCATION "Castelo de Consumo"
#define NODE_003_SENSOR "HC-SR04"
#define NODE_003_GPIO_TRIG 1
#define NODE_003_GPIO_ECHO 0
#define NODE_003_FIRMWARE_VERSION "v2.0"

// ============================================
// NODE-004 - DUAL (Dual Sensor) - ESP32-C3
// ============================================
#define NODE_004_ID "NODE-004"
#define NODE_004_ALIAS "CIE"
#define NODE_004_MAC_STR "DC:06:75:67:67:C4"
static const uint8_t node_004_mac[] = {0xDC, 0x06, 0x75, 0x67, 0x67, 0xC4};
#define NODE_004_BOARD "ESP32-C3 Super Mini"
#define NODE_004_LOCATION "Cisternas Ilha do Engenho (CIE)"
#define NODE_004_SENSOR "2x HC-SR04"
#define NODE_004_GPIO_ULTRA1_TRIG 1
#define NODE_004_GPIO_ULTRA1_ECHO 0
#define NODE_004_GPIO_ULTRA2_TRIG 3
#define NODE_004_GPIO_ULTRA2_ECHO 2
#define NODE_004_SENSOR1_DESC "Ultra1 (GPIO0/1) → Cisterna IE1 (250m³)"
#define NODE_004_SENSOR2_DESC "Ultra2 (GPIO2/3) → Cisterna IE2 (250m³)"
#define NODE_004_FIRMWARE_VERSION "v2.0"

// ============================================
// CONFIGURAÇÃO DE REDE
// ============================================
#define WIFI_SSID "luciano"
#define WIFI_PASSWORD "19852012"
#define SERVER_IP "192.168.0.101"
#define SERVER_PORT 80

#endif // NODE_DEFINITIONS_H
