#include <avr/io.h>

.macro hlt
    cli
    ldi r16, (1 << SM1) | (1 << SE) // SLEEP_MODE_PWR_DOWN
    out _SFR_IO_ADDR(SMCR), r16
    sleep
.endm

    .section .text
start:
    ser r16
    out _SFR_IO_ADDR(DDRC), r16
    ldi r16, 0xe5
    out _SFR_IO_ADDR(PORTC), r16

    hlt
