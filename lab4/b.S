#include <avr/io.h>

// static const char line1[] PROGMEM = "COMP2121";
line1:
    .asciz "COMP2121"
line1_end:

// static const char line2[] PROGMEM = "Lab 4";
line2:
    .asciz "Lab 4"
line2_end:

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
    // for (const char* c = line1; c < line1 + sizeof(line1) - 1; ++c)
    //     lcdWrite(pgm_read_byte(c));
setup_showLine1_start:
    movw ZL, YL
    lpm r24, Z
    call lcdWrite
    adiw YL, 1
    ldi r24, hi8(line1_end - 1)
    cpi YL, lo8(line1_end - 1)
    cpc YH, r24
    brne setup_showLine1_start

    // lcdSetCursor(true, 0);
    clr r22
    ldi r24, 1
    call lcdSetCursor

    ldi YL, lo8(line2)
    ldi YH, hi8(line2)
    // for (const char* c = line2; c < line2 + sizeof(line2) - 1; ++c)
    //     lcdWrite(pgm_read_byte(c));
setup_showLine2_start:
    movw ZL, YL
    lpm r24, Z
    call lcdWrite
    adiw YL, 1
    ldi r24, hi8(line2_end - 1)
    cpi YL, lo8(line2_end - 1)
    cpc YH, r24
    brne setup_showLine2_start

    pop YH
    pop YL
    ret
// }
