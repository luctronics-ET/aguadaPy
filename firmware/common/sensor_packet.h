/**
 * @file sensor_packet.h
 * @brief Protocolo ESP-NOW ESTENDIDO - Aguada V2 + Confiabilidade
 *
 * Payload com melhorias de confiabilidade:
 * Total: 12 bytes por packet
 * - Número de sequência (detectar perda de pacotes)
 * - RSSI (qualidade do sinal)
 * Sem CRC (ESP-NOW já valida)
 * Sem timestamp (backend adiciona)
 * Sem battery (não usado por enquanto)
 */

#ifndef SENSOR_PACKET_H
#define SENSOR_PACKET_H

#include <stdint.h>

/**
 * Sensor data packet ESTENDIDO (12 bytes total)
 *
 * Node envia:
 * - MAC address (identificação automática)
 * - value_id (multi-sensor support   id=1 -> ultra_1_dist_cm, id=2 -> ultra_2_dist_cm)
 * - value_data (distancia_cm, int)
 * - Número de sequência (detectar perda)
 * - RSSI (qualidade sinal - preenchido pelo gateway)
 *
 * Backend faz TODOS os cálculos:
 * - Volume em litros
 * - Percentual
 * - Identificação do node por MAC
 * - Timestamp de recebimento
 * - Detecção de perda de pacotes via sequence
 */
typedef struct __attribute__((packed))
{
    uint8_t mac[6];
    // MAC address do node (6 bytes)
    uint8_t value_id;    // ID do valor/sensor (ex: 0, 1, ... para múltiplos sensores)
    uint16_t value_data; // Distância em cm (2 bytes)
                         // 0xFFFF = erro/timeout no sensor
    uint16_t sequence;   // Número sequencial do pacote (2 bytes)
                         // Incrementa a cada envio, usado para detectar perda
    int8_t rssi;         // RSSI em dBm (1 byte) - preenchido pelo gateway
                         // Range típico: -30 a -90 dBm
    uint8_t reserved;    // Byte reservado para alinhamento/futuras expansões
} sensor_packet_t;

// Tamanho do packet
#define SENSOR_PACKET_SIZE sizeof(sensor_packet_t) // 12 bytes

// Valores especiais para distance_cm
#define SENSOR_ERROR_VALUE 0xFFFF  // Sensor falhou/timeout
#define SENSOR_OUT_OF_RANGE 0xFFFE // Opcional: fora de range

#endif // SENSOR_PACKET_H
