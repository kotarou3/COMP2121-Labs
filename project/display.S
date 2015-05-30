#include <avr/io.h>
#include "util.h"
#include "events.h"
#include "lcd.h"

#define DIM_LCD_BACKLIGHT_TIMEOUT 10000
#define DIM_LCD_BACKLIGHT_FADE_LENGTH 500

#define BACKLIGHT_PWM_HALF_PERIOD 63 // In clock cycles (= TOP)

#define BACKLIGHT_PWM_OUTPUT(reg) reg##H
#define BACKLIGHT_PWM_OUTPUT_BIT PH6
#define BACKLIGHT_PWM_TIMER(reg) reg##2
#define BACKLIGHT_PWM_TIMER_S(reg, suf) reg##2##suf

// static bool isDimmingEnabled;
.lcomm isDimmingEnabled, 1
// static void* dimLcdBacklightTimeout;
.lcomm dimLcdBacklightTimeout, 2
// static void* doDimInterval;
.lcomm doDimInterval, 2

// static void doDim() {
doDim:

    lds r24, _SFR_MEM_ADDR(BACKLIGHT_PWM_TIMER_S(OCR, B))

    // if (BACKLIGHT_PWM_TIMER(OCR, B) == 0) {
    tst r24
    brnz doDim_notOffYet

    //     clearInterval(doDimInterval);
    lds r24, doDimInterval
    lds r25, doDimInterval + 1
    call clearInterval

    //     doDimInterval = 0;
    sts doDimInterval, r1
    sts doDimInterval + 1, r1

    //     return;
    ret
    // }

doDim_notOffYet:
    // --BACKLIGHT_PWM_TIMER(OCR, B);
    dec r24
    sts _SFR_MEM_ADDR(BACKLIGHT_PWM_TIMER_S(OCR, B)), r24

    ret
// }

// static void dimLcdBacklight() {
dimLcdBacklight:

    // dimLcdBacklightTimeout = 0;
    sts dimLcdBacklightTimeout, r1
    sts dimLcdBacklightTimeout + 1, r1

    // if (!doDimInterval)
    lds r24, doDimInterval
    lds r25, doDimInterval + 1
    or r24, r25
    brnz dimLcdBacklight_end

    //     doDimInterval = setInterval((void (*)(uint8_t, bool))doDim, 0, DIM_LCD_BACKLIGHT_FADE_LENGTH / BACKLIGHT_PWM_HALF_PERIOD, 0);
    clr r18
    clr r19
    ldi r20, lo8(DIM_LCD_BACKLIGHT_FADE_LENGTH / BACKLIGHT_PWM_HALF_PERIOD)
    ldi r21, hi8(DIM_LCD_BACKLIGHT_FADE_LENGTH / BACKLIGHT_PWM_HALF_PERIOD)
    clr r22
    ldi r24, lo8(gs(doDim))
    ldi r25, hi8(gs(doDim))
    call setInterval
    sts doDimInterval, r24
    sts doDimInterval + 1, r25

dimLcdBacklight_end:
    ret
// }

// void displayActivate() {
    .global displayActivate
displayActivate:

    // if (dimLcdBacklightTimeout) {
    lds r24, dimLcdBacklightTimeout
    lds r25, dimLcdBacklightTimeout + 1
    sbiw r24, 0
    breq displayActivate_noExistingTimeout

    //     clearTimeout(dimLcdBacklightTimeout);
    call clearTimeout

    //     dimLcdBacklightTimeout = 0;
    sts dimLcdBacklightTimeout, r1
    sts dimLcdBacklightTimeout + 1, r1

    // }
displayActivate_noExistingTimeout:

    // BACKLIGHT_PWM_TIMER(OCR, B) = BACKLIGHT_PWM_HALF_PERIOD;
    ldi r24, BACKLIGHT_PWM_HALF_PERIOD
    sts _SFR_MEM_ADDR(BACKLIGHT_PWM_TIMER_S(OCR, B)), r24

    // if (isDimmingEnabled)
    lds r24, isDimmingEnabled
    tst r24
    brz displayActivate_end

    //     dimLcdBacklightTimeout = setTimeout((void (*)(uint8_t))dimLcdBacklight, 0, DIM_LCD_BACKLIGHT_TIMEOUT);
    ldi r20, lo8(DIM_LCD_BACKLIGHT_TIMEOUT)
    ldi r21, hi8(DIM_LCD_BACKLIGHT_TIMEOUT)
    clr r22
    ldi r24, lo8(gs(dimLcdBacklight))
    ldi r25, hi8(gs(dimLcdBacklight))
    call setTimeout
    sts dimLcdBacklightTimeout, r24
    sts dimLcdBacklightTimeout + 1, r25

displayActivate_end:
    ret
// }

// void displayEnableDimming(bool isEnabling) {
    .global displayEnableDimming
displayEnableDimming:

    // isDimmingEnabled = isEnabling;
    sts isDimmingEnabled, r24

    ret
// }

// void displayUpdateTime(uint8_t minutes, uint8_t seconds) {
    .global displayUpdateTime
displayUpdateTime:
    push r14
    push r16
    mov r14, r22
    mov r16, r24

    // lcdClearSection(false, 0, 5);
    ldi r20, 5
    clr r22
    clr r24
    call lcdClearSection

    // if (minutes >= 10) {
    cpi r16, 10
    brlo displayUpdateTime_minutes_singleDigit

displayUpdateTime_minutes_write:
    //     lcdWriteUInt(minutes);
    mov r24, r16
    clr r25
    call lcdWriteUInt
    rjmp displayUpdateTime_minutes_end

displayUpdateTime_minutes_singleDigit:
    // } else if (minutes != 0) {
    tst r16
    brz displayUpdateTime_minutes_end

    //     lcdWrite(' ');
    ldi r24, ' '
    call lcdWrite

    //     lcdWriteUInt(minutes);
    rjmp displayUpdateTime_minutes_write

    // }
displayUpdateTime_minutes_end:

    // lcdSetCursor(false, 2);
    ldi r22, 2
    clr r24
    call lcdSetCursor

    // lcdWrite(':');
    ldi r24, ':'
    call lcdWrite

    // if (seconds >= 10) {
    ldi r24, 10
    cp r14, r24
    brlo displayUpdateTime_seconds_singleDigit

displayUpdateTime_seconds_write:
    //     lcdWriteUInt(seconds);
    mov r24, r14
    clr r25
    call lcdWriteUInt

displayUpdateTime_end:
    pop r16
    pop r14
    ret

displayUpdateTime_seconds_singleDigit:
    // } else if (minutes != 0) {
    tst r16
    brz displayUpdateTime_seconds_noMinutes

    //     lcdWrite('0');
    ldi r24, '0'
    call lcdWrite

    //     lcdWriteUInt(seconds);
    rjmp displayUpdateTime_seconds_write

displayUpdateTime_seconds_noMinutes:
    // } else if (seconds != 0) {
    tst r14
    brz displayUpdateTime_end

    //     lcdWrite(' ');
    ldi r24, ' '
    call lcdWrite

    //     lcdWriteUInt(seconds);
    rjmp displayUpdateTime_seconds_write
    // }
// }

// void displayUpdateDoor(bool isOpen) {
    .global displayUpdateDoor
displayUpdateDoor:
    push r16
    mov r16, r24

    // lcdSetCursor(true, LCD_COLS - 1);
    ldi r22, LCD_COLS - 1
    ldi r24, 1
    call lcdSetCursor

    // lcdWrite(isOpen ? 'O' : 'C');
    ldi r24, 'O'
    tst r16
    skipIf nz
    ldi r24, 'C'
    pop r16
    jmp lcdWrite

// }

// void displayStatusRemoveFood() {
    // static const char doneText[] PROGMEM = "Done";
    // static const char removeFoodText[] PROGMEM = "Remove food";
displayStatusRemoveFood_doneText:
    .asciz "Done"
displayStatusRemoveFood_removeFoodText:
    .asciz "Remove food"
    .balign 2

    .global displayStatusRemoveFood
displayStatusRemoveFood:

    // lcdClearSection(false, 0, 5);
    ldi r20, 5
    clr r22
    clr r24
    call lcdClearSection

    // lcdWriteStringProgMem(doneText);
    ldi r24, lo8(displayStatusRemoveFood_doneText)
    ldi r25, hi8(displayStatusRemoveFood_doneText)
    call lcdWriteStringProgMem

    // lcdSetCursor(true, 0);
    clr r22
    ldi r24, 1
    call lcdSetCursor

    // lcdWriteStringProgMem(removeFoodText);
    ldi r24, lo8(displayStatusRemoveFood_removeFoodText)
    ldi r25, hi8(displayStatusRemoveFood_removeFoodText)
    jmp lcdWriteStringProgMem
// }

// void displayStatusSetPower() {
    // static const char setPowerText[] PROGMEM = "Set Power 1/2/3";
displayStatusSetPower_setPowerText:
    .asciz "Set Power 1/2/3"
    .balign 2

    .global displayStatusSetPower
displayStatusSetPower:

    // lcdSetCursor(true, 0);
    clr r22
    ldi r24, 1
    call lcdSetCursor

    // lcdWriteStringProgMem(setPowerText);
    ldi r24, lo8(displayStatusSetPower_setPowerText)
    ldi r25, hi8(displayStatusSetPower_setPowerText)
    jmp lcdWriteStringProgMem
// }

// void displayStatusClear() {
    .global displayStatusClear
displayStatusClear:

    // lcdClearSection(true, 0, LCD_COLS - 1);
    ldi r20, LCD_COLS - 1
    clr r22
    ldi r24, 1
    jmp lcdClearSection
// }

// void displaySetup() {
    .global displaySetup
displaySetup:

    // lcdSetup();
    call lcdSetup

    // // Setup PWM timer in phase correct mode, with no prescaler
    // // Clear/Set output on OCRnB compare match when up/down-counting

    // BACKLIGHT_PWM_TIMER(TCCR, A) = (1 << BACKLIGHT_PWM_TIMER(WGM, 0)) | (1 << BACKLIGHT_PWM_TIMER(COM, B1)) | (0 << BACKLIGHT_PWM_TIMER(COM, B0));
    ldi r24, (1 << BACKLIGHT_PWM_TIMER_S(WGM, 0)) | (1 << BACKLIGHT_PWM_TIMER_S(COM, B1)) | (0 << BACKLIGHT_PWM_TIMER_S(COM, B0))
    sts _SFR_MEM_ADDR(BACKLIGHT_PWM_TIMER_S(TCCR, A)), r24

    // BACKLIGHT_PWM_TIMER(TCCR, B) = (1 << BACKLIGHT_PWM_TIMER(WGM, 2)) | (1 << BACKLIGHT_PWM_TIMER(CS, 0));
    ldi r24, (1 << BACKLIGHT_PWM_TIMER_S(WGM, 2)) | (1 << BACKLIGHT_PWM_TIMER_S(CS, 0))
    sts _SFR_MEM_ADDR(BACKLIGHT_PWM_TIMER_S(TCCR, B)), r24

    // BACKLIGHT_PWM_TIMER(OCR, A) = BACKLIGHT_PWM_HALF_PERIOD; // TOP
    // BACKLIGHT_PWM_TIMER(OCR, B) = BACKLIGHT_PWM_HALF_PERIOD; // Duty Cycle
    ldi r24, BACKLIGHT_PWM_HALF_PERIOD
    sts _SFR_MEM_ADDR(BACKLIGHT_PWM_TIMER_S(OCR, A)), r24
    sts _SFR_MEM_ADDR(BACKLIGHT_PWM_TIMER_S(OCR, B)), r24

    // BACKLIGHT_PWM_OUTPUT(DDR) |= 1 << BACKLIGHT_PWM_OUTPUT_BIT;
    lds r24, _SFR_MEM_ADDR(BACKLIGHT_PWM_OUTPUT(DDR))
    ori r24, 1 << BACKLIGHT_PWM_OUTPUT_BIT
    sts _SFR_MEM_ADDR(BACKLIGHT_PWM_OUTPUT(DDR)), r24

    // displayUpdateDoor(false);
    clr r24
    call displayUpdateDoor

    // displayEnableDimming(true);
    ldi r24, 1
    call displayEnableDimming

    // displayActivate();
    jmp displayActivate

    // Note: Turntable code also updates the display (but wouldn't in real life)
// }
