#include "util.h"

// Binary long division: http://en.wikipedia.org/wiki/Division_algorithm#Integer_division_.28unsigned.29_with_remainder
// Modified to be more optimal for AVR

// All functions return remainder in upper half and quotient in lower half

// static uint16_t udivmod8(uint8_t dividend, uint8_t divisor) {
    .global udivmod8
udivmod8:

    // uint8_t quotient = 0;
    // uint8_t remainder = 0;
    clr r20
    clr r21

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

// static uint32_t udivmod16(uint16_t dividend, uint16_t divisor) {
    .global udivmod16
udivmod16:

    // uint16_t quotient = 0;
    // uint16_t remainder = 0;
    clr r18
    clr r19
    clr r20
    clr r21

    ldi r26, 16
    // for (uint8_t i = 16; i > 0; --i) {
udivmod16_iterateBits:
    // (Condition is checked at the end of the loop)

    //     remainder <<= 1;
    //     remainder |= dividend >> 15;
    //     dividend <<= 1;
    lsl r24
    rol r25
    rol r20
    rol r21

    //     quotient <<= 1;
    lsl r18
    rol r19

    //     if (remainder >= divisor) {
    cp r20, r22
    cpc r21, r23
    brlo udivmod16_iterateBits_doesntDivide

    //         remainder -= divisor;
    sub r20, r22
    sbc r21, r23

    //         quotient |= 1;
    ori r18, 1

    //     }
udivmod16_iterateBits_doesntDivide:

    dec r26
    brnz udivmod16_iterateBits
    // }

    // return ((uint32_t)remainder << 16) | quotient;
    movw r22, r18
    movw r24, r20
    ret
// }
