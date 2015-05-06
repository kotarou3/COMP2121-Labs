#ifdef ALL_ASSEMBLY
    #error Including C source when ALL_ASSEMBLY is set
#endif

#include <avr/io.h>
#include <avr/pgmspace.h>

#include "../lcd.h"

static const char line1[] PROGMEM = "COMP2121";
static const char line2[] PROGMEM = "Lab 4";

void setup() {
    lcdSetup();

    lcdSetCursor(false, 0);
    for (const char* c = line1; c < line1 + sizeof(line1) - 1; ++c)
        lcdWrite(pgm_read_byte(c));

    lcdSetCursor(true, 0);
    for (const char* c = line2; c < line2 + sizeof(line2) - 1; ++c)
        lcdWrite(pgm_read_byte(c));
}
