#include <avr/io.h>
#include "util.h"

.org 0
    ser r16
    out _SFR_IO_ADDR(DDRC), r16
    ldi r16, 0xe5
    out _SFR_IO_ADDR(PORTC), r16

    hlt
