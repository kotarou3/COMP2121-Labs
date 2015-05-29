#include <avr/io.h>
#include <avr/pgmspace.h>

#include "divmod.h"
#include "events.h"
#include "lcd.h"
#include "display.h"

#define DIM_LCD_BACKLIGHT_TIMEOUT 10000
#define DIM_LCD_BACKLIGHT_FADE_LENGTH 500

#define BACKLIGHT_PWM_HALF_PERIOD 63 // In clock cycles (= TOP)

#define BACKLIGHT_PWM_OUTPUT(reg) reg##H
#define BACKLIGHT_PWM_OUTPUT_BIT PH6
#define BACKLIGHT_PWM_TIMER(reg, ...) reg##2##__VA_ARGS__

static bool isDimmingEnabled;
static void* dimLcdBacklightTimeout;
static void* doDimInterval;

static void doDim() {
    if (BACKLIGHT_PWM_TIMER(OCR, B) == 0) {
        clearInterval(doDimInterval);
        doDimInterval = 0;
        return;
    }

    --BACKLIGHT_PWM_TIMER(OCR, B);
}

static void dimLcdBacklight() {
    dimLcdBacklightTimeout = 0;

    if (!doDimInterval)
        doDimInterval = setInterval((void (*)(uint8_t, bool))doDim, 0, DIM_LCD_BACKLIGHT_FADE_LENGTH / BACKLIGHT_PWM_HALF_PERIOD, 0);
}

void displayActivate() {
    if (dimLcdBacklightTimeout) {
        clearTimeout(dimLcdBacklightTimeout);
        dimLcdBacklightTimeout = 0;
    }

    BACKLIGHT_PWM_TIMER(OCR, B) = BACKLIGHT_PWM_HALF_PERIOD;

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

    // Setup PWM timer in phase correct mode, with no prescaler
    // Clear/Set output on OCRnB compare match when up/down-counting
    BACKLIGHT_PWM_TIMER(TCCR, A) = (1 << BACKLIGHT_PWM_TIMER(WGM, 0)) | (1 << BACKLIGHT_PWM_TIMER(COM, B1)) | (0 << BACKLIGHT_PWM_TIMER(COM, B0));
    BACKLIGHT_PWM_TIMER(TCCR, B) = (1 << BACKLIGHT_PWM_TIMER(WGM, 2)) | (1 << BACKLIGHT_PWM_TIMER(CS, 0));
    BACKLIGHT_PWM_TIMER(OCR, A) = BACKLIGHT_PWM_HALF_PERIOD; // TOP
    BACKLIGHT_PWM_TIMER(OCR, B) = BACKLIGHT_PWM_HALF_PERIOD; // Duty Cycle
    BACKLIGHT_PWM_OUTPUT(DDR) |= 1 << BACKLIGHT_PWM_OUTPUT_BIT;

    displayUpdateDoor(false);
    displayEnableDimming(true);
    displayActivate();

    // Note: Turntable code also updates the display (but wouldn't in real life)
}
