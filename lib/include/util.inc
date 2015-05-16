#ifndef UTIL_H
#define UTIL_H

#include <avr/io.h>

.macro hlt
    cli
    ldi r24, (1 << SM1) | (1 << SE) // SLEEP_MODE_PWR_DOWN
    out _SFR_IO_ADDR(SMCR), r24
    sleep
.endm

.macro brz // target
    breq @0
.endm
.macro brnz // target
    brne @0
.endm

.macro skipIf // condition
    br@0 PC + 2
.endm
.macro skip2If // condition
    br@0 PC + 3
.endm

.macro lsln // reg, n
    rjmp b
a:
    lsl @0
b:
    dec @1
    brpl a
.endm
.macro lsrn // reg, n
    rjmp b
a:
    lsr @0
b:
    dec @1
    brpl a
.endm

#endif
