/**
 * @file hc_sr04.c
 * @brief Driver para sensor ultrassônico HC-SR04
 */

#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "hc_sr04.h"
#include "esp_log.h"
#include "esp_rom_sys.h"
#include <string.h>

static const char *TAG = "HC_SR04";

// Velocidade do som: 343 m/s = 0.0343 cm/us
#define SOUND_SPEED_CM_PER_US 0.0343f

esp_err_t hc_sr04_init(hc_sr04_t *sensor, const hc_sr04_config_t *config)
{
    if (!sensor || !config)
    {
        return ESP_ERR_INVALID_ARG;
    }

    memcpy(&sensor->config, config, sizeof(hc_sr04_config_t));

    // Configurar pino TRIG como saída
    gpio_reset_pin(sensor->config.trig_pin);
    gpio_set_direction(sensor->config.trig_pin, GPIO_MODE_OUTPUT);
    gpio_set_level(sensor->config.trig_pin, 0);

    // Configurar pino ECHO como entrada (com pull-down para evitar flutuação)
    gpio_reset_pin(sensor->config.echo_pin);
    gpio_set_direction(sensor->config.echo_pin, GPIO_MODE_INPUT);
    gpio_set_pull_mode(sensor->config.echo_pin, GPIO_PULLDOWN_ONLY);

    sensor->initialized = true;

    ESP_LOGI(TAG, "HC-SR04 inicializado (TRIG=%d, ECHO=%d)",
             sensor->config.trig_pin, sensor->config.echo_pin);

    return ESP_OK;
}

float hc_sr04_measure_cm(hc_sr04_t *sensor)
{
    if (!sensor || !sensor->initialized)
    {
        ESP_LOGE(TAG, "Sensor não inicializado");
        return -1.0f;
    }

    // Garantir que ECHO esteja LOW antes de gerar TRIG (evita resíduos)
    // Primeiro tenta fazer um reset do sensor com múltiplos pulsos TRIG
    gpio_set_level(sensor->config.trig_pin, 0);
    esp_rom_delay_us(10);

    int64_t pre_start = esp_timer_get_time();
    int attempts = 0;
    while (gpio_get_level(sensor->config.echo_pin) == 1)
    {
        if (esp_timer_get_time() - pre_start > 10000)
        { // 10ms de guarda
            ESP_LOGW(TAG, "Echo permaneceu HIGH antes do trigger (tentou %d vezes)", attempts);
            // Última tentativa: forçar pulso TRIG para resetar
            gpio_set_level(sensor->config.trig_pin, 1);
            esp_rom_delay_us(5);
            gpio_set_level(sensor->config.trig_pin, 0);
            esp_rom_delay_us(100);
            if (gpio_get_level(sensor->config.echo_pin) == 1)
            {
                return -1.0f;
            }
            break;
        }
        // Tenta pulso curto para resetar
        if (attempts < 3)
        {
            gpio_set_level(sensor->config.trig_pin, 1);
            esp_rom_delay_us(2);
            gpio_set_level(sensor->config.trig_pin, 0);
            esp_rom_delay_us(50);
            attempts++;
        }
        esp_rom_delay_us(100);
    }

    // Enviar pulso de trigger (10us)
    gpio_set_level(sensor->config.trig_pin, 0);
    esp_rom_delay_us(2);
    gpio_set_level(sensor->config.trig_pin, 1);
    esp_rom_delay_us(10);
    gpio_set_level(sensor->config.trig_pin, 0);

    // Aguardar echo subir (início do pulso)
    int64_t start_time = esp_timer_get_time();
    int64_t timeout = start_time + sensor->config.timeout_us;

    while (gpio_get_level(sensor->config.echo_pin) == 0)
    {
        if (esp_timer_get_time() > timeout)
        {
            ESP_LOGW(TAG, "Timeout aguardando echo HIGH");
            return -1.0f;
        }
    }

    int64_t pulse_start = esp_timer_get_time();

    // Aguardar echo descer (fim do pulso)
    timeout = pulse_start + sensor->config.timeout_us;
    while (gpio_get_level(sensor->config.echo_pin) == 1)
    {
        if (esp_timer_get_time() > timeout)
        {
            ESP_LOGW(TAG, "Timeout aguardando echo LOW");
            return -1.0f;
        }
    }

    int64_t pulse_end = esp_timer_get_time();
    int64_t pulse_duration_us = pulse_end - pulse_start;

    // Calcular distância: (tempo * velocidade_som) / 2
    float distance_cm = (pulse_duration_us * SOUND_SPEED_CM_PER_US) / 2.0f;

    return distance_cm;
}

float hc_sr04_measure_avg_cm(hc_sr04_t *sensor, uint8_t samples)
{
    if (samples < 1)
    {
        samples = 1;
    }

    float total = 0.0f;
    uint8_t valid_samples = 0;

    for (uint8_t i = 0; i < samples; i++)
    {
        float reading = hc_sr04_measure_cm(sensor);

        if (reading > 0)
        {
            total += reading;
            valid_samples++;
        }

        // Pequeno delay entre leituras
        if (i < samples - 1)
        {
            vTaskDelay(pdMS_TO_TICKS(60));
        }
    }

    if (valid_samples == 0)
    {
        ESP_LOGE(TAG, "Nenhuma leitura válida em %d tentativas", samples);
        return -1.0f;
    }

    float average = total / valid_samples;

    ESP_LOGD(TAG, "Média de %d/%d leituras: %.2f cm",
             valid_samples, samples, average);

    return average;
}

bool hc_sr04_is_valid(float distance_cm, float min_cm, float max_cm)
{
    return (distance_cm >= min_cm && distance_cm <= max_cm);
}
