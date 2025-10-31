idf_component_register(
    SRCS "hc_sr04.c"
    INCLUDE_DIRS "."
    REQUIRES driver esp_timer esp_driver_gpio freertos
)
