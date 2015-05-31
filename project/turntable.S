#include <avr/io.h>
#include "util.h"
#include "lcd.h"

#define CHAR_BACKSLASH 1
#define TURNTABLE_RPM 3

// static const char turntableCharMap[] PROGMEM = {'-', '/', '|', CHAR_BACKSLASH};
turntableCharMap:
    .byte '-', '/', '|', CHAR_BACKSLASH

// static enum {
//     // In gradians
//     TURNTABLE_ZERO,
//     TURNTABLE_FIFTY,
//     TURNTABLE_ONE_HUNDRED,
//     TURNTABLE_ONE_HUNDRED_AND_FIFTY,
//     TURNTABLE_LOOP
// } currentTurntablePosition;
#define TURNTABLE_ZERO 0
#define TURNTABLE_FIFTY (TURNTABLE_ZERO + 1)
#define TURNTABLE_ONE_HUNDRED (TURNTABLE_FIFTY + 1)
#define TURNTABLE_ONE_HUNDRED_AND_FIFTY (TURNTABLE_ONE_HUNDRED + 1)
#define TURNTABLE_LOOP (TURNTABLE_ONE_HUNDRED_AND_FIFTY + 1)
.lcomm currentTurntablePosition, 1

// static enum {
//     TURNTABLE_ANTICLOCKWISE,
//     TURNTABLE_CLOCKWISE
// } currentTurntableDirection;
#define TURNTABLE_ANTICLOCKWISE
#define TURNTABLE_CLOCKWISE
.lcomm currentTurntableDirection, 1

// static void* turntableRotateInterval;
.lcomm turntableRotateInterval, 2

// static void rotateTurntable() {
rotateTurntable:

    lds r24, currentTurntablePosition

    // if (currentTurntableDirection == TURNTABLE_ANTICLOCKWISE) {
    lds r22, currentTurntableDirection
    cpi r22, TURNTABLE_ANTICLOCKWISE
    brne rotateTurntable_clockwise

    //     ++currentTurntablePosition;
    inc r24

    //     if (currentTurntablePosition == TURNTABLE_LOOP)
    cpi r24, TURNTABLE_LOOP
    brne rotateTurntable_updateLcd

    //         currentTurntablePosition = TURNTABLE_ZERO;
    ldi r24, TURNTABLE_ZERO
    rjmp rotateTurntable_updateLcd

rotateTurntable_clockwise:
    // } else {
    //     if (currentTurntablePosition == TURNTABLE_ZERO)
    //         currentTurntablePosition = TURNTABLE_LOOP;
    cpi r24, TURNTABLE_ZERO
    skipIf ne
    ldi r24, TURNTABLE_LOOP

    //     --currentTurntablePosition;
    dec r24

    // }

rotateTurntable_updateLcd:
    sts currentTurntablePosition, r24

    // lcdSetCursor(false, LCD_COLS - 1);
    push r24
    ldi r22, LCD_COLS - 1
    clr r24
    call lcdSetCursor
    pop ZL

    // lcdWrite(pgm_read_byte(&turntableCharMap[currentTurntablePosition]));
    clr ZH
    subi ZL, lo8(-(turntableCharMap))
    sbci ZH, hi8(-(turntableCharMap))
    lpm r24, Z
    jmp lcdWrite
// }

// void turntableSetActive(bool isActive) {
    .global turntableSetActive
turntableSetActive:
    mov r22, r24

    // if (turntableRotateInterval && isActive)
    //     return;
    lds r24, turntableRotateInterval
    lds r25, turntableRotateInterval + 1
    sbiw r24, 0
    breq turntableSetActive_checkOffAndInactive
    tst r22
    brnz turntableSetActive_end

turntableSetActive_checkOffAndInactive:
    // if (!turntableRotateInterval && !isActive)
    //     return;
    sbiw r24, 0
    sbci r22, 0
    breq turntableSetActive_end

    // if (!isActive) {
    tst r22
    brnz turntableSetActive_true

    //     clearInterval(turntableRotateInterval);
    call clearInterval

    //     turntableRotateInterval = 0;
    sts turntableRotateInterval, r1
    sts turntableRotateInterval + 1, r1
    ret

turntableSetActive_true:
    // } else {
    //     turntableRotateInterval = setInterval((void (*)(uint8_t, bool))rotateTurntable, 0, 60L * 1000 / (TURNTABLE_RPM * (2 * TURNTABLE_LOOP)), 0);
    clr r18
    clr r19
    ldi r20, lo8(60 * 1000 / (TURNTABLE_RPM * (2 * TURNTABLE_LOOP)))
    ldi r21, hi8(60 * 1000 / (TURNTABLE_RPM * (2 * TURNTABLE_LOOP)))
    clr r22
    ldi r24, lo8(gs(rotateTurntable))
    ldi r25, hi8(gs(rotateTurntable))
    call setInterval
    sts turntableRotateInterval, r24
    sts turntableRotateInterval + 1, r25

    // }

turntableSetActive_end:
    ret
// }

// void turntableReverseDirection() {
    .global turntableReverseDirection
turntableReverseDirection:

    // currentTurntableDirection = !currentTurntableDirection;
    lds r24, currentTurntableDirection
    ldi r25, 1
    eor r24, r25
    sts currentTurntableDirection, r24

    ret
// }

// void turntableSetup() {
    .global turntableSetup
turntableSetup:

    // Because the LCD doesn't have the backslash character, we add it in as a custom character
    // lcdStartCustomGlyphWrite(CHAR_BACKSLASH);
    // lcdWrite(0x00); // 0b00000
    // lcdWrite(0x10); // 0b10000
    // lcdWrite(0x08); // 0b01000
    // lcdWrite(0x04); // 0b00100
    // lcdWrite(0x02); // 0b00010
    // lcdWrite(0x01); // 0b00001
    // lcdWrite(0x00); // 0b00000
    // lcdWrite(0x00); // 0b00000
    ldi r24, CHAR_BACKSLASH
    call lcdStartCustomGlyphWrite
    ldi r24, 0x00
    call lcdWrite
    ldi r24, 0x10
    call lcdWrite
    ldi r24, 0x08
    call lcdWrite
    ldi r24, 0x04
    call lcdWrite
    ldi r24, 0x02
    call lcdWrite
    ldi r24, 0x01
    call lcdWrite
    ldi r24, 0x00
    call lcdWrite
    ldi r24, 0x00
    call lcdWrite

    // lcdSetCursor(false, LCD_COLS - 1);
    ldi r22, LCD_COLS - 1
    clr r24
    call lcdSetCursor

    // lcdWrite(pgm_read_byte(&turntableCharMap[0]));
    ldi r24, '-'
    jmp lcdWrite
// }
