#include <stdbool.h>
#include <avr/io.h>

#include "events.h"

#define FLASH_INTERVAL 500

#define TARGET_PORT(reg) reg##D
#define LED(reg) reg##C

static void queryPort(bool isInverse) {
    LED(PORT) = isInverse ? ~TARGET_PORT(PIN) : TARGET_PORT(PIN);
}

void setup() {
    TARGET_PORT(DDR) = 0;
    TARGET_PORT(PORT) = 0xff;

    LED(DDR) = 0xff;
    LED(PORT) = 0;

    setIntervalWithDelay((void (*)(uint8_t, bool))queryPort, false, -FLASH_INTERVAL, 2 * FLASH_INTERVAL, 0);
    setInterval((void (*)(uint8_t, bool))queryPort, true, 2 * FLASH_INTERVAL, 0);
}
