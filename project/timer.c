#include <avr/io.h>

#include "events.h"
#include "display.h"
#include "timer.h"

// What the time defaults to if nothing is entered
#define DEFAULT_TIME_MINUTES 1
#define DEFAULT_TIME_SECONDS 0

static struct {
    uint8_t minutes;
    uint8_t seconds;
} currentTimer;

static uint8_t enteredDigits;

void timerClear() {
    currentTimer.minutes = 0;
    currentTimer.seconds = 0;
    enteredDigits = 0;
    displayUpdateTime(0, 0, 0);
}

bool timerIsZero() {
    return currentTimer.minutes == 0 && currentTimer.seconds == 0;
}

void timerSetDefaultIfEmpty() {
    if (enteredDigits != 0)
        return;

    currentTimer.minutes = DEFAULT_TIME_MINUTES;
    currentTimer.seconds = DEFAULT_TIME_SECONDS;
    enteredDigits = 4;
    displayUpdateTime(DEFAULT_TIME_MINUTES, DEFAULT_TIME_SECONDS, 4);
}

void timerAddSeconds(int8_t seconds) {
    int8_t newSeconds = currentTimer.seconds + seconds;

    if (seconds > 0 && newSeconds < 0) {
        // Overflowed. Clamp to 99 seconds
        newSeconds = 99;
    }

    // Normalise the seconds to be in [0, 59] if possible.
    // Also clamp timer between 00:00 and 99:99.
    if (newSeconds >= 60) {
        if (currentTimer.minutes == 99) {
            if (newSeconds > 99) {
                currentTimer.seconds = 99;
            } else {
                currentTimer.seconds = newSeconds;
            }
        } else {
            currentTimer.seconds = newSeconds - 60;
            ++currentTimer.minutes;
        }
    } else if (newSeconds < 0) {
        if (currentTimer.minutes == 0) {
            currentTimer.seconds = 0;
        } else {
            currentTimer.seconds = newSeconds + 60;
            --currentTimer.minutes;
        }
    } else {
        currentTimer.seconds = newSeconds;
    }

    displayUpdateTime(currentTimer.minutes, currentTimer.seconds, 4);
}

void timerInput(uint8_t n) {
    if (enteredDigits >= 4)
        return;

    switch (enteredDigits) {
        case 0:
            currentTimer.minutes = n * 10;
            break;

        case 1:
            currentTimer.minutes += n;
            break;

        case 2:
            currentTimer.seconds = n * 10;
            break;

        case 3:
            currentTimer.seconds += n;
            break;
    }

    ++enteredDigits;
    displayUpdateTime(currentTimer.minutes, currentTimer.seconds, enteredDigits);
}
