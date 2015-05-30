#include <stdbool.h>
#include <stdint.h>
#include <avr/io.h>
#include <avr/pgmspace.h>

#include "events.h"
#include "beeper.h"

#define BEEP_PWM_PERIOD 512 // In clock cycles (= TOP)
// 512 produces a 31250 Hz wave (for 16 MHz F_CPU) so the PWM is above the audible range
// 512 also means audio is 9-bit depth and 31250 Hz sample rate

#define BEEP_PWM_OUTPUT(reg) reg##H
#define BEEP_PWM_OUTPUT_BIT PH5
#define BEEP_PWM_TIMER(reg, ...) reg##4##__VA_ARGS__

static void* setBeepActiveInterval;
static void* setBeepInactiveInterval;

static const uint8_t waveform[] PROGMEM = {
    128, 203, 249, 249, 203, 128, 53, 7, 7, 53 // 3125 Hz sine
};

static void updateWaveform() {
    static uint16_t nextSample;

    BEEP_PWM_TIMER(OCR, C) = (uint16_t)pgm_read_byte(&waveform[nextSample]) * 2; // Convert 8-bit sample to 9-bit

    ++nextSample;
    if (nextSample >= sizeof(waveform))
        nextSample = 0;
}

static void setBeepActive(bool isActive, bool isLastBeep) {
    if (isLastBeep) {
        if (isActive)
            setBeepActiveInterval = 0;
        else
            setBeepInactiveInterval = 0;
    }

    if (isActive) {
        BEEP_PWM_TIMER(TIMSK) = 1 << BEEP_PWM_TIMER(OCIE, A); // Interrupt at TOP
    } else {
        BEEP_PWM_TIMER(TIMSK) = 0;
        BEEP_PWM_TIMER(OCR, C) = BEEP_PWM_PERIOD / 2;
    }
}

void beepSet(uint16_t length, uint8_t times) {
    if (setBeepActiveInterval) {
        clearInterval(setBeepActiveInterval);
        setBeepActiveInterval = 0;
    }
    if (setBeepInactiveInterval) {
        clearInterval(setBeepInactiveInterval);
        setBeepInactiveInterval = 0;
    }

    if (times == 0) {
        setBeepActive(false, false);
        return;
    }

    setBeepActiveInterval = setIntervalWithDelay((void (*)(uint8_t, bool))setBeepActive, true, -2 * length, 2 * length, times);
    setBeepInactiveInterval = setIntervalWithDelay((void (*)(uint8_t, bool))setBeepActive, false, -length, 2 * length, times);
}

void beepSetup() {
    // Setup PWM timer in fast mode, with no prescaler
    // Clear output on OCRnC compare match, and set when at BOTTOM
    BEEP_PWM_TIMER(TCCR, A) = (1 << BEEP_PWM_TIMER(WGM, 1)) | (1 << BEEP_PWM_TIMER(WGM, 0)) | (1 << BEEP_PWM_TIMER(COM, C1)) | (0 << BEEP_PWM_TIMER(COM, C0));
    BEEP_PWM_TIMER(TCCR, B) = (1 << BEEP_PWM_TIMER(WGM, 3)) | (1 << BEEP_PWM_TIMER(WGM, 2)) | (1 << BEEP_PWM_TIMER(CS, 0));
    BEEP_PWM_TIMER(OCR, A) = BEEP_PWM_PERIOD; // TOP
    BEEP_PWM_TIMER(OCR, C) = BEEP_PWM_PERIOD / 2; // Duty Cycle
    BEEP_PWM_OUTPUT(DDR) |= 1 << BEEP_PWM_OUTPUT_BIT;

    // Update the duty cycle at TOP
    onInterrupt(BEEP_PWM_TIMER(TIMER, _COMPA_vect_num), (void (*)(uint8_t))updateWaveform);
}
