#include <avr/io.h>

#define RPS_DISPLAY_INTERVAL 100

// static void outputRps() {
outputRps:

    // lcdClearSection(false, 0, 3); // Max 3 digits for 8-bit rps
    ldi r20, 3
    clr r22
    clr r24
    call lcdClearSection

    // lcdWriteUInt(motorGetRps());
    call motorGetRps
    clr r25
    jmp lcdWriteUInt
// }

// void setup() {
    .global setup
setup:

    // lcdSetup();
    call lcdSetup

    // motorSetup();
    call motorSetup

    // motorSetRps(0xff);
    ser r24
    call motorSetRps

    // setInterval((void (*)(uint8_t, bool))outputRps, 0, RPS_DISPLAY_INTERVAL, 0);
    clr r18
    clr r19
    ldi r20, lo8(RPS_DISPLAY_INTERVAL)
    ldi r21, hi8(RPS_DISPLAY_INTERVAL)
    clr r22
    ldi r24, lo8(gs(outputRps))
    ldi r25, hi8(gs(outputRps))
    jmp setInterval
// }
