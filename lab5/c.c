#ifdef ALL_ASSEMBLY
    #error Including C source when ALL_ASSEMBLY is set
#endif

#include <avr/io.h>

#include "events.h"
#include "lcd.h"
#include "motor.h"

#define RPS_DISPLAY_INTERVAL 100
#define STARTING_RPS 60

#define MORE_RPS_AMOUNT 20
#define LESS_RPS_AMOUNT 20
#define MAX_RPS 400

#define BUTTONS(reg) reg##D
#define BUTTON_MORE_RPS PD1
#define BUTTON_LESS_RPS PD0
#define BUTTON_MORE_RPS_INT(reg, ...) reg##1##__VA_ARGS__
#define BUTTON_LESS_RPS_INT(reg, ...) reg##0##__VA_ARGS__

static uint16_t targetRps;

static void outputRps() {
    lcdClearSection(true, 0, 3); // Max 3 digits for 8-bit rps
    lcdWriteUInt(motorGetRps());
}

static void onButtonPress(uint8_t vectorNumber) {
    if (vectorNumber == BUTTON_MORE_RPS_INT(INT, _vect_num)) {
        targetRps += MORE_RPS_AMOUNT;
        if (targetRps > MAX_RPS)
            targetRps = MAX_RPS;
    } else {
        targetRps -= LESS_RPS_AMOUNT;
        if (targetRps > MAX_RPS)
            // Overflowed
            targetRps = 0;
    }

    if (targetRps < 0x100)
        motorSetRps(targetRps);

    lcdClearSection(false, 0, 3);
    lcdWriteUInt(targetRps);
}

void setup() {
    lcdSetup();
    motorSetup();
    motorSetRps(STARTING_RPS);

    BUTTONS(DDR) &= ~((1 << BUTTON_MORE_RPS) | (1 << BUTTON_LESS_RPS));
    BUTTONS(PORT) |= (1 << BUTTON_MORE_RPS) | (1 << BUTTON_LESS_RPS);

    // Falling edge for buttons
    EICRA &= ~(0 << BUTTON_MORE_RPS_INT(ISC, 0)) & ~(0 << BUTTON_LESS_RPS_INT(ISC, 0));
    EICRA |= (1 << BUTTON_MORE_RPS_INT(ISC, 1)) | (1 << BUTTON_LESS_RPS_INT(ISC, 1));
    EIMSK |= (1 << BUTTON_MORE_RPS_INT(INT)) | (1 << BUTTON_LESS_RPS_INT(INT));

    targetRps = STARTING_RPS;
    lcdClearSection(false, 0, 3);
    lcdWriteUInt(targetRps);

    setInterval((void (*)(uint8_t, bool))outputRps, 0, RPS_DISPLAY_INTERVAL, 0);
    onDebouncedInterrupt(BUTTON_MORE_RPS_INT(INT, _vect_num), onButtonPress);
    onDebouncedInterrupt(BUTTON_LESS_RPS_INT(INT, _vect_num), onButtonPress);
}
