#include <avr/io.h>
#include "../keypad.h"
#include "../util.h"

#define LED(reg) reg##C

// static void onPress(char input) {
onPress:
    // if ('0' <= input && input <= '9')
    //     LED(PORT) = input - '0';
    subi r24, '0'
    cpi r24, 10
    SKIP_IF(sh) // input - '0' < 10
    out _SFR_IO_ADDR(LED(PORT)), r24
    ret
// }

// void setup() {
    .global setup
setup:

    // keypadSetup();
    call keypadSetup

    // LED(DDR) = 0xff;
    // LED(PORT) = 0xff;
    ser r24
    out _SFR_IO_ADDR(LED(DDR)), r24
    out _SFR_IO_ADDR(LED(PORT)), r24

    // onKeypadPress(onPress);
    ldi r24, lo8(gs(onPress))
    ldi r25, hi8(gs(onPress))
    jmp onKeypadPress
// }
