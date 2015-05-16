#include <avr/io.h>
#include "util.h"

// static const char line1[] PROGMEM = "COMP2121";
line1: .asciz "COMP2121"

// static const char line2[] PROGMEM = "Lab 4";
line2: .asciz "Lab 4"

.balign 2

// void setup() {
    .global setup
setup:
    push YL
    push YH

    // lcdSetup();
    call lcdSetup

    // lcdSetCursor(false, 0);
    clr r22
    clr r24
    call lcdSetCursor

    ldi YL, lo8(line1)
    ldi YH, hi8(line1)
    // for (const char* c = line1; pgm_read_byte(c); ++c)
setup_showLine1_start:
    movw ZL, YL
    lpm r24, Z
    tst r24
    brz setup_showLine1_end

    //     lcdWrite(pgm_read_byte(c));
    call lcdWrite
    adiw YL, 1
    rjmp setup_showLine1_start

setup_showLine1_end:
    // lcdSetCursor(true, 0);
    clr r22
    ldi r24, 1
    call lcdSetCursor

    ldi YL, lo8(line2)
    ldi YH, hi8(line2)
    // for (const char* c = line2; pgm_read_byte(c); ++c)
setup_showLine2_start:
    movw ZL, YL
    lpm r24, Z
    tst r24
    brz setup_showLine2_end

    //     lcdWrite(pgm_read_byte(c));
    call lcdWrite
    adiw YL, 1
    rjmp setup_showLine2_start

setup_showLine2_end:
    pop YH
    pop YL
    ret
// }
