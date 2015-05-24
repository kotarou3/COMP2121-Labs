#include <avr/io.h>
#include "util.h"

#define LED_FADE_TIME 1000

#define PWM_HALF_PERIOD 125 // In clock cycles (= TOP)

#define PWM_OUTPUT(reg) reg##E
#define PWM_OUTPUT_BIT PE4
#define PWM_TIMER(reg) reg##3
#define PWM_TIMER_S(reg, suf) reg##3##suf

// static void doFade() {
doFade:

    // static bool isFadingOut;
    .lcomm doFade_isFadingOut, 1

    // uint16_t dutyCycle = PWM_TIMER(OCR, B);
    lds r24, _SFR_MEM_ADDR(PWM_TIMER_S(OCR, BL))
    lds r25, _SFR_MEM_ADDR(PWM_TIMER_S(OCR, BH))

    // if (isFadingOut)
    lds r22, doFade_isFadingOut
    tst r22
    brz doFade_fadeIn

    //     --dutyCycle;
    sbiw r24, 1
    rjmp doFade_update

doFade_fadeIn:
    // else
    //     ++dutyCycle;
    adiw r24, 1

doFade_update:
    // PWM_TIMER(OCR, B) = dutyCycle;
    sts _SFR_MEM_ADDR(PWM_TIMER_S(OCR, BH)), r25
    sts _SFR_MEM_ADDR(PWM_TIMER_S(OCR, BL)), r24

    // if (dutyCycle == 0)
    or r24, r25
    brnz doFade_dutyCycleNonZero

    //     isFadingOut = false;
    sts doFade_isFadingOut, r1
    ret

doFade_dutyCycleNonZero:
    // else if (dutyCycle == PWM_HALF_PERIOD)
    ldi r23, hi8(PWM_HALF_PERIOD)
    cpi r24, lo8(PWM_HALF_PERIOD)
    cpc r25, r23
    brne doFade_end

    //     isFadingOut = true;
    ldi r24, 1
    sts doFade_isFadingOut, r24

doFade_end:
    ret
// }

// void setup() {
    .global setup
setup:

    // Setup PWM timer in phase/frequency correct mode, with no prescaler
    // Clear/Set output on OCRnB compare match when up/down-counting
    // PWM_TIMER(TCCR, A) = (1 << PWM_TIMER(WGM, 0)) | (1 << PWM_TIMER(COM, B1)) | (0 << PWM_TIMER(COM, B0));
    ldi r24, (1 << PWM_TIMER_S(WGM, 0)) | (1 << PWM_TIMER_S(COM, B1)) | (0 << PWM_TIMER_S(COM, B0))
    sts _SFR_MEM_ADDR(PWM_TIMER_S(TCCR, A)), r24

    // PWM_TIMER(TCCR, B) = (1 << PWM_TIMER(WGM, 3)) | (1 << PWM_TIMER(CS, 0));
    ldi r24, (1 << PWM_TIMER_S(WGM, 3)) | (1 << PWM_TIMER_S(CS, 0))
    sts _SFR_MEM_ADDR(PWM_TIMER_S(TCCR, B)), r24

    // PWM_TIMER(OCR, A) = PWM_HALF_PERIOD; // TOP
    ldi r24, lo8(PWM_HALF_PERIOD)
    ldi r25, hi8(PWM_HALF_PERIOD)
    sts _SFR_MEM_ADDR(PWM_TIMER_S(OCR, AH)), r25
    sts _SFR_MEM_ADDR(PWM_TIMER_S(OCR, AL)), r24

    // PWM_TIMER(OCR, B) = 0; // Duty Cycle
    sts _SFR_MEM_ADDR(PWM_TIMER_S(OCR, BH)), r1
    sts _SFR_MEM_ADDR(PWM_TIMER_S(OCR, BL)), r1

    // PWM_OUTPUT(DDR) = 1 << PWM_OUTPUT_BIT;
    ldi r24, 1 << PWM_OUTPUT_BIT
    out _SFR_IO_ADDR(PWM_OUTPUT(DDR)), r24

    // setInterval((void (*)(uint8_t, bool))doFade, 0, LED_FADE_TIME / PWM_HALF_PERIOD, 0);
    clr r18
    clr r19
    ldi r20, lo8(LED_FADE_TIME / PWM_HALF_PERIOD)
    ldi r21, hi8(LED_FADE_TIME / PWM_HALF_PERIOD)
    clr r22
    ldi r24, lo8(gs(doFade))
    ldi r25, hi8(gs(doFade))
    jmp setInterval
// }
