#include <avr/io.h>
#include "util.h"

.equ LED_PATTERN, 0xaaff

.org 0
    rjmp start

.org TIMER0_COMPA_vect_num << 2
    out _SFR_IO_ADDR(TCNT0), r1

    lds r24, counter
    inc r24
    cpi r24, 125
    brlo timer0_ret

    // Rotate and output pattern
    lds r24, currentPattern
    lds r25, currentPattern + 1
    lsr r25
    ror r24
    skipIf cc
    subi r25, -0x80
    out _SFR_IO_ADDR(PORTC), r24
    sts currentPattern, r24
    sts currentPattern + 1, r25

    clr r24
timer0_ret:
    sts counter, r24

    reti

start:
    clr r1

    // Setup stack
    ldi r24, lo8(RAMEND)
    out _SFR_IO_ADDR(SPL), r24
    ldi r24, hi8(RAMEND)
    out _SFR_IO_ADDR(SPH), r24

    // Setup Timer0 to interrupt every 1024 * 125 cycles
    ldi r24, (1 << CS02) | (1 << CS00)
    out _SFR_IO_ADDR(TCCR0B), r24
    ldi r24, 125
    out _SFR_IO_ADDR(OCR0A), r24
    ldi r24, (1 << OCIE0A)
    sts _SFR_MEM_ADDR(TIMSK0), r24

    // Set port C as output
    ser r24
    out _SFR_IO_ADDR(DDRC), r24

    // Load pattern to memory and initial output to port C
    ldi r24, lo8(LED_PATTERN)
    out _SFR_IO_ADDR(PORTC), r24
    sts currentPattern, r24
    ldi r24, hi8(LED_PATTERN)
    sts currentPattern + 1, r24

    // Wait for interrupts
    ldi r24, (1 << SE)
    out _SFR_IO_ADDR(SMCR), r24
    sei
idle:
    sleep
    rjmp idle

    .lcomm counter, 1
    .lcomm currentPattern, 2
