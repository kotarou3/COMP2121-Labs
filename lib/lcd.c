#ifdef ALL_ASSEMBLY
    #error Including C source when ALL_ASSEMBLY is set
#endif

#include <avr/io.h>
#include <avr/pgmspace.h>

#include "divmod.h"
#include "events.h"
#include "lcd.h"

#define LCD_DATA(reg) reg##K
#define LCD_CONTROL(reg) reg##A
#define LCD_CONTROL_BE PA4
#define LCD_CONTROL_RW PA5
#define LCD_CONTROL_E PA6
#define LCD_CONTROL_RS PA7
#define LCD_BF 7

#define LCD_FUNCTION_TYPE 8 // 8-bit; 2-line; 5x7 character set
#define LCD_DEFAULT_ENTRY_MODE 2 // Increment mode; No shifting
#define LCD_DEFAULT_DISPLAY_MODE 0 // No cursor; No blinking

#define LCD_INSTRUCTION_CLEAR_DISPLAY 0x01
#define LCD_INSTRUCTION_RETURN_HOME 0x02
#define LCD_INSTRUCTION_ENTRY_MODE_SET 0x04
#define LCD_INSTRUCTION_DISPLAY_OFF 0x08
#define LCD_INSTRUCTION_DISPLAY_ON 0x0c
#define LCD_INSTRUCTION_SHIFT_CURSOR 0x10
#define LCD_INSTRUCTION_SHIFT_DISPLAY 0x18
#define LCD_INSTRUCTION_FUNCTION_SET 0x30
#define LCD_INSTRUCTION_SET_CGRAM_ADDRESS 0x40
#define LCD_INSTRUCTION_SET_DDRAM_ADDRESS 0x80

static inline void microsecondBusyWait() {
    __builtin_avr_delay_cycles(F_CPU / 1000000);
}

static uint8_t readRaw(bool isControl) {
    LCD_DATA(DDR) = 0;
    LCD_DATA(PORT) = 0;

    LCD_CONTROL(PORT) = (1 << LCD_CONTROL_RW) | (0 << LCD_CONTROL_E) | (!isControl << LCD_CONTROL_RS);
    microsecondBusyWait();

    LCD_CONTROL(PORT) |= 1 << LCD_CONTROL_E;
    microsecondBusyWait();

    uint8_t result = LCD_DATA(PIN);

    LCD_CONTROL(PORT) &= ~(1 << LCD_CONTROL_E);

    return result;
}

static void writeRaw(uint8_t data, bool isInstruction, bool isSkippingBusyCheck) {
    if (!isSkippingBusyCheck)
        while (readRaw(true) & (1 << LCD_BF))
            ;

    LCD_DATA(DDR) = 0xff;
    LCD_DATA(PORT) = data;

    LCD_CONTROL(PORT) = (0 << LCD_CONTROL_RW) | (0 << LCD_CONTROL_E) | (!isInstruction << LCD_CONTROL_RS);
    microsecondBusyWait();

    LCD_CONTROL(PORT) |= 1 << LCD_CONTROL_E;
    microsecondBusyWait();

    LCD_CONTROL(PORT) &= ~(1 << LCD_CONTROL_E);
}

void lcdClear() {
    writeRaw(LCD_INSTRUCTION_CLEAR_DISPLAY, true, false);
}

void lcdClearSection(bool isBottomRow, uint8_t startCol, uint8_t length) {
    lcdSetCursor(isBottomRow, startCol);

    for (; length > 0; --length)
        writeRaw(' ', false, false);

    lcdSetCursor(isBottomRow, startCol);
}

void lcdSetCursor(bool isBottomRow, uint8_t col) {
    if (col > 40)
        col = 40;
    if (isBottomRow)
        col += 0x40;

    writeRaw(LCD_INSTRUCTION_SET_DDRAM_ADDRESS | col, true, false);
}

void lcdShiftCursor(bool isRight) {
    writeRaw(LCD_INSTRUCTION_SHIFT_CURSOR | isRight, true, false);
}

void lcdStartCustomGlyphWrite(char c) {
    writeRaw(LCD_INSTRUCTION_SET_CGRAM_ADDRESS | ((c & 0x07) * 8), true, false);
}

void lcdWrite(char c) {
    writeRaw(c, false, false);
}

void lcdWriteString(const char* str) {
    for (; *str; ++str)
        writeRaw(*str, false, false);
}

void lcdWriteStringProgMem(const char* str) {
    for (char c = pgm_read_byte(str); c; c = pgm_read_byte(++str))
        writeRaw(c, false, false);
}

void lcdWriteUInt(uint16_t n) {
    char buf[6]; // Maximum 5 digits for 16 bits + terminating null
    char* start = &buf[5];
    *start = 0;
    while (n >= 10) {
        uint32_t divmod = udivmod16(n, 10);
        *--start = (uint8_t)(divmod >> 16) + '0';
        n = divmod & 0xffff;
    }
    *--start = (uint8_t)n + '0';

    lcdWriteString(start);
}

void lcdSetup() {
    LCD_CONTROL(DDR) = (1 << LCD_CONTROL_BE) | (1 << LCD_CONTROL_RW) | (1 << LCD_CONTROL_E) | (1 << LCD_CONTROL_RS);
    LCD_CONTROL(PORT) = 0;
    LCD_DATA(DDR) = 0;
    LCD_DATA(PORT) = 0;

    // Init display
    busyWait(15);
    writeRaw(LCD_INSTRUCTION_FUNCTION_SET, true, true);
    busyWait(5);
    writeRaw(LCD_INSTRUCTION_FUNCTION_SET, true, true);
    busyWait(1);
    writeRaw(LCD_INSTRUCTION_FUNCTION_SET, true, true);

    writeRaw(LCD_INSTRUCTION_FUNCTION_SET | LCD_FUNCTION_TYPE, true, false);
    writeRaw(LCD_INSTRUCTION_DISPLAY_OFF, true, false);
    writeRaw(LCD_INSTRUCTION_CLEAR_DISPLAY, true, false);
    writeRaw(LCD_INSTRUCTION_ENTRY_MODE_SET | LCD_DEFAULT_ENTRY_MODE, true, false);
    writeRaw(LCD_INSTRUCTION_DISPLAY_ON | LCD_DEFAULT_DISPLAY_MODE, true, false);
}
