#include <stdbool.h>
#include <stdint.h>
#include <avr/io.h>

#include "events.h"
#include "magnetron.h"

#define MAGNETRON_RPS 300
#define MAGNETRON_POWER_MAX_INTERVAL 1000

static void* setMagnetronActiveInterval;
static void* setMagnetronInactiveInterval;

static void setMagnetronActive(bool isActive) {
    // TODO
}

void setMagnetronPower(PowerSetting power) {
    if (setMagnetronActiveInterval) {
        clearInterval(setMagnetronActiveInterval);
        setMagnetronActiveInterval = 0;
    }
    if (setMagnetronInactiveInterval) {
        clearInterval(setMagnetronInactiveInterval);
        setMagnetronInactiveInterval = 0;
    }

    if (power == POWER_OFF) {
        setMagnetronActive(false);
        return;
    } else if (power == POWER_MAX) {
        setMagnetronActive(true);
        return;
    }

    uint16_t activeDuration;
    if (power == POWER_HALF)
        activeDuration = MAGNETRON_POWER_MAX_INTERVAL / 2;
    else
        activeDuration = MAGNETRON_POWER_MAX_INTERVAL / 4;

    setMagnetronActiveInterval = setIntervalWithDelay((void (*)(uint8_t, bool))setMagnetronActive, true, -MAGNETRON_POWER_MAX_INTERVAL, MAGNETRON_POWER_MAX_INTERVAL, 0);
    setMagnetronInactiveInterval = setIntervalWithDelay((void (*)(uint8_t, bool))setMagnetronActive, false, -MAGNETRON_POWER_MAX_INTERVAL + activeDuration, MAGNETRON_POWER_MAX_INTERVAL, 0);
}
