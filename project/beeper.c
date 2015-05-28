#include <stdbool.h>
#include <stdint.h>
#include <avr/io.h>

#include "events.h"
#include "beeper.h"

static void* setBeepActiveInterval;
static void* setBeepInactiveInterval;

static void setBeepActive(bool isActive, bool isLastBeep) {
    if (isLastBeep) {
        if (isActive)
            setBeepActiveInterval = 0;
        else
            setBeepInactiveInterval = 0;
    }

    // TODO
}

void beepSet(uint16_t length, uint8_t times) {
    if (setBeepActiveInterval) {
        clearInterval(setBeepActiveInterval);
        setBeepActiveInterval = 0;
    }
    if (setBeepInactiveInterval) {
        clearInterval(setBeepInactiveInterval);
        setBeepInactiveInterval = 0;
    }

    if (times == 0)
        return;

    setBeepActiveInterval = setIntervalWithDelay((void (*)(uint8_t, bool))setBeepActive, true, -2 * length, 2 * length, times);
    setBeepInactiveInterval = setIntervalWithDelay((void (*)(uint8_t, bool))setBeepActive, false, -length, 2 * length, times);
}

void beepStop() {
    beepSet(0, 0);
    setBeepActive(false, false);
}
