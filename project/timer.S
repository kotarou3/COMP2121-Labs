#include <avr/io.h>
#include "util.h"

// What the time defaults to if nothing is entered
#define DEFAULT_TIME_MINUTES 1
#define DEFAULT_TIME_SECONDS 0

// static struct {
    // uint8_t minutes;
    // uint8_t seconds;
// } currentTimer;
.lcomm currentTimer_minutes, 1
.lcomm currentTimer_seconds, 1

// static uint8_t inputBuffer[4];
// static uint8_t enteredDigits;
.lcomm inputBuffer, 4
.lcomm enteredDigits, 1

// void timerClear() {
    .global timerClear
timerClear:

    // currentTimer.minutes = 0;
    // currentTimer.seconds = 0;
    sts currentTimer_minutes, r1
    sts currentTimer_seconds, r1

    // inputBuffer[0] = 0;
    // inputBuffer[1] = 0;
    // inputBuffer[2] = 0;
    // inputBuffer[3] = 0;
    // enteredDigits = 0;
    sts inputBuffer + 0, r1
    sts inputBuffer + 1, r1
    sts inputBuffer + 2, r1
    sts inputBuffer + 3, r1
    sts enteredDigits, r1

    // displayUpdateTime(0, 0);
    clr r22
    clr r24
    jmp displayUpdateTime
// }

// bool timerIsZero() {
    .global timerIsZero
timerIsZero:

    // return currentTimer.minutes == 0 && currentTimer.seconds == 0;
    clr r24
    lds r22, currentTimer_minutes
    lds r23, currentTimer_seconds
    or r22, r23
    skipIf nz
    inc r24
    ret
// }

// void timerSetDefaultIfEmpty() {
    .global timerSetDefaultIfEmpty
timerSetDefaultIfEmpty:

    // if (enteredDigits != 0)
    //     return;
    lds r24, enteredDigits
    tst r24
    skipIf z
    ret

    // enteredDigits = 4;
    ldi r24, 4
    sts enteredDigits, r24

    // currentTimer.minutes = DEFAULT_TIME_MINUTES;
    // currentTimer.seconds = DEFAULT_TIME_SECONDS;
    // displayUpdateTime(DEFAULT_TIME_MINUTES, DEFAULT_TIME_SECONDS);
    ldi r24, DEFAULT_TIME_MINUTES
    sts currentTimer_minutes, r24
    ldi r22, DEFAULT_TIME_SECONDS
    sts currentTimer_seconds, r22
    jmp displayUpdateTime
// }

// void timerAddSeconds(int8_t seconds) {
    .global timerAddSeconds
timerAddSeconds:

    // int8_t newSeconds = currentTimer.seconds + seconds;
    lds r22, currentTimer_seconds
    add r22, r24

    // if (seconds > 0 && newSeconds < 0) {
    brpl timerAddSeconds_newSeconds_notOverflowed
    cpi r24, 0 + 1
    brlt timerAddSeconds_newSeconds_notOverflowed

    //     // Overflowed. Clamp to 99 seconds
    //     newSeconds = 99;
    ldi r22, 99

    // }
timerAddSeconds_newSeconds_notOverflowed:

    // Normalise the seconds to be in [0, 59] if possible.
    // Also clamp timer between 00:00 and 99:99.

    lds r24, currentTimer_minutes

    // if (newSeconds >= 60) {
    cpi r22, 60
    brlt timerAddSeconds_newSeconds_checkNegative

    //     if (currentTimer.minutes == 99) {
    cpi r24, 99
    brne timerAddSeconds_minutes_not99

    //         if (newSeconds > 99) {
    cpi r22, 99 + 1
    brlt timerAddSeconds_updateSeconds

    //             newSeconds = 99;
    ldi r22, 99

    //         }
    rjmp timerAddSeconds_updateSeconds

timerAddSeconds_minutes_not99:
    //     } else {
    //         newSeconds -= 60;
    //         ++currentTimer.minutes;
    subi r22, 60
    inc r24
    sts currentTimer_minutes, r24

    rjmp timerAddSeconds_updateSeconds
    //     }

timerAddSeconds_newSeconds_checkNegative:
    // } else if (newSeconds < 0) {
    tst r22
    brpl timerAddSeconds_updateSeconds

    //     if (currentTimer.minutes == 0) {
    tst r24
    brnz timerAddSeconds_minutes_not0

    //         newSeconds = 0;
    clr r22
    rjmp timerAddSeconds_updateSeconds

timerAddSeconds_minutes_not0:
    //     } else {
    //         currentTimer.seconds = newSeconds + 60;
    //         --currentTimer.minutes;
    subi r22, -60
    dec r24
    sts currentTimer_minutes, r24

    //     }
    // }

timerAddSeconds_updateSeconds:
    // currentTimer.seconds = newSeconds;
    sts currentTimer_seconds, r22

    // displayUpdateTime(currentTimer.minutes, currentTimer.seconds);
    jmp displayUpdateTime
// }

// void timerInput(uint8_t n) {
timerInput_end:
    ret

    .global timerInput
timerInput:

    lds r25, enteredDigits

    // if (enteredDigits >= 4)
    //     return;
    cpi r25, 4
    brsh timerInput_end

    // if (n == 0 && enteredDigits == 0)
    //     return;
    sbiw r24, 0
    breq timerInput_end

    // inputBuffer[enteredDigits] = n;
    ldi XL, lo8(inputBuffer)
    ldi XH, hi8(inputBuffer)
    add XL, r25
    adc XH, r1
    st X, r24

    // ++enteredDigits;
    inc r25
    sts enteredDigits, r25

    // switch (enteredDigits) {
    //     case 1:
    dec r25
    brnz timerInput_switch_check_case_2

    //         currentTimer.seconds = inputBuffer[0];
    lds r22, inputBuffer + 0
    sts currentTimer_seconds, r22

    //         break;
    rjmp timerInput_switch_end

timerInput_switch_check_case_2:
    //     case 2:
    dec r25
    brnz timerInput_switch_check_case_3

    //         currentTimer.seconds = inputBuffer[0] * 10 + inputBuffer[1];
    lds r22, inputBuffer + 0
    ldi r24, 10
    mul r22, r24
    mov r22, r0
    clr r1
    lds r24, inputBuffer + 1
    add r22, r24
    sts currentTimer_seconds, r22

    //         break;
    rjmp timerInput_switch_end

timerInput_switch_check_case_3:
    //     case 3:
    dec r25
    brnz timerInput_switch_case_4

    //         currentTimer.minutes = inputBuffer[0];
    lds r22, inputBuffer + 0
    sts currentTimer_minutes, r22

    //         currentTimer.seconds = inputBuffer[1] * 10 + inputBuffer[2];
    lds r22, inputBuffer + 1
    ldi r24, 10
    mul r22, r24
    mov r22, r0
    clr r1
    lds r24, inputBuffer + 2
    add r22, r24
    sts currentTimer_seconds, r22

    //         break;
    rjmp timerInput_switch_end

timerInput_switch_case_4:
    //     case 4:
    //         currentTimer.minutes = inputBuffer[0] * 10 + inputBuffer[1];
    lds r22, inputBuffer + 0
    ldi r24, 10
    mul r22, r24
    mov r22, r0
    clr r1
    lds r24, inputBuffer + 1
    add r22, r24
    sts currentTimer_minutes, r22

    //         currentTimer.seconds = inputBuffer[2] * 10 + inputBuffer[3];
    lds r22, inputBuffer + 2
    ldi r24, 10
    mul r22, r24
    mov r22, r0
    clr r1
    lds r24, inputBuffer + 3
    add r22, r24
    sts currentTimer_seconds, r22

    //         break;
    // }
timerInput_switch_end:

    // displayUpdateTime(currentTimer.minutes, currentTimer.seconds);
    lds r24, currentTimer_minutes
    jmp displayUpdateTime
// }
