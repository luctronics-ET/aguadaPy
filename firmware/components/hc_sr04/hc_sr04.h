/**
 * @file hc_sr04.h
 * @brief Driver para sensor ultrassônico HC-SR04
 * @note Código adaptado do aguada v1
 */

#ifndef HC_SR04_H
#define HC_SR04_H

#include "driver/gpio.h"
#include "esp_timer.h"
#include <stdint.h>
#include <stdbool.h>

/**
 * @brief Configuração do sensor HC-SR04
 */
typedef struct {
    gpio_num_t trig_pin;
    gpio_num_t echo_pin;
    uint32_t timeout_us;        // Timeout em microsegundos (default: 30000)
} hc_sr04_config_t;

/**
 * @brief Handle do sensor
 */
typedef struct {
    hc_sr04_config_t config;
    bool initialized;
} hc_sr04_t;

/**
 * @brief Inicializa o sensor HC-SR04
 * @param sensor Ponteiro para handle do sensor
 * @param config Configuração do sensor
 * @return ESP_OK se sucesso
 */
esp_err_t hc_sr04_init(hc_sr04_t *sensor, const hc_sr04_config_t *config);

/**
 * @brief Faz uma leitura única do sensor
 * @param sensor Ponteiro para handle do sensor
 * @return Distância em cm, ou -1 se erro
 */
float hc_sr04_measure_cm(hc_sr04_t *sensor);

/**
 * @brief Faz múltiplas leituras e retorna a média
 * @param sensor Ponteiro para handle do sensor
 * @param samples Número de amostras (mínimo 3)
 * @return Distância média em cm, ou -1 se erro
 */
float hc_sr04_measure_avg_cm(hc_sr04_t *sensor, uint8_t samples);

/**
 * @brief Verifica se leitura está dentro do range válido
 * @param distance_cm Distância em cm
 * @param min_cm Distância mínima válida
 * @param max_cm Distância máxima válida
 * @return true se válida
 */
bool hc_sr04_is_valid(float distance_cm, float min_cm, float max_cm);

#endif // HC_SR04_H
