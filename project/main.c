#include <stdint.h>
#include <avr/io.h>
#include <avr/pgmspace.h>

#include "events.h"
#include "keypad.h"
#include "lcd.h"

// In quarter seconds
#define ENTRY_BEEP_LENGTH 1
#define FINISH_BEEP_LENGTH 4
#define FINISH_BEEP_INTERVAL 8
#define FINISH_BEEP_TIMES 3

// In milliseconds
#define DIM_LCD_BACKLIGHT_TIMEOUT 10000
#define DIM_LCD_BACKLIGHT_FADE_LENGTH 500

#define TURNTABLE_RPM 3

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

static struct {
    uint8_t minutes;
    uint8_t seconds;
} currentTime;
static uint8_t enteredDigits;

typedef enum _PowerSetting {
    POWER_MAX,
    POWER_HALF,
    POWER_QUARTER,
    POWER_OFF
} PowerSetting;
static PowerSetting currentPowerSetting;

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

static enum {
    DOOR_CLOSED,
    DOOR_OPENED
} currentDoorState;

static void* beepInterval;
static void* dimLcdBacklightTimeout;

static void* turntableRotateInterval;
static void* countdownTimeInterval;

static void resetMicrowave();
static void startMicrowave();
static void pauseMicrowave();
static void stopMicrowave();

// Returns remainder in high byte, quotient in low byte
static uint16_t udivmod8(uint8_t dividend, uint8_t divisor) {
    uint8_t quotient = 0;
    uint8_t remainder = 0;

    // Binary long division: http://en.wikipedia.org/wiki/Division_algorithm#Integer_division_.28unsigned.29_with_remainder
    // Modified to be more optimal for AVR
    for (uint8_t i = 8; i > 0; --i) {
        remainder <<= 1;
        remainder |= dividend >> 7;
        dividend <<= 1;
        quotient <<= 1;
        if (remainder >= divisor) {
            remainder -= divisor;
            quotient |= 1;
        }
    }

    return (remainder << 8) | quotient;
}

static void beep(uint8_t quarterSeconds, bool isLastBeep) {
    if (isLastBeep)
        beepInterval = 0;
    // TODO
}

static void dimLcdBacklight() {
    dimLcdBacklightTimeout = 0;
    // TODO
}

static void resetLcdBacklightTimeout() {
    if (dimLcdBacklightTimeout) {
        clearTimeout(dimLcdBacklightTimeout);
        dimLcdBacklightTimeout = 0;
    }

    // TODO: Light up LCD

    if (currentMode != MODE_RUNNING)
        dimLcdBacklightTimeout = setTimeout((void (*)(uint8_t))dimLcdBacklight, 0, DIM_LCD_BACKLIGHT_TIMEOUT);
}

static void updateTimeDisplay(uint8_t minutes, uint8_t seconds, uint8_t digitsToDisplay) {
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

static void rotateTurntable() {
    static const char turntableCharMap[] PROGMEM = {'-', '/', '|', 1}; // 1 is backslash (See setup())

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

static void setTurntableSpeed(uint8_t rpm) {
    if (turntableRotateInterval) {
        clearInterval(turntableRotateInterval);
        turntableRotateInterval = 0;
    }

    if (rpm != 0)
        turntableRotateInterval = setInterval((void (*)(uint8_t, bool))rotateTurntable, 0, 60L * 1000 / (rpm * (2 * TURNTABLE_LOOP)), 0);
}

static void setMagnetronPower(PowerSetting power) {
    // TODO
}

static void countdownTime() {
    if (currentTime.seconds == 0) {
        --currentTime.minutes;
        currentTime.seconds = 59;
    } else {
        --currentTime.seconds;
    }
    updateTimeDisplay(currentTime.minutes, currentTime.seconds, 4);

    if (currentTime.minutes == 0 && currentTime.seconds == 0)
        stopMicrowave();
}

static void resetMicrowave() {
    currentMode = MODE_ENTRY;
    resetLcdBacklightTimeout();

    // Stop any beeping
    if (beepInterval) {
        clearInterval(beepInterval);
        beepInterval = 0;
    }

    // Clear any unwanted existing text
    updateTimeDisplay(0, 0, 0);
    lcdClearSection(true, 0, LCD_COLS - 1);

    currentTime.minutes = 0;
    currentTime.seconds = 0;
    enteredDigits = 0;
}

static void startMicrowave() {
    if (currentTime.minutes == 0 && currentTime.seconds == 0) {
        stopMicrowave();
        return;
    }

    currentMode = MODE_RUNNING;
    resetLcdBacklightTimeout();

    countdownTimeInterval = setInterval((void (*)(uint8_t, bool))countdownTime, 0, 1000, 0);

    currentTurntableDirection = !currentTurntableDirection;
    setTurntableSpeed(TURNTABLE_RPM);
    setMagnetronPower(currentPowerSetting);
}

static void pauseMicrowave() {
    currentMode = MODE_PAUSED;
    resetLcdBacklightTimeout();

    setMagnetronPower(POWER_OFF);
    setTurntableSpeed(0);

    if (countdownTimeInterval) {
        clearInterval(countdownTimeInterval);
        countdownTimeInterval = 0;
    }
}

static void stopMicrowave() {
    static const char doneText[] PROGMEM = "Done";
    static const char removeFoodText[] PROGMEM = "Remove food";

    currentMode = MODE_FINISHED;
    resetLcdBacklightTimeout();

    setMagnetronPower(POWER_OFF);
    setTurntableSpeed(0);

    if (countdownTimeInterval) {
        clearInterval(countdownTimeInterval);
        countdownTimeInterval = 0;
    }

    beepInterval = setIntervalWithDelay(beep, ENTRY_BEEP_LENGTH, -FINISH_BEEP_INTERVAL * 250, FINISH_BEEP_INTERVAL * 250, FINISH_BEEP_TIMES);

    lcdClearSection(false, 0, 5);
    for (const char* c = doneText; c < doneText + sizeof(doneText) - 1; ++c)
        lcdWrite(pgm_read_byte(c));

    lcdSetCursor(true, 0);
    for (const char* c = removeFoodText; c < removeFoodText + sizeof(removeFoodText) - 1; ++c)
        lcdWrite(pgm_read_byte(c));
}

static void onEntryKeypadPress(char key) {
    static const char setPowerText[] PROGMEM = "Set Power 1/2/3";

    if ('0' <= key && key <= '9') {
        // Enter the time
        if (enteredDigits >= 4)
            return;

        switch (enteredDigits) {
            case 0:
                currentTime.minutes = (key - '0') * 10;
                break;

            case 1:
                currentTime.minutes += key - '0';
                break;

            case 2:
                currentTime.seconds = (key - '0') * 10;
                break;

            case 3:
                currentTime.seconds += key - '0';
                break;
        }

        ++enteredDigits;
        updateTimeDisplay(currentTime.minutes, currentTime.seconds, enteredDigits);
    } else if (key == '*') {
        // Start the microwave
        if (enteredDigits == 0) {
            currentTime.minutes = 1;
            currentTime.seconds = 0;
        }
        updateTimeDisplay(currentTime.minutes, currentTime.seconds, 4);

        startMicrowave();
    } else if (key == '#') {
        // Reset the time
        currentTime.minutes = 0;
        currentTime.seconds = 0;
        enteredDigits = 0;
        updateTimeDisplay(currentTime.minutes, currentTime.seconds, enteredDigits);
    } else if (key == 'A') {
        // Enter power select mode
        currentMode = MODE_POWER_SELECT;

        lcdSetCursor(true, 0);
        for (const char* c = setPowerText; c < setPowerText + sizeof(setPowerText) - 1; ++c)
            lcdWrite(pgm_read_byte(c));
    }
}

static void onRunningKeypadPress(char key) {
    if (key == '#') {
        // Pause the microwave
        pauseMicrowave();
    } else if (key == '*' || key == 'C') {
        // Add 60 or 30 seconds
        currentTime.seconds += key == '*' ? 60 : 30;
        if (currentTime.seconds > 99) {
            if (currentTime.minutes == 99) {
                // We don't want to overflow, so clamp to 99:99
                currentTime.seconds = 99;
            } else {
                ++currentTime.minutes;
                currentTime.seconds -= 60;
            }
        }
        updateTimeDisplay(currentTime.minutes, currentTime.seconds, 4);
    } else if (key == 'D') {
        // Subtract 30 seconds
        currentTime.seconds -= 30;
        if (currentTime.seconds & 0x80) { // Did we underflow?
            if (currentTime.minutes == 0) {
                // Finished!
                currentTime.seconds = 0;
                stopMicrowave();
                return;
            } else {
                --currentTime.minutes;
                currentTime.seconds += 60;
            }
        }
        updateTimeDisplay(currentTime.minutes, currentTime.seconds, 4);
    }
}

static void onKeypad(char key) {
    beep(ENTRY_BEEP_LENGTH, true);
    resetLcdBacklightTimeout();

    if (currentDoorState == DOOR_OPENED)
        return;

    switch (currentMode) {
        case MODE_ENTRY:
            onEntryKeypadPress(key);
            break;

        case MODE_POWER_SELECT:
            if (key == '1') {
                currentPowerSetting = POWER_MAX;
                POWER_LEDS(PORT) = POWER_LEDS_MAX_MASK;
            } else if (key == '2') {
                currentPowerSetting = POWER_HALF;
                POWER_LEDS(PORT) = POWER_LEDS_HALF_MASK;
            } else if (key == '3') {
                currentPowerSetting = POWER_QUARTER;
                POWER_LEDS(PORT) = POWER_LEDS_QUARTER_MASK;
            } else if (key == '#') {
                currentMode = MODE_ENTRY;
                lcdClearSection(true, 0, LCD_COLS - 1); // Remove the "set power" text
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
    beep(ENTRY_BEEP_LENGTH, true);
    resetLcdBacklightTimeout();

    if (currentDoorState == DOOR_OPENED)
        return;
    currentDoorState = DOOR_OPENED;

    lcdSetCursor(true, LCD_COLS - 1);
    lcdWrite('O');
    STATUS_LEDS(PORT) |= 1 << STATUS_LED_OPEN;

    if (currentMode == MODE_RUNNING)
        pauseMicrowave();
    else if (currentMode == MODE_FINISHED)
        resetMicrowave();
}

static void onCloseButton() {
    beep(ENTRY_BEEP_LENGTH, true);
    resetLcdBacklightTimeout();

    if (currentDoorState == DOOR_CLOSED)
        return;
    currentDoorState = DOOR_CLOSED;

    lcdSetCursor(true, LCD_COLS - 1);
    lcdWrite('C');
    STATUS_LEDS(PORT) &= ~(1 << STATUS_LED_OPEN);
}

void setup() {
    keypadSetup();
    lcdSetup();

    // Because the LCD doesn't have the backslash character, we add it in as custom character 1
    lcdStartCustomGlyphWrite(1);
    lcdWrite(0x00); // 0b00000
    lcdWrite(0x10); // 0b10000
    lcdWrite(0x08); // 0b01000
    lcdWrite(0x04); // 0b00100
    lcdWrite(0x02); // 0b00010
    lcdWrite(0x01); // 0b00001
    lcdWrite(0x00); // 0b00000
    lcdWrite(0x00); // 0b00000

    BUTTONS(DDR) = ~((1 << BUTTON_OPEN) | (1 << BUTTON_CLOSE));
    BUTTONS(PORT) = (1 << BUTTON_OPEN) | (1 << BUTTON_CLOSE);

    EICRA = // Falling edge for buttons
        (1 << BUTTON_OPEN_INT(ISC, 1)) | (0 << BUTTON_OPEN_INT(ISC, 0)) |
        (1 << BUTTON_CLOSE_INT(ISC, 1)) | (0 << BUTTON_CLOSE_INT(ISC, 0));
    EIMSK = (1 << BUTTON_OPEN_INT(INT)) | (1 << BUTTON_CLOSE_INT(INT));

    POWER_LEDS(DDR) = 0xff;
    POWER_LEDS(PORT) = POWER_LEDS_MAX_MASK;

    STATUS_LEDS(DDR) = 0xff;
    STATUS_LEDS(PORT) = 0;

    onKeypadPress(onKeypad);
    onDebouncedInterrupt(BUTTON_OPEN_INT(INT, _vect_num), (void (*)(uint8_t))onOpenButton);
    onDebouncedInterrupt(BUTTON_CLOSE_INT(INT, _vect_num), (void (*)(uint8_t))onCloseButton);

    // Show initial state of door (closed)
    lcdSetCursor(true, LCD_COLS - 1);
    lcdWrite('C');

    rotateTurntable();
    resetMicrowave();
}
