#include <avr/io.h>
#include "util.h"
#include "magnetron.h"

#define MAGNETRON_RPS 75
#define MAGNETRON_POWER_MAX_INTERVAL 1000

// static void* setMagnetronActiveInterval;
// static void* setMagnetronInactiveInterval;
.lcomm setMagnetronActiveInterval, 2
.lcomm setMagnetronInactiveInterval, 2

// static void setMagnetronActive(bool isActive) {
setMagnetronActive:

    // motorSetRps(isActive ? MAGNETRON_RPS : 0);
    cpse r24, r1
    ldi r24, MAGNETRON_RPS
    jmp motorSetRps
// }

// void magnetronSetPower(PowerSetting power) {
    .global magnetronSetPower
magnetronSetPower:

    push r24

    // if (setMagnetronActiveInterval) {
    lds r24, setMagnetronActiveInterval
    lds r25, setMagnetronActiveInterval + 1
    sbiw r24, 0
    breq magnetronSetPower_clearInactiveInterval

    //     clearInterval(setMagnetronActiveInterval);
    call clearInterval

    //     setMagnetronActiveInterval = 0;
    sts setMagnetronActiveInterval, r1
    sts setMagnetronActiveInterval + 1, r1

    // }
magnetronSetPower_clearInactiveInterval:
    // if (setMagnetronInactiveInterval) {
    lds r24, setMagnetronInactiveInterval
    lds r25, setMagnetronInactiveInterval + 1
    sbiw r24, 0
    breq magnetronSetPower_checkPowerOff

    //     clearInterval(setMagnetronInactiveInterval);
    call clearInterval

    //     setMagnetronInactiveInterval = 0;
    sts setMagnetronInactiveInterval, r1
    sts setMagnetronInactiveInterval + 1, r1

    // }

magnetronSetPower_checkPowerOff:
    pop r24

    // if (power == POWER_OFF) {
    cpi r24, POWER_OFF
    brne magnetronSetPower_checkPowerMax

    //     setMagnetronActive(false);
    //     return;
    clr r24
    jmp setMagnetronActive

magnetronSetPower_checkPowerMax:
    // } else if (power == POWER_MAX) {
    cpi r24, POWER_MAX
    brne magnetronSetPower_checkPowerHalf

    //     setMagnetronActive(true);
    //     return;
    ldi r24, 1
    jmp setMagnetronActive

    // }

magnetronSetPower_checkPowerHalf:
    // uint16_t activeDuration;
    // if (power == POWER_HALF)
    cpi r24, POWER_HALF
    brne magnetronSetPower_powerQuarter

    //     activeDuration = MAGNETRON_POWER_MAX_INTERVAL / 2;
    ldi r20, lo8(-MAGNETRON_POWER_MAX_INTERVAL / 2) // (-MAGNETRON_POWER_MAX_INTERVAL + activeDuration)
    ldi r21, hi8(-MAGNETRON_POWER_MAX_INTERVAL / 2)
    rjmp magnetronSetPower_setIntervals

magnetronSetPower_powerQuarter:
    // else
    //     activeDuration = MAGNETRON_POWER_MAX_INTERVAL / 4;
    ldi r20, lo8(-3 * MAGNETRON_POWER_MAX_INTERVAL / 4) // (-MAGNETRON_POWER_MAX_INTERVAL + activeDuration)
    ldi r21, hi8(-3 * MAGNETRON_POWER_MAX_INTERVAL / 4)

magnetronSetPower_setIntervals:
    push r16
    push r17
    clr r16
    clr r17

    // setMagnetronInactiveInterval = setIntervalWithDelay((void (*)(uint8_t, bool))setMagnetronActive, false, -MAGNETRON_POWER_MAX_INTERVAL + activeDuration, MAGNETRON_POWER_MAX_INTERVAL, 0);
    ldi r18, lo8(MAGNETRON_POWER_MAX_INTERVAL)
    ldi r19, hi8(MAGNETRON_POWER_MAX_INTERVAL)
    clr r22
    ldi r24, lo8(gs(setMagnetronActive))
    ldi r25, hi8(gs(setMagnetronActive))
    call setIntervalWithDelay
    sts setMagnetronInactiveInterval, r24
    sts setMagnetronInactiveInterval + 1, r25

    // setMagnetronActiveInterval = setIntervalWithDelay((void (*)(uint8_t, bool))setMagnetronActive, true, -MAGNETRON_POWER_MAX_INTERVAL, MAGNETRON_POWER_MAX_INTERVAL, 0);
    ldi r18, lo8(MAGNETRON_POWER_MAX_INTERVAL)
    ldi r19, hi8(MAGNETRON_POWER_MAX_INTERVAL)
    ldi r20, lo8(-MAGNETRON_POWER_MAX_INTERVAL)
    ldi r21, hi8(-MAGNETRON_POWER_MAX_INTERVAL)
    ldi r22, 1
    ldi r24, lo8(gs(setMagnetronActive))
    ldi r25, hi8(gs(setMagnetronActive))
    call setIntervalWithDelay
    sts setMagnetronActiveInterval, r24
    sts setMagnetronActiveInterval + 1, r25

    pop r17
    pop r16
    ret
// }

// void magnetronSetup() {
    .global magnetronSetup
magnetronSetup:

    // motorSetup();
    jmp motorSetup
// }
