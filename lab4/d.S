#include <avr/io.h>
#include "util.h"

// static uint8_t accumulator;
.lcomm accumulator, 1

// static uint8_t input;
.lcomm input, 1

// Returns remainder in high byte, quotient in low byte
// static uint16_t udivmod8(uint8_t dividend, uint8_t divisor) {
udivmod8:

    // uint8_t quotient = 0;
    // uint8_t remainder = 0;
    clr r20
    clr r21

    // Binary long division: http://en.wikipedia.org/wiki/Division_algorithm#Integer_division_.28unsigned.29_with_remainder
    // Modified to be more optimal for AVR
    ldi r18, 8
    // for (uint8_t i = 8; i > 0; --i) {
udivmod8_iterateBits:
    // (Condition is checked at the end of the loop)

    //     remainder <<= 1;
    //     remainder |= dividend >> 7;
    //     dividend <<= 1;
    lsl r24
    rol r21

    //     quotient <<= 1;
    lsl r20

    //     if (remainder >= divisor) {
    cp r21, r22
    brlo udivmod8_iterateBits_doesntDivide

    //         remainder -= divisor;
    sub r21, r22

    //         quotient |= 1;
    ori r20, 1

    //     }
udivmod8_iterateBits_doesntDivide:

    dec r18
    brnz udivmod8_iterateBits
    // }

    // return (remainder << 8) | quotient;
    movw r24, r20
    ret
// }

// static void updateLcdWithAccumulator(uint8_t accumulator) {
updateLcdWithAccumulator:
    push YL
    push YH
    mov YL, r24

    // lcdClear();
    call lcdClear

    // lcdSetCursor(false, 0);
    clr r22
    clr r24
    call lcdSetCursor

    mov r24, YL
    // char buf[4]; // Maximum 3 digits for 8 bits + terminating null
    // char* start = &buf[3];
    // *start = 0;
    in YL, _SFR_IO_ADDR(SPL)
    in YH, _SFR_IO_ADDR(SPH)
    push r1 // +1 stack space and `*start = 0;` for terminating null
    rcall . // +3 stack space for digits

    // while (accumulator >= 10) {
updateLcdWithAccumulator_convertToDecimal_start:
    cpi r24, 10
    brlo updateLcdWithAccumulator_convertToDecimal_end

    //     uint16_t divmod = udivmod8(accumulator, 10);
    ldi r22, 10
    call udivmod8

    //     accumulator = divmod & 0xff;
    // (Do nothing because the result is already in `accumulator`'s register)

    //     *--start = (divmod >> 8) + '0';
    subi r25, -'0'
    st -Y, r25

    rjmp updateLcdWithAccumulator_convertToDecimal_start
    // }
updateLcdWithAccumulator_convertToDecimal_end:
    // *--start = accumulator + '0';
    subi r24, -'0'
    st -Y, r24

    // lcdWriteString(start);
    movw r24, YL
    call lcdWriteString

    pop r0
    pop r0
    pop r0
    pop r0
    pop YH
    pop YL

    // lcdSetCursor(true, 0);
    clr r22
    ldi r24, 1
    jmp lcdSetCursor
// }

// static void onPress(char key) {
onPress:

    // if ('0' <= key && key <= '9') {
    mov r22, r24
    subi r22, '0'
    cpi r22, 10
    brsh onPress_notNumber // key - '0' < 10

    //     lcdWrite(key);
    push r22
    call lcdWrite
    pop r22

    //     input = key - '0' + input * 10;
    lds r24, input
    mov r23, r24
    lsl r24
    lsl r24
    lsl r24
    add r24, r23
    add r24, r23 // input * 10 <=> (input << 3) + input + input
    add r24, r22
    sts input, r24

    ret

onPress_notNumber:
    // } else if (key == '*') {
    cpi r24, '*'
    brne onPress_notAsterix

    //     accumulator = 0;
    //     input = 0;
    sts accumulator, r1
    sts input, r1

    //     updateLcdWithAccumulator(0);
    clr r24
    jmp updateLcdWithAccumulator

onPress_notAsterix:
    // } else if ('A' <= key && key <= 'D') {
    mov r20, r24
    subi r24, 'A'
    cpi r24, 4
    skipIf lo // key - 'A' < 4
    ret

    lds r22, input
    lds r24, accumulator
    //     if (key == 'A')
    cpi r20, 'A'
    brne onPress_notA

    //         accumulator += input;
    add r24, r22
    rjmp onPress_operationFinished

onPress_notA:
    //     else if (key == 'B')
    cpi r20, 'B'
    brne onPress_notB

    //         accumulator -= input;
    sub r24, r22
    rjmp onPress_operationFinished

onPress_notB:
    //     else if (key == 'C')
    cpi r20, 'C'
    brne onPress_notC

    //         accumulator *= input;
    mul r24, r22
    mov r24, r0
    clr r1
    rjmp onPress_operationFinished

onPress_notC:
    //     else if (key == 'D')
    //         accumulator = udivmod8(accumulator, input) & 0xff;
    call udivmod8

onPress_operationFinished:
    sts accumulator, r24

    //     input = 0;
    sts input, r1

    //     updateLcdWithAccumulator(accumulator);
    jmp updateLcdWithAccumulator
    // }
// }

// void setup() {
    .global setup
setup:

    // keypadSetup();
    // lcdSetup();
    call keypadSetup
    call lcdSetup

    // onKeypadPress(onPress);
    ldi r24, lo8(gs(onPress))
    ldi r25, hi8(gs(onPress))
    call onKeypadPress

    // updateLcdWithAccumulator(0);
    clr r24
    jmp updateLcdWithAccumulator
// }
