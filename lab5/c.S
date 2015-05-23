#include <avr/io.h>
#include "util.h"

#define RPS_DISPLAY_INTERVAL 100
#define STARTING_RPS 60

#define MORE_RPS_AMOUNT 20
#define LESS_RPS_AMOUNT 20
#define MAX_RPS 400

#define BUTTONS(reg) reg##D
#define BUTTON_MORE_RPS PD1
#define BUTTON_LESS_RPS PD0
#define BUTTON_MORE_RPS_INT(reg) reg##1
#define BUTTON_MORE_RPS_INT_S(reg, suf) reg##1##suf
#define BUTTON_LESS_RPS_INT(reg) reg##0
#define BUTTON_LESS_RPS_INT_S(reg, suf) reg##0##suf

// static uint16_t targetRps;
.lcomm targetRps, 2

// static void outputRps() {
outputRps:

    // lcdClearSection(true, 0, 3); // Max 3 digits for 8-bit rps
    ldi r20, 3
    clr r22
    ldi r24, 1
    call lcdClearSection

    // lcdWriteUInt(motorGetRps());
    call motorGetRps
    clr r25
    jmp lcdWriteUInt
// }

// static void onButtonPress(uint8_t vectorNumber) {
onButtonPress:

    lds r22, targetRps
    lds r23, targetRps + 1

    // if (vectorNumber == BUTTON_MORE_RPS_INT(INT, _vect_num)) {
    cpi r24, BUTTON_MORE_RPS_INT_S(INT, _vect_num)
    brne onButtonPress_less

    //     targetRps += MORE_RPS_AMOUNT;
    subi r22, lo8(-MORE_RPS_AMOUNT)
    sbci r23, hi8(-MORE_RPS_AMOUNT)

    //     if (targetRps > MAX_RPS)
    ldi r25, hi8(MAX_RPS + 1)
    cpi r22, lo8(MAX_RPS + 1)
    cpc r23, r25
    brlo onButtonPress_update

    //         targetRps = MAX_RPS;
    ldi r22, lo8(MAX_RPS)
    ldi r23, hi8(MAX_RPS)

    rjmp onButtonPress_update

onButtonPress_less:
    // } else {
    //     targetRps -= LESS_RPS_AMOUNT;
    subi r22, lo8(LESS_RPS_AMOUNT)
    sbci r23, hi8(LESS_RPS_AMOUNT)

    //     if (targetRps > MAX_RPS)
    ldi r25, hi8(MAX_RPS + 1)
    cpi r22, lo8(MAX_RPS + 1)
    cpc r23, r25
    brlo onButtonPress_update

    //         // Overflowed
    //         targetRps = 0;
    clr r22
    clr r23

    // }
onButtonPress_update:
    sts targetRps, r22
    sts targetRps + 1, r23

    // if (targetRps < 0x100)
    tst r23
    brnz onButtonPress_exceeded8Bits

    //     motorSetRps(targetRps);
    mov r24, r22
    call motorSetRps

onButtonPress_exceeded8Bits:
    // lcdClearSection(false, 0, 3);
    ldi r20, 3
    clr r22
    clr r24
    call lcdClearSection

    // lcdWriteUInt(targetRps);
    lds r24, targetRps
    lds r25, targetRps + 1
    call lcdWriteUInt

    ret
// }

// void setup() {
    .global setup
setup:

    // lcdSetup();
    call lcdSetup

    // motorSetup();
    call motorSetup

    // motorSetRps(STARTING_RPS);
    ldi r24, lo8(STARTING_RPS)
    call motorSetRps

    // BUTTONS(DDR) &= ~((1 << BUTTON_MORE_RPS) | (1 << BUTTON_LESS_RPS));
    cbi _SFR_IO_ADDR(BUTTONS(DDR)), BUTTON_MORE_RPS
    cbi _SFR_IO_ADDR(BUTTONS(DDR)), BUTTON_LESS_RPS

    // BUTTONS(PORT) |= (1 << BUTTON_MORE_RPS) | (1 << BUTTON_LESS_RPS);
    sbi _SFR_IO_ADDR(BUTTONS(PORT)), BUTTON_MORE_RPS
    sbi _SFR_IO_ADDR(BUTTONS(PORT)), BUTTON_LESS_RPS

    // Falling edge for buttons
    // EICRA &= ~(0 << BUTTON_MORE_RPS_INT(ISC, 0)) & ~(0 << BUTTON_LESS_RPS_INT(ISC, 0));
    // EICRA |= (1 << BUTTON_MORE_RPS_INT(ISC, 1)) | (1 << BUTTON_LESS_RPS_INT(ISC, 1));
    lds r24, _SFR_MEM_ADDR(EICRA)
    ori r24, (1 << BUTTON_MORE_RPS_INT_S(ISC, 1)) | (1 << BUTTON_LESS_RPS_INT_S(ISC, 1))
    andi r24, ~(0 << BUTTON_MORE_RPS_INT_S(ISC, 0)) & ~(0 << BUTTON_LESS_RPS_INT_S(ISC, 0))
    sts _SFR_MEM_ADDR(EICRA), r24

    // EIMSK |= (1 << BUTTON_MORE_RPS_INT(INT)) | (1 << BUTTON_LESS_RPS_INT(INT));
    sbi _SFR_IO_ADDR(EIMSK), BUTTON_MORE_RPS_INT(INT)
    sbi _SFR_IO_ADDR(EIMSK), BUTTON_LESS_RPS_INT(INT)

    // targetRps = STARTING_RPS;
    ldi r24, lo8(STARTING_RPS)
    ldi r25, hi8(STARTING_RPS)
    sts targetRps, r24
    sts targetRps + 1, r25

    // lcdClearSection(false, 0, 3);
    ldi r20, 3
    clr r22
    clr r24
    call lcdClearSection

    // lcdWriteUInt(targetRps);
    ldi r24, lo8(STARTING_RPS)
    ldi r25, hi8(STARTING_RPS)
    call lcdWriteUInt

    // setInterval((void (*)(uint8_t, bool))outputRps, 0, RPS_DISPLAY_INTERVAL, 0);
    clr r18
    clr r19
    ldi r20, lo8(RPS_DISPLAY_INTERVAL)
    ldi r21, hi8(RPS_DISPLAY_INTERVAL)
    clr r22
    ldi r24, lo8(gs(outputRps))
    ldi r25, hi8(gs(outputRps))
    call setInterval

    // onDebouncedInterrupt(BUTTON_MORE_RPS_INT(INT, _vect_num), onButtonPress);
    ldi r22, lo8(gs(onButtonPress))
    ldi r23, hi8(gs(onButtonPress))
    ldi r24, BUTTON_MORE_RPS_INT_S(INT, _vect_num)
    call onDebouncedInterrupt

    // onDebouncedInterrupt(BUTTON_LESS_RPS_INT(INT, _vect_num), onButtonPress);
    ldi r22, lo8(gs(onButtonPress))
    ldi r23, hi8(gs(onButtonPress))
    ldi r24, BUTTON_LESS_RPS_INT_S(INT, _vect_num)
    jmp onDebouncedInterrupt
// }
