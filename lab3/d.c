#ifdef ALL_ASSEMBLY
    #error Including C source when ALL_ASSEMBLY is set
#endif

#include <stdbool.h>
#include <stdint.h>
#include <avr/io.h>

#include "circular-buffer.h"
#include "events.h"

#define DISPLAY_BUFFER_SIZE 32
#define DISPLAY_FLASHES 3
#define DISPLAY_INTERVAL 1000
#define DISPLAY_INTERVAL_HALVE_THRESHOLD 5
#define DEBOUNCE_TIME 30

#define BUTTONS(reg) reg##D
#define BUTTON_L PD1
#define BUTTON_R PD0
#define BUTTON_L_INT(reg, ...) reg##1##__VA_ARGS__
#define BUTTON_R_INT(reg, ...) reg##0##__VA_ARGS__

#define LED(reg) reg##C

static uint8_t displayBufferRaw[DISPLAY_BUFFER_SIZE];
static CircularBuffer displayBuffer;

static uint8_t inputBuffer;
static uint8_t inputEntryBit;

static void* updateLedInterval;
static uint16_t currentDisplayInterval;
static uint8_t currentDisplayStep;

static void* debounceTimeouts[2];

static void updateLed() {
    if (CircularBuffer_isEmpty(&displayBuffer)) {
        LED(PORT) = inputBuffer;

        if (updateLedInterval) {
            clearInterval(updateLedInterval);
            updateLedInterval = 0;
        }
        return;
    }

    uint16_t correctDisplayInterval = CircularBuffer_size(&displayBuffer) < DISPLAY_INTERVAL_HALVE_THRESHOLD ? DISPLAY_INTERVAL : DISPLAY_INTERVAL / 2;
    if (updateLedInterval && currentDisplayInterval != correctDisplayInterval) {
        clearInterval(updateLedInterval);
        updateLedInterval = 0;
    }
    if (!updateLedInterval) {
        updateLedInterval = setInterval((void (*)(uint8_t, bool))updateLed, 0, correctDisplayInterval, 0);
        currentDisplayInterval = correctDisplayInterval;
    }

    if ((currentDisplayStep & 1) == 0)
        LED(PORT) = CircularBuffer_top(&displayBuffer); // Even step: Show pattern
    else
        LED(PORT) = 0; // Odd step: Hide pattern

    ++currentDisplayStep;
    if (currentDisplayStep == 2 * DISPLAY_FLASHES) {
        CircularBuffer_popFront(&displayBuffer);
        currentDisplayStep = 0;
    }
}

static void onPress(bool isLeft) {
    inputBuffer |= isLeft << inputEntryBit;

    if (inputEntryBit == 0) {
        CircularBuffer_pushBack(&displayBuffer, inputBuffer);
        inputBuffer = 0;
        inputEntryBit = 8;
    }
    --inputEntryBit;

    if (!updateLedInterval) {
        currentDisplayStep = -1;
        updateLed();
    }
}

static void onDoublePress() {
    CircularBuffer_clear(&displayBuffer);
    inputBuffer = 0;
    inputEntryBit = 7;
    LED(PORT) = 0;

    if (updateLedInterval) {
        clearInterval(updateLedInterval);
        updateLedInterval = 0;
    }
}

static void debouncePress(bool isLeft) {
    static bool isCheckingDouble;

    debounceTimeouts[isLeft] = 0;

    /*
        isPressed && isCheckingDouble -> doublePress
                  && !isCheckingDouble && isOtherPressed -> checkDouble
                                       && !isOtherPressed -> singlePress
        !isPressed && isCheckingDouble -> singlePress
                   && !isCheckingDouble -> nothing
    */

    bool isButtonPressed = (BUTTONS(PIN) & (isLeft ? (1 << BUTTON_L) : (1 << BUTTON_R))) == 0;
    if (!isButtonPressed) {
        if (isCheckingDouble) {
            isCheckingDouble = false;
            onPress(!isLeft);
        }
    } else {
        if (isCheckingDouble) {
            isCheckingDouble = false;
            onDoublePress();
        } else {
            if (debounceTimeouts[!isLeft]) {
                isCheckingDouble = true;
            } else {
                onPress(isLeft);
            }
        }
    }
}

static void onUndebouncedPress(uint8_t vectorNumber) {
    bool isLeft = vectorNumber == BUTTON_L_INT(INT, _vect_num);

    if (debounceTimeouts[isLeft])
        clearTimeout(debounceTimeouts[isLeft]);

    debounceTimeouts[isLeft] = setTimeout((void (*)(uint8_t))debouncePress, isLeft, DEBOUNCE_TIME);
}

void setup() {
    CircularBuffer_init(&displayBuffer, displayBufferRaw, DISPLAY_BUFFER_SIZE, false);
    inputEntryBit = 7;

    BUTTONS(DDR) = ~((1 << BUTTON_L) | (1 << BUTTON_R));
    BUTTONS(PORT) = (1 << BUTTON_L) | (1 << BUTTON_R);

    LED(DDR) = 0xff;
    LED(PORT) = 0xff;

    EICRA = // Falling edge
        (1 << BUTTON_L_INT(ISC, 1)) | (0 << BUTTON_L_INT(ISC, 0)) |
        (1 << BUTTON_R_INT(ISC, 1)) | (0 << BUTTON_R_INT(ISC, 0));
    EIMSK = (1 << BUTTON_L_INT(INT)) | (1 << BUTTON_R_INT(INT));

    onInterrupt(BUTTON_L_INT(INT, _vect_num), onUndebouncedPress);
    onInterrupt(BUTTON_R_INT(INT, _vect_num), onUndebouncedPress);
}
