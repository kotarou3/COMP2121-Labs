#include <avr/io.h>
#include <avr/pgmspace.h>

#include "divmod.h"
#include "events.h"
#include "lcd.h"
#include "display.h"

#define DIM_LCD_BACKLIGHT_TIMEOUT 10000
#define DIM_LCD_BACKLIGHT_FADE_LENGTH 500

static bool isDimmingEnabled;
static void* dimLcdBacklightTimeout;

static void dimLcdBacklight() {
    dimLcdBacklightTimeout = 0;
    // TODO
}

void displayActivate() {
    if (dimLcdBacklightTimeout) {
        clearTimeout(dimLcdBacklightTimeout);
        dimLcdBacklightTimeout = 0;
    }

    // TODO: Light up LCD

    if (isDimmingEnabled)
        dimLcdBacklightTimeout = setTimeout((void (*)(uint8_t))dimLcdBacklight, 0, DIM_LCD_BACKLIGHT_TIMEOUT);
}

void displayEnableDimming(bool isEnabling) {
    isDimmingEnabled = isEnabling;
}

void displayUpdateTime(uint8_t minutes, uint8_t seconds, uint8_t digitsToDisplay) {
    lcdSetCursor(false, 0);

    if (digitsToDisplay != 0) {
        uint16_t divmod = udivmod8(minutes, 10);
        minutes = divmod >> 8;

        lcdWrite((divmod & 0xff) + '0');
        --digitsToDisplay;
    } else {
        lcdWrite(' ');
    }

    if (digitsToDisplay != 0) {
        lcdWrite(minutes + '0');
        --digitsToDisplay;
    } else {
        lcdWrite(' ');
    }

    lcdWrite(':');

    if (digitsToDisplay != 0) {
        uint16_t divmod = udivmod8(seconds, 10);
        seconds = divmod >> 8;

        lcdWrite((divmod & 0xff) + '0');
        --digitsToDisplay;
    } else {
        lcdWrite(' ');
    }

    if (digitsToDisplay != 0) {
        lcdWrite(seconds + '0');
        --digitsToDisplay;
    } else {
        lcdWrite(' ');
    }
}

void displayUpdateDoor(bool isOpen) {
    lcdSetCursor(true, LCD_COLS - 1);
    lcdWrite(isOpen ? 'O' : 'C');
}

void displayStatusRemoveFood() {
    static const char doneText[] PROGMEM = "Done";
    static const char removeFoodText[] PROGMEM = "Remove food";

    lcdClearSection(false, 0, 5);
    lcdWriteStringProgMem(doneText);

    lcdSetCursor(true, 0);
    lcdWriteStringProgMem(removeFoodText);
}

void displayStatusSetPower() {
    static const char setPowerText[] PROGMEM = "Set Power 1/2/3";

    lcdSetCursor(true, 0);
    lcdWriteStringProgMem(setPowerText);
}

void displayStatusClear() {
    lcdClearSection(true, 0, LCD_COLS - 1);
}

void displaySetup() {
    lcdSetup();

    displayUpdateDoor(false);
    displayEnableDimming(true);
    displayActivate();

    // Note: Turntable code also updates the display (but wouldn't in real life)
}
