#ifdef ALL_ASSEMBLY
    #error Including C source when ALL_ASSEMBLY is set
#endif

#include <avr/io.h>

#include "keypad.h"

#define LED(reg) reg##C

static void onPress(char input) {
    if ('0' <= input && input <= '9')
        LED(PORT) = input - '0';
}

void setup() {
    keypadSetup();

    LED(DDR) = 0xff;
    LED(PORT) = 0xff;

    onKeypadPress(onPress);
}
