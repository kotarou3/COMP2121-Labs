#ifdef ALL_ASSEMBLY
    #error Including C source when ALL_ASSEMBLY is set
#endif

#include <stdbool.h>
#include <avr/io.h>

#include "events.h"

#define LED_FADE_TIME 1000

#define PWM_HALF_PERIOD 125 // In clock cycles (= TOP)

#define PWM_OUTPUT(reg) reg##E
#define PWM_OUTPUT_BIT PE4
#define PWM_TIMER(reg, ...) reg##3##__VA_ARGS__

static void doFade() {
    static bool isFadingOut;

    uint16_t dutyCycle = PWM_TIMER(OCR, B);
    if (isFadingOut)
        --dutyCycle;
    else
        ++dutyCycle;
    PWM_TIMER(OCR, B) = dutyCycle;

    if (dutyCycle == 0)
        isFadingOut = false;
    else if (dutyCycle == PWM_HALF_PERIOD)
        isFadingOut = true;
}

void setup() {
    // Setup PWM timer in phase/frequency correct mode, with no prescaler
    // Clear/Set output on OCRnB compare match when up/down-counting
    PWM_TIMER(TCCR, A) = (1 << PWM_TIMER(WGM, 0)) | (1 << PWM_TIMER(COM, B1)) | (0 << PWM_TIMER(COM, B0));
    PWM_TIMER(TCCR, B) = (1 << PWM_TIMER(WGM, 3)) | (1 << PWM_TIMER(CS, 0));
    PWM_TIMER(OCR, A) = PWM_HALF_PERIOD; // TOP
    PWM_TIMER(OCR, B) = 0; // Duty Cycle
    PWM_OUTPUT(DDR) = 1 << PWM_OUTPUT_BIT;

    setInterval((void (*)(uint8_t, bool))doFade, 0, LED_FADE_TIME / PWM_HALF_PERIOD, 0);
}
