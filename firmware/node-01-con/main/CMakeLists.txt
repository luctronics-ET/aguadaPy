idf_component_register(
    SRCS "main.c"
    INCLUDE_DIRS "." "../../common" "../../components/hc_sr04"
    REQUIRES nvs_flash esp_wifi esp_netif esp_event esp_timer driver esp_driver_gpio
)
