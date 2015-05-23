#ifdef ALL_ASSEMBLY
    #error Including C source when ALL_ASSEMBLY is set
#endif

#include <avr/io.h>

#include "events.h"
#include "lcd.h"
#include "motor.h"

#define RPS_DISPLAY_INTERVAL 100

static void outputRps() {
    lcdClearSection(false, 0, 3); // Max 3 digits for 8-bit rps
    lcdWriteUInt(motorGetRps());
}

void setup() {
    lcdSetup();
    motorSetup();
    motorSetRps(0xff);

    setInterval((void (*)(uint8_t, bool))outputRps, 0, RPS_DISPLAY_INTERVAL, 0);
}
