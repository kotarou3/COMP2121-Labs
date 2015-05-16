#include <avr/io.h>
#include "../events.h"
#include "../circular-buffer.h"
#include "../util.h"

#define DISPLAY_BUFFER_SIZE 32
#define DISPLAY_FLASHES 3
#define DISPLAY_INTERVAL 1000
#define DISPLAY_INTERVAL_HALVE_THRESHOLD 5
#define DEBOUNCE_TIME 30

#define BUTTONS(reg) reg##D
#define BUTTON_L PD1
#define BUTTON_R PD0
#define BUTTON_L_INT(reg, ...) reg##1##__VA_ARGS__
#define BUTTON_R_INT(reg, ...) reg##0##__VA_ARGS__

#define LED(reg) reg##C

// static uint8_t displayBufferRaw[DISPLAY_BUFFER_SIZE];
.lcomm displayBufferRaw, DISPLAY_BUFFER_SIZE
// static CircularBuffer displayBuffer;
.lcomm displayBuffer, sizeof_CircularBuffer

// static uint8_t inputBuffer;
.lcomm inputBuffer, 1
// static uint8_t inputEntryBit;
.lcomm inputEntryBit, 1

// static void* updateLedInterval;
.lcomm updateLedInterval, 2
// static uint16_t currentDisplayInterval;
.lcomm currentDisplayInterval, 2
// static uint8_t currentDisplayStep;
.lcomm currentDisplayStep, 1

// static void* debounceTimeouts[2];
.lcomm debounceTimeouts, 2 * 2

// static void updateLed() {
updateLed:
    ldi r24, lo8(displayBuffer)
    ldi r25, hi8(displayBuffer)
    // if (CircularBuffer_isEmpty(&displayBuffer)) {
    call CircularBuffer_isEmpty
    tst r24
    brz updateLed_displayBufferNotEmpty

    //     LED(PORT) = inputBuffer;
    lds r24, inputBuffer
    out _SFR_IO_ADDR(LED(PORT)), r24

    //     if (updateLedInterval) {
    lds r24, updateLedInterval
    lds r25, updateLedInterval + 1
    sbiw r24, 0
    breq updateLed_displayBufferEmpty_end

    //         clearInterval(updateLedInterval);
    call clearInterval

    //         updateLedInterval = 0;
    sts updateLedInterval, r1
    sts updateLedInterval + 1, r1

    //     }
updateLed_displayBufferEmpty_end:
    //     return;
    ret

    // }
updateLed_displayBufferNotEmpty:
    push YL
    push YH

    // uint16_t correctDisplayInterval = CircularBuffer_size(&displayBuffer) < DISPLAY_INTERVAL_HALVE_THRESHOLD ? DISPLAY_INTERVAL : DISPLAY_INTERVAL / 2;
    ldi r24, lo8(displayBuffer)
    ldi r25, hi8(displayBuffer)
    call CircularBuffer_size
    sbiw r24, DISPLAY_INTERVAL_HALVE_THRESHOLD
    brsh updateLed_getCorrectDisplayInterval_overThreshold
    ldi YL, lo8(DISPLAY_INTERVAL)
    ldi YH, hi8(DISPLAY_INTERVAL)
    rjmp updateLed_getCorrectDisplayInterval_end
updateLed_getCorrectDisplayInterval_overThreshold:
    ldi YL, lo8(DISPLAY_INTERVAL / 2)
    ldi YH, hi8(DISPLAY_INTERVAL / 2)
updateLed_getCorrectDisplayInterval_end:

    lds r24, updateLedInterval
    lds r25, updateLedInterval + 1
    // if (updateLedInterval && currentDisplayInterval != correctDisplayInterval) {
    sbiw r24, 0
    breq updateLed_checkCorrectDisplayInterval_end
    lds r18, currentDisplayInterval
    lds r19, currentDisplayInterval + 1
    cp r18, YL
    cpc r19, YH
    breq updateLed_checkCorrectDisplayInterval_end

    //     clearInterval(updateLedInterval);
    call clearInterval

    //     updateLedInterval = 0;
    clr r24
    clr r25

    // }
updateLed_checkCorrectDisplayInterval_end:
    // if (!updateLedInterval) {
    or r24, r25
    brnz updateLed_setInterval_end

    //     updateLedInterval = setInterval((void (*)(uint8_t, bool))updateLed, 0, correctDisplayInterval, 0);
    ldi r18, 0
    ldi r19, 0
    movw r20, YL
    ldi r22,0
    ldi r24, lo8(gs(updateLed))
    ldi r25, hi8(gs(updateLed))
    call setInterval
    sts updateLedInterval, r24
    sts updateLedInterval + 1, r25

    //     currentDisplayInterval = correctDisplayInterval;
    sts currentDisplayInterval, YL
    sts currentDisplayInterval + 1, YH

    // }
updateLed_setInterval_end:

    // if ((currentDisplayStep & 1) == 0)
    lds YL, currentDisplayStep
    sbrc YL, 0
    rjmp updateLed_oddDisplayStep

    //     LED(PORT) = CircularBuffer_top(&displayBuffer); // Even step: Show pattern
    ldi r24, lo8(displayBuffer)
    ldi r25, hi8(displayBuffer)
    call CircularBuffer_top
    out _SFR_IO_ADDR(LED(PORT)), r24
    rjmp updateLed_displayStep_end

    // else
updateLed_oddDisplayStep:
    //     LED(PORT) = 0; // Odd step: Hide pattern
    out _SFR_IO_ADDR(LED(PORT)), r1

updateLed_displayStep_end:
    // ++currentDisplayStep;
    inc YL
    sts currentDisplayStep, YL

    // if (currentDisplayStep == 2 * DISPLAY_FLASHES) {
    cpi YL, 2 * DISPLAY_FLASHES
    brne updateLed_end

    //     CircularBuffer_popFront(&displayBuffer);
    ldi r24, lo8(displayBuffer)
    ldi r25, hi8(displayBuffer)
    call CircularBuffer_popFront

    //     currentDisplayStep = 0;
    sts currentDisplayStep, r1

    // }
updateLed_end:
    pop YH
    pop YL
    ret
// }

// static void onPress(bool isLeft) {
onPress:

    // inputBuffer |= isLeft << inputEntryBit;
    lds r23, inputEntryBit
    mov r0, r23
    lsln r24, r0
    lds r22, inputBuffer
    or r22, r24
    sts inputBuffer, r22

    // if (inputEntryBit == 0) {
    tst r23
    brnz onPress_inputIncomplete

    //     CircularBuffer_pushBack(&displayBuffer, inputBuffer);
    ldi r24, lo8(displayBuffer)
    ldi r25, hi8(displayBuffer)
    call CircularBuffer_pushBack

    //     inputBuffer = 0;
    sts inputBuffer, r1

    //     inputEntryBit = 8;
    ldi r23, 8

    // }
onPress_inputIncomplete:
    // --inputEntryBit;
    dec r23
    sts inputEntryBit, r23

    // if (!updateLedInterval) {
    lds r24, updateLedInterval
    lds r25, updateLedInterval + 1
    or r24, r25
    brnz onPress_end

    //     currentDisplayStep = -1;
    ldi r24, -1
    sts currentDisplayStep, r24

    //     updateLed();
    jmp updateLed
    // }

onPress_end:
    ret
// }

// static void onDoublePress() {
onDoublePress:
    // CircularBuffer_clear(&displayBuffer);
    ldi r24, lo8(displayBuffer)
    ldi r25, hi8(displayBuffer)
    call CircularBuffer_clear

    // inputBuffer = 0;
    sts inputBuffer, r1

    // inputEntryBit = 7;
    ldi r24, 7
    sts inputEntryBit, r24

    // LED(PORT) = 0;
    out _SFR_IO_ADDR(LED(PORT)), r1

    lds r24, updateLedInterval
    lds r25, updateLedInterval + 1
    // if (updateLedInterval) {
    sbiw r24, 0
    breq onDoublePress_end

    //     clearInterval(updateLedInterval);
    //     updateLedInterval = 0;
    sts updateLedInterval, r1
    sts updateLedInterval + 1, r1
    jmp clearInterval

    // }
onDoublePress_end:
    ret
// }

// static void debouncePress(bool isLeft) {
debouncePress:
    // static bool isCheckingDouble;
    .lcomm debouncePress_isCheckingDouble, 1

    // debounceTimeouts[isLeft] = 0;
    mov ZL, r24
    lsl ZL
    clr ZH
    subi ZL, lo8(-(debounceTimeouts))
    sbci ZH, hi8(-(debounceTimeouts))
    std Z + 0, r1
    std Z + 1, r1

    /*
        isPressed && isCheckingDouble -> doublePress
                  && !isCheckingDouble && isOtherPressed -> checkDouble
                                       && !isOtherPressed -> singlePress
        !isPressed && isCheckingDouble -> singlePress
                   && !isCheckingDouble -> nothing
    */

    // bool isButtonPressed = (BUTTONS(PIN) & (isLeft ? (1 << BUTTON_L) : (1 << BUTTON_R))) == 0;
    clr r22
    tst r24
    brz debouncePress_checkButtonR
    sbis _SFR_IO_ADDR(BUTTONS(PIN)), BUTTON_L
    inc r22
    rjmp debouncePress_checkButton_end
debouncePress_checkButtonR:
    sbis _SFR_IO_ADDR(BUTTONS(PIN)), BUTTON_R
    inc r22
debouncePress_checkButton_end:

    lds r25, debouncePress_isCheckingDouble
    // if (!isButtonPressed) {
    tst r22
    brnz debouncePress_buttonStillPressed

    //     if (isCheckingDouble) {
    tst r25
    brz debouncePress_end

    //         isCheckingDouble = false;
    sts debouncePress_isCheckingDouble, r1

    //         onPress(!isLeft);
    ldi r25, 1
    eor r24, r25
    jmp onPress

    //     }
    // } else {
debouncePress_buttonStillPressed:
    //     if (isCheckingDouble) {
    tst r25
    brz debouncePress_notDoublePress

    //         isCheckingDouble = false;
    sts debouncePress_isCheckingDouble, r1

    //         onDoublePress();
    jmp onDoublePress

    //     } else {
debouncePress_notDoublePress:
    //         if (debounceTimeouts[!isLeft]) {
    mov ZL, r24
    ldi r25, 1
    eor ZL, r25
    lsl ZL
    clr ZH
    subi ZL, lo8(-(debounceTimeouts))
    sbci ZH, hi8(-(debounceTimeouts))
    ldd r22, Z + 0
    ldd r23, Z + 1
    or r22, r23
    brz debouncePress_noPendingSecondPress

    //             isCheckingDouble = true;
    sts debouncePress_isCheckingDouble, r25
    ret

    //         } else {
debouncePress_noPendingSecondPress:
    //             onPress(isLeft);
    jmp onPress

    //         }
    //     }
    // }
debouncePress_end:
    ret
// }

// static void onUndebouncedPress(uint8_t vectorNumber) {
onUndebouncedPress:
    push r17
    push YL
    push YH

    // bool isLeft = vectorNumber == BUTTON_L_INT(INT, _vect_num);
    clr r17
    cpi r24, BUTTON_L_INT(INT, _vect_num)
    skipIf ne
    inc r17

    mov YL, r17
    lsl YL
    clr YH
    subi YL, lo8(-(debounceTimeouts))
    sbci YH, hi8(-(debounceTimeouts))
    // if (debounceTimeouts[isLeft])
    ldd r24, Y + 0
    ldd r25, Y + 1
    sbiw r24, 0
    breq onUndebouncedPress_noExistingDebounce

    //     clearTimeout(debounceTimeouts[isLeft]);
    call clearTimeout

onUndebouncedPress_noExistingDebounce:
    // debounceTimeouts[isLeft] = setTimeout((void (*)(uint8_t))debouncePress, isLeft, DEBOUNCE_TIME);
    ldi r20, lo8(DEBOUNCE_TIME)
    ldi r21, hi8(DEBOUNCE_TIME)
    mov r22, r17
    ldi r24, lo8(gs(debouncePress))
    ldi r25, hi8(gs(debouncePress))
    call setTimeout
    std Y + 0, r24
    std Y + 1, r25

    pop YH
    pop YL
    pop r17
    ret
// }

// void setup() {
    .global setup
setup:

    // CircularBuffer_init(&displayBuffer, displayBufferRaw, DISPLAY_BUFFER_SIZE, false);
    clr r18
    ldi r20, lo8(DISPLAY_BUFFER_SIZE)
    ldi r21, hi8(DISPLAY_BUFFER_SIZE)
    ldi r22, lo8(displayBufferRaw)
    ldi r23, hi8(displayBufferRaw)
    ldi r24, lo8(displayBuffer)
    ldi r25, hi8(displayBuffer)
    call CircularBuffer_init

    // inputEntryBit = 7;
    ldi r24, 7
    sts inputEntryBit, r24

    // BUTTONS(DDR) = ~((1 << BUTTON_L) | (1 << BUTTON_R));
    ldi r24, ~((1 << BUTTON_L) | (1 << BUTTON_R))
    out _SFR_IO_ADDR(BUTTONS(DDR)), r24

    // BUTTONS(PORT) = (1 << BUTTON_L) | (1 << BUTTON_R);
    ldi r24, (1 << BUTTON_L) | (1 << BUTTON_R)
    out _SFR_IO_ADDR(BUTTONS(PORT)), r24

    // LED(DDR) = 0xff;
    // LED(PORT) = 0xff;
    ldi r24, 0xff
    out _SFR_IO_ADDR(LED(DDR)), r24
    out _SFR_IO_ADDR(LED(PORT)), r24

    // EICRA = // Falling edge
    //     (1 << BUTTON_L_INT(ISC, 1)) | (0 << BUTTON_L_INT(ISC, 0)) |
    //     (1 << BUTTON_R_INT(ISC, 1)) | (0 << BUTTON_R_INT(ISC, 0));
    ldi r24, \
        (1 << BUTTON_L_INT(ISC, 1)) | (0 << BUTTON_L_INT(ISC, 0)) | \
        (1 << BUTTON_R_INT(ISC, 1)) | (0 << BUTTON_R_INT(ISC, 0))
    sts _SFR_MEM_ADDR(EICRA), r24

    // EIMSK = (1 << BUTTON_L_INT(INT)) | (1 << BUTTON_R_INT(INT));
    ldi r24, (1 << BUTTON_L_INT(INT)) | (1 << BUTTON_R_INT(INT))
    out _SFR_IO_ADDR(EIMSK), r24

    // onInterrupt(BUTTON_L_INT(INT, _vect_num), onUndebouncedPress);
    ldi r22, lo8(gs(onUndebouncedPress))
    ldi r23, hi8(gs(onUndebouncedPress))
    ldi r24, BUTTON_L_INT(INT, _vect_num)
    call onInterrupt

    // onInterrupt(BUTTON_R_INT(INT, _vect_num), onUndebouncedPress);
    ldi r22, lo8(gs(onUndebouncedPress))
    ldi r23, hi8(gs(onUndebouncedPress))
    ldi r24, BUTTON_R_INT(INT, _vect_num)
    jmp onInterrupt
// }
