#include <stdbool.h>
#include <stdint.h>
#include <avr/io.h>
#include <avr/pgmspace.h>

#include "events.h"
#include "lcd.h"
#include "turntable.h"

#define CHAR_BACKSLASH 1
#define TURNTABLE_RPM 3

static const char turntableCharMap[] PROGMEM = {'-', '/', '|', CHAR_BACKSLASH};

static enum {
    // In gradians
    TURNTABLE_ZERO,
    TURNTABLE_FIFTY,
    TURNTABLE_ONE_HUNDRED,
    TURNTABLE_ONE_HUNDRED_AND_FIFTY,
    TURNTABLE_LOOP
} currentTurntablePosition;

static enum {
    TURNTABLE_ANTICLOCKWISE,
    TURNTABLE_CLOCKWISE
} currentTurntableDirection;

static void* turntableRotateInterval;

static void rotateTurntable() {
    if (currentTurntableDirection == TURNTABLE_ANTICLOCKWISE) {
        ++currentTurntablePosition;
        if (currentTurntablePosition == TURNTABLE_LOOP)
            currentTurntablePosition = TURNTABLE_ZERO;
    } else {
        if (currentTurntablePosition == TURNTABLE_ZERO)
            currentTurntablePosition = TURNTABLE_LOOP;
        --currentTurntablePosition;
    }

    lcdSetCursor(false, LCD_COLS - 1);
    lcdWrite(pgm_read_byte(&turntableCharMap[currentTurntablePosition]));
}

void setTurntableActive(bool isActive) {
    if (turntableRotateInterval && isActive)
        return;

    if (!turntableRotateInterval && !isActive)
        return;

    if (!isActive) {
        clearInterval(turntableRotateInterval);
        turntableRotateInterval = 0;
    } else {
        turntableRotateInterval = setInterval((void (*)(uint8_t, bool))rotateTurntable, 0, 60L * 1000 / (TURNTABLE_RPM * (2 * TURNTABLE_LOOP)), 0);
    }
}

void reverseTurntableDirection() {
    currentTurntableDirection = !currentTurntableDirection;
}

void turntableSetup() {
    // Because the LCD doesn't have the backslash character, we add it in as a custom character
    lcdStartCustomGlyphWrite(CHAR_BACKSLASH);
    lcdWrite(0x00); // 0b00000
    lcdWrite(0x10); // 0b10000
    lcdWrite(0x08); // 0b01000
    lcdWrite(0x04); // 0b00100
    lcdWrite(0x02); // 0b00010
    lcdWrite(0x01); // 0b00001
    lcdWrite(0x00); // 0b00000
    lcdWrite(0x00); // 0b00000

    lcdSetCursor(false, LCD_COLS - 1);
    lcdWrite(pgm_read_byte(&turntableCharMap[0]));
}
