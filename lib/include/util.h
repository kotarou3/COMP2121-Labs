#ifndef UTIL_H
#define UTIL_H

#include <avr/io.h>

.macro hlt
    cli
    ldi r24, (1 << SM1) | (1 << SE) // SLEEP_MODE_PWR_DOWN
    out _SFR_IO_ADDR(SMCR), r24
    sleep
.endm

.macro brz, target
    breq \target
.endm
.macro brnz, target
    brne \target
.endm

.macro skipIf, condition
    br\condition . + 2
.endm
.macro skip2If, condition
    br\condition . + 4
.endm

.macro lsln, reg, n
    rjmp 2f
1:
    lsl \reg
2:
    dec \n
    brpl 1b
.endm
.macro lsrn, reg, n
    rjmp 2f
1:
    lsr \reg
2:
    dec \n
    brpl 1b
.endm

#endif
