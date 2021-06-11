#include "esp_log.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "driver/gpio.h"

extern "C" {
	void app_main(void);
}

constexpr static const gpio_num_t BLINK_GPIO = (gpio_num_t) 2;

void configure_led(void) {
   gpio_reset_pin(BLINK_GPIO);
   gpio_set_direction(BLINK_GPIO, GPIO_MODE_OUTPUT);
}

void blink_led(bool enable) {
	gpio_set_level(BLINK_GPIO, enable);
}

void app_main(void)
{
	bool enabled = false;
	configure_led();

	for (;;) {
		ESP_LOGI("foo", "Turning the LED %s!", "ON");

		blink_led(enabled);
		enabled = !enabled;
	        vTaskDelay(100000);
	}
}
