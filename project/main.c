#include <stdint.h>
#include <avr/io.h>

#include "events.h"
#include "keypad.h"

#include "beeper.h"
#include "display.h"
#include "magnetron.h"
#include "timer.h"
#include "turntable.h"

// In milliseconds
#define ENTRY_BEEP_LENGTH 250
#define FINISH_BEEP_LENGTH 1000
#define FINISH_BEEP_TIMES 3

#define BUTTONS(reg) reg##D
#define BUTTON_OPEN PD1
#define BUTTON_CLOSE PD0
#define BUTTON_OPEN_INT(reg, ...) reg##1##__VA_ARGS__
#define BUTTON_CLOSE_INT(reg, ...) reg##0##__VA_ARGS__

#define POWER_LEDS(reg) reg##C
#define POWER_LEDS_MAX_MASK 0xff
#define POWER_LEDS_HALF_MASK 0x0f
#define POWER_LEDS_QUARTER_MASK 0x03

#define STATUS_LEDS(reg) reg##G
#define STATUS_LED_OPEN PG2

static enum {
    MODE_ENTRY,
    MODE_POWER_SELECT,
    MODE_RUNNING,
    MODE_PAUSED,
    MODE_FINISHED
} currentMode;

static PowerSetting currentPowerSetting;

static enum {
    DOOR_CLOSED,
    DOOR_OPENED
} currentDoorState;

static void* countdownTimeInterval;

static void resetMicrowave();
static void startMicrowave();
static void pauseMicrowave();
static void stopMicrowave();

static void countdownTime() {
    timerAddSeconds(-1);

    if (timerIsZero())
        stopMicrowave();
}

static void resetMicrowave() {
    currentMode = MODE_ENTRY;
    displayEnableDimming(true);
    displayActivate();

    // Clear any unwanted existing text
    displayStatusClear();
    timerClear();
}

static void startMicrowave() {
    timerSetDefaultIfEmpty();
    timerAddSeconds(0); // Normalise the timer

    if (timerIsZero()) {
        stopMicrowave();
        return;
    }

    currentMode = MODE_RUNNING;
    displayEnableDimming(false);
    displayActivate();

    countdownTimeInterval = setInterval((void (*)(uint8_t, bool))countdownTime, 0, 1000, 0);

    turntableReverseDirection();
    turntableSetActive(true);
    magnetronSetPower(currentPowerSetting);
}

static void pauseMicrowave() {
    currentMode = MODE_PAUSED;
    displayEnableDimming(true);
    displayActivate();

    magnetronSetPower(POWER_OFF);
    turntableSetActive(false);

    if (countdownTimeInterval) {
        clearInterval(countdownTimeInterval);
        countdownTimeInterval = 0;
    }
}

static void stopMicrowave() {
    currentMode = MODE_FINISHED;
    displayEnableDimming(true);
    displayActivate();

    magnetronSetPower(POWER_OFF);
    turntableSetActive(false);

    if (countdownTimeInterval) {
        clearInterval(countdownTimeInterval);
        countdownTimeInterval = 0;
    }

    displayStatusRemoveFood();
    beepSet(FINISH_BEEP_LENGTH, FINISH_BEEP_TIMES);
}

static void onEntryKeypadPress(char key) {
    if ('0' <= key && key <= '9') {
        // Enter the time
        timerInput(key - '0');
    } else if (key == '*') {
        // Start the microwave
        startMicrowave();
    } else if (key == '#') {
        // Reset the time
        timerClear();
    } else if (key == 'A') {
        // Enter power select mode
        currentMode = MODE_POWER_SELECT;
        displayStatusSetPower();
    }
}

static void onRunningKeypadPress(char key) {
    if (key == '#') {
        // Pause the microwave
        pauseMicrowave();
    } else if (key == '*' || key == 'C') {
        // Add 60 or 30 seconds
        timerAddSeconds(key == '*' ? 60 : 30);
    } else if (key == 'D') {
        // Subtract 30 seconds
        timerAddSeconds(-30);

        if (timerIsZero())
            stopMicrowave();
    }
}

static void onKeypad(char key) {
    beepSet(ENTRY_BEEP_LENGTH, 1);
    displayActivate();

    if (currentDoorState == DOOR_OPENED)
        return;

    switch (currentMode) {
        case MODE_ENTRY:
            onEntryKeypadPress(key);
            break;

        case MODE_POWER_SELECT:
            if (key == '#' || ('1' <= key && key <= '3')) {
                if (key == '1') {
                    currentPowerSetting = POWER_MAX;
                    POWER_LEDS(PORT) = POWER_LEDS_MAX_MASK;
                } else if (key == '2') {
                    currentPowerSetting = POWER_HALF;
                    POWER_LEDS(PORT) = POWER_LEDS_HALF_MASK;
                } else if (key == '3') {
                    currentPowerSetting = POWER_QUARTER;
                    POWER_LEDS(PORT) = POWER_LEDS_QUARTER_MASK;
                }
                currentMode = MODE_ENTRY;
                displayStatusClear(); // Remove the "set power" text
            }
            break;

        case MODE_RUNNING:
            onRunningKeypadPress(key);
            break;

        case MODE_PAUSED:
            if (key == '#')
                resetMicrowave();
            else if (key == '*')
                startMicrowave();
            break;

        case MODE_FINISHED:
            if (key == '#')
                resetMicrowave();
            break;
    }
}

static void onOpenButton() {
    beepSet(ENTRY_BEEP_LENGTH, 1);
    displayActivate();

    if (currentDoorState == DOOR_OPENED)
        return;
    currentDoorState = DOOR_OPENED;

    displayUpdateDoor(true);
    STATUS_LEDS(PORT) |= 1 << STATUS_LED_OPEN;

    if (currentMode == MODE_RUNNING)
        pauseMicrowave();
    else if (currentMode == MODE_FINISHED)
        resetMicrowave();
}

static void onCloseButton() {
    beepSet(ENTRY_BEEP_LENGTH, 1);
    displayActivate();

    if (currentDoorState == DOOR_CLOSED)
        return;
    currentDoorState = DOOR_CLOSED;

    displayUpdateDoor(false);
    STATUS_LEDS(PORT) &= ~(1 << STATUS_LED_OPEN);
}

void setup() {
    displaySetup();
    keypadSetup();
    magnetronSetup();
    turntableSetup();
    beepSetup();

    BUTTONS(DDR) &= ~((1 << BUTTON_OPEN) | (1 << BUTTON_CLOSE));
    BUTTONS(PORT) |= (1 << BUTTON_OPEN) | (1 << BUTTON_CLOSE);

    // Falling edge for buttons
    EICRA &= ~(0 << BUTTON_OPEN_INT(ISC, 0)) & ~(0 << BUTTON_CLOSE_INT(ISC, 0));
    EICRA |= (1 << BUTTON_OPEN_INT(ISC, 1)) | (1 << BUTTON_CLOSE_INT(ISC, 1));
    EIMSK |= (1 << BUTTON_OPEN_INT(INT)) | (1 << BUTTON_CLOSE_INT(INT));

    POWER_LEDS(DDR) = 0xff;
    POWER_LEDS(PORT) = POWER_LEDS_MAX_MASK;

    STATUS_LEDS(DDR) = 0xff;
    STATUS_LEDS(PORT) = 0;

    onKeypadPress(onKeypad);
    onDebouncedInterrupt(BUTTON_OPEN_INT(INT, _vect_num), (void (*)(uint8_t))onOpenButton);
    onDebouncedInterrupt(BUTTON_CLOSE_INT(INT, _vect_num), (void (*)(uint8_t))onCloseButton);

    resetMicrowave();
}
