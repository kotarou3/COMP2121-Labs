#include <avr/io.h>
#include "util.h"

#define BEEP_PWM_PERIOD 512 // In clock cycles (= TOP)
// 512 produces a 31250 Hz wave (for 16 MHz F_CPU) so the PWM is above the audible range
// 512 also means audio is 9-bit depth and 31250 Hz sample rate

#define BEEP_PWM_OUTPUT(reg) reg##H
#define BEEP_PWM_OUTPUT_BIT PH5
#define BEEP_PWM_TIMER(reg) reg##4
#define BEEP_PWM_TIMER_S(reg, suf) reg##4##suf

// static void* setBeepActiveInterval;
// static void* setBeepInactiveInterval;
.lcomm setBeepActiveInterval, 2
.lcomm setBeepInactiveInterval, 2

// static const uint8_t waveform[] PROGMEM = {
//     128, 203, 249, 249, 203, 128, 53, 7, 7, 53 // 3125 Hz sine
// };
waveform:
    .byte 128, 203, 249, 249, 203, 128, 53, 7, 7, 53
#define sizeof_waveform 10

// static void updateWaveform() {
updateWaveform:

    // static uint16_t nextSample;
    .lcomm updateWaveform_nextSample, 2

    // BEEP_PWM_TIMER(OCR, C) = (uint16_t)pgm_read_byte(&waveform[nextSample]) * 2; // Convert 8-bit sample to 9-bit
    ldi ZL, lo8(waveform)
    ldi ZH, hi8(waveform)
    lds r24, updateWaveform_nextSample
    lds r25, updateWaveform_nextSample + 1
    add ZL, r24
    adc ZH, r25
    lpm r22, Z
    clr r23
    lsl r22
    rol r23
    sts _SFR_MEM_ADDR(BEEP_PWM_TIMER_S(OCR, CH)), r23
    sts _SFR_MEM_ADDR(BEEP_PWM_TIMER_S(OCR, CL)), r22

    // ++nextSample;
    subi r24, lo8(-1)
    sbci r25, hi8(-1)

    // if (nextSample >= sizeof(waveform))
    ldi r23, hi8(sizeof_waveform)
    cpi r24, lo8(sizeof_waveform)
    cpc r25, r23
    brlo updateWaveform_end

    //     nextSample = 0;
    clr r24
    clr r25

updateWaveform_end:
    sts updateWaveform_nextSample, r24
    sts updateWaveform_nextSample + 1, r25

    ret
// }

// static void setBeepActive(bool isActive, bool isLastBeep) {
setBeepActive:

    // if (isLastBeep) {
    tst r22
    brz setBeepActive_notLastBeep

    //     if (isActive)
    tst r24
    brz setBeepActive_lastBeep_notActive

    //         setBeepActiveInterval = 0;
    sts setBeepActiveInterval, r1
    sts setBeepActiveInterval + 1, r1
    rjmp setBeepActive_notLastBeep

setBeepActive_lastBeep_notActive:
    //     else
    //         setBeepInactiveInterval = 0;
    sts setBeepInactiveInterval, r1
    sts setBeepInactiveInterval + 1, r1

    // }
setBeepActive_notLastBeep:

    // if (isActive) {
    tst r24
    brz setBeepActive_notActive

    //     BEEP_PWM_TIMER(TIMSK) = 1 << BEEP_PWM_TIMER(OCIE, A); // Interrupt at TOP
    ldi r24, 1 << BEEP_PWM_TIMER_S(OCIE, A)
    sts _SFR_MEM_ADDR(BEEP_PWM_TIMER(TIMSK)), r24

    ret

setBeepActive_notActive:
    // } else {
    //     BEEP_PWM_TIMER(TIMSK) = 0;
    sts _SFR_MEM_ADDR(BEEP_PWM_TIMER(TIMSK)), r1

    //     BEEP_PWM_TIMER(OCR, C) = BEEP_PWM_PERIOD / 2;
    ldi r24, lo8(BEEP_PWM_PERIOD / 2)
    ldi r25, hi8(BEEP_PWM_PERIOD / 2)
    sts _SFR_MEM_ADDR(BEEP_PWM_TIMER_S(OCR, CH)), r25
    sts _SFR_MEM_ADDR(BEEP_PWM_TIMER_S(OCR, CL)), r24

    ret
    // }
// }

// void beepSet(uint16_t length, uint8_t times) {
    .global beepSet
beepSet:
    push r14
    push r15
    push r16
    push r17
    mov r16, r22
    clr r17
    movw r14, r24

    // if (setBeepActiveInterval) {
    lds r24, setBeepActiveInterval
    lds r25, setBeepActiveInterval + 1
    sbiw r24, 0
    breq beepSet_clearInactiveInterval

    //     clearInterval(setBeepActiveInterval);
    call clearInterval

    //     setBeepActiveInterval = 0;
    sts setBeepActiveInterval, r1
    sts setBeepActiveInterval + 1, r1

    // }
beepSet_clearInactiveInterval:
    // if (setBeepInactiveInterval) {
    lds r24, setBeepInactiveInterval
    lds r25, setBeepInactiveInterval + 1
    sbiw r24, 0
    breq beepSet_checkTimesNonZero

    //     clearInterval(setBeepInactiveInterval);
    call clearInterval

    //     setBeepInactiveInterval = 0;
    sts setBeepInactiveInterval, r1
    sts setBeepInactiveInterval + 1, r1

    // }

beepSet_checkTimesNonZero:
    // if (times == 0) {
    tst r16
    brnz beepSet_timeNonZero

    //     setBeepActive(false, false);
    //     return;
    clr r22
    clr r24
    pop r17
    pop r16
    pop r15
    pop r14
    jmp setBeepActive

    // }
beepSet_timeNonZero:

    // setBeepActiveInterval = setIntervalWithDelay((void (*)(uint8_t, bool))setBeepActive, true, -2 * length, 2 * length, times);
    movw r18, r14
    lsl r18
    rol r19
    movw r20, r18
    neg r21
    neg r20
    sbc r21, r1
    ldi r22, 1
    ldi r24, lo8(gs(setBeepActive))
    ldi r25, hi8(gs(setBeepActive))
    call setIntervalWithDelay
    sts setBeepActiveInterval, r24
    sts setBeepActiveInterval + 1, r25

    // setBeepInactiveInterval = setIntervalWithDelay((void (*)(uint8_t, bool))setBeepActive, false, -length, 2 * length, times);
    movw r18, r14
    lsl r18
    rol r19
    movw r20, r14
    neg r21
    neg r20
    sbc r21, r1
    clr r22
    ldi r24, lo8(gs(setBeepActive))
    ldi r25, hi8(gs(setBeepActive))
    call setIntervalWithDelay
    sts setBeepInactiveInterval, r24
    sts setBeepInactiveInterval + 1, r25

    pop r17
    pop r16
    pop r15
    pop r14
    ret
// }

// void beepSetup() {
    .global beepSetup
beepSetup:

    // Setup PWM timer in fast mode, with no prescaler
    // Clear output on OCRnC compare match, and set when at BOTTOM

    // BEEP_PWM_TIMER(TCCR, A) = (1 << BEEP_PWM_TIMER(WGM, 1)) | (1 << BEEP_PWM_TIMER(WGM, 0)) | (1 << BEEP_PWM_TIMER(COM, C1)) | (0 << BEEP_PWM_TIMER(COM, C0));
    ldi r24, (1 << BEEP_PWM_TIMER_S(WGM, 1)) | (1 << BEEP_PWM_TIMER_S(WGM, 0)) | (1 << BEEP_PWM_TIMER_S(COM, C1)) | (0 << BEEP_PWM_TIMER_S(COM, C0))
    sts _SFR_MEM_ADDR(BEEP_PWM_TIMER_S(TCCR, A)), r24

    // BEEP_PWM_TIMER(TCCR, B) = (1 << BEEP_PWM_TIMER(WGM, 3)) | (1 << BEEP_PWM_TIMER(WGM, 2)) | (1 << BEEP_PWM_TIMER(CS, 0));
    ldi r24, (1 << BEEP_PWM_TIMER_S(WGM, 3)) | (1 << BEEP_PWM_TIMER_S(WGM, 2)) | (1 << BEEP_PWM_TIMER_S(CS, 0));
    sts _SFR_MEM_ADDR(BEEP_PWM_TIMER_S(TCCR, B)), r24

    // BEEP_PWM_TIMER(OCR, A) = BEEP_PWM_PERIOD; // TOP
    ldi r24, lo8(BEEP_PWM_PERIOD)
    ldi r25, hi8(BEEP_PWM_PERIOD)
    sts _SFR_MEM_ADDR(BEEP_PWM_TIMER_S(OCR, AH)), r25
    sts _SFR_MEM_ADDR(BEEP_PWM_TIMER_S(OCR, AL)), r24

    // BEEP_PWM_TIMER(OCR, C) = BEEP_PWM_PERIOD / 2; // Duty Cycle
    ldi r24, lo8(BEEP_PWM_PERIOD / 2)
    ldi r25, hi8(BEEP_PWM_PERIOD / 2)
    sts _SFR_MEM_ADDR(BEEP_PWM_TIMER_S(OCR, CH)), r25
    sts _SFR_MEM_ADDR(BEEP_PWM_TIMER_S(OCR, CL)), r24

    // BEEP_PWM_OUTPUT(DDR) |= 1 << BEEP_PWM_OUTPUT_BIT;
    lds r24, _SFR_MEM_ADDR(BEEP_PWM_OUTPUT(DDR))
    ori r24, 1 << BEEP_PWM_OUTPUT_BIT
    sts _SFR_MEM_ADDR(BEEP_PWM_OUTPUT(DDR)), r24

    // Update the duty cycle at TOP
    // onInterrupt(BEEP_PWM_TIMER(TIMER, _COMPA_vect_num), (void (*)(uint8_t))updateWaveform);
    ldi r22, lo8(gs(updateWaveform))
    ldi r23, hi8(gs(updateWaveform))
    ldi r24, BEEP_PWM_TIMER_S(TIMER, _COMPA_vect_num)
    jmp onInterrupt
// }
