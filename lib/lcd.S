#include <avr/io.h>

#include "events.h"
#include "util.h"

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

// static inline void microsecondBusyWait() {
.macro microsecondBusyWait, tmpReg
    // __builtin_avr_delay_cycles(F_CPU / 1000000);
    // 16 cycles for 16 MHz
    ldi \tmpReg, 5 // 1 cycle
1:
    dec \tmpReg // 5 * 1 cycle
    brne 1b // 4 * 2 + 1 cycle
    nop // 1 cycle
.endm
// }

// static uint8_t readRaw(bool isControl) {
readRaw:

    // LCD_DATA(DDR) = 0;
    // LCD_DATA(PORT) = 0;
    sts _SFR_MEM_ADDR(LCD_DATA(DDR)), r1
    sts _SFR_MEM_ADDR(LCD_DATA(PORT)), r1

    // LCD_CONTROL(PORT) = (1 << LCD_CONTROL_RW) | (0 << LCD_CONTROL_E) | (!isControl << LCD_CONTROL_RS);
    // microsecondBusyWait();
    ldi r23, (1 << LCD_CONTROL_RW) | (0 << LCD_CONTROL_E)
    tst r24
    skipIf nz
    ori r23, 1 << LCD_CONTROL_RS
    out _SFR_IO_ADDR(LCD_CONTROL(PORT)), r23
    microsecondBusyWait r22

    // LCD_CONTROL(PORT) |= 1 << LCD_CONTROL_E;
    // microsecondBusyWait();
    ori r23, 1 << LCD_CONTROL_E
    out _SFR_IO_ADDR(LCD_CONTROL(PORT)), r23
    microsecondBusyWait r22

    // uint8_t result = LCD_DATA(PIN);
    lds r24, _SFR_MEM_ADDR(LCD_DATA(PIN))

    // LCD_CONTROL(PORT) &= ~(1 << LCD_CONTROL_E);
    andi r23, ~(1 << LCD_CONTROL_E)
    out _SFR_IO_ADDR(LCD_CONTROL(PORT)), r23

    // return result;
    ret
// }

// static void writeRaw(uint8_t data, bool isInstruction, bool isSkippingBusyCheck) {
writeRaw:
    push r16
    push r17
    mov r16, r22
    mov r17, r24

    // if (!isSkippingBusyCheck)
    tst r20
    brnz writeRaw_skippedBusyCheck

    //     while (readRaw(true) & (1 << LCD_BF))
    //         ;
writeRaw_checkBusy:
    ldi r24, 1
    call readRaw
    sbrc r24, LCD_BF
    rjmp writeRaw_checkBusy

writeRaw_skippedBusyCheck:
    // LCD_DATA(DDR) = 0xff;
    // LCD_DATA(PORT) = data;
    ser r23
    sts _SFR_MEM_ADDR(LCD_DATA(DDR)), r23
    sts _SFR_MEM_ADDR(LCD_DATA(PORT)), r17

    // LCD_CONTROL(PORT) = (0 << LCD_CONTROL_RW) | (0 << LCD_CONTROL_E) | (!isInstruction << LCD_CONTROL_RS);
    // microsecondBusyWait();
    ldi r23, (0 << LCD_CONTROL_RW) | (0 << LCD_CONTROL_E)
    tst r16
    skipIf nz
    ori r23, 1 << LCD_CONTROL_RS
    out _SFR_IO_ADDR(LCD_CONTROL(PORT)), r23
    microsecondBusyWait r22

    // LCD_CONTROL(PORT) |= 1 << LCD_CONTROL_E;
    // microsecondBusyWait();
    ori r23, 1 << LCD_CONTROL_E
    out _SFR_IO_ADDR(LCD_CONTROL(PORT)), r23
    microsecondBusyWait r22

    // LCD_CONTROL(PORT) &= ~(1 << LCD_CONTROL_E);
    andi r23, ~(1 << LCD_CONTROL_E)
    out _SFR_IO_ADDR(LCD_CONTROL(PORT)), r23

    pop r17
    pop r16
    ret
// }

// void lcdClear() {
    .global lcdClear
lcdClear:

    // writeRaw(LCD_INSTRUCTION_CLEAR_DISPLAY, true, false);
    clr r20
    ldi r22, 1
    ldi r24, LCD_INSTRUCTION_CLEAR_DISPLAY
    jmp writeRaw
// }

// void lcdClearSection(bool isBottomRow, uint8_t startCol, uint8_t length) {
    .global lcdClearSection
lcdClearSection:
    push r17
    push r28
    push r29
    mov r17, r20
    mov r28, r22
    mov r29, r24

    // lcdSetCursor(isBottomRow, startCol);
    call lcdSetCursor

    // for (; length > 0; --length)
    tst r17
lcdClearSection_clear_start:
    brz lcdClearSection_clear_end

    //     writeRaw(' ', false, false);
    clr r20
    clr r22
    ldi r24, ' '
    call writeRaw
    subi r17, 1
    rjmp lcdClearSection_clear_start

lcdClearSection_clear_end:
    // lcdSetCursor(isBottomRow, startCol);
    mov r22, r28
    mov r24, r29
    pop r29
    pop r28
    pop r17
    jmp lcdSetCursor
// }

// void lcdSetCursor(bool isBottomRow, uint8_t col) {
    .global lcdSetCursor
lcdSetCursor:

    // if (col > 40)
    //     col = 40;
    cpi r22, 40 + 1
    skipIf lo // !(col > 40) <=> col < 41
    ldi r22, 40

    // if (isBottomRow)
    //     col += 0x40;
    cpse r24, r1
    subi r22, -0x40

    // writeRaw(LCD_INSTRUCTION_SET_DDRAM_ADDRESS | col, true, false);
    mov r24, r22
    ori r24, LCD_INSTRUCTION_SET_DDRAM_ADDRESS
    clr r20
    ldi r22, 1
    jmp writeRaw
// }

// void lcdShiftCursor(bool isRight) {
    .global lcdShiftCursor
lcdShiftCursor:

    // writeRaw(LCD_INSTRUCTION_SHIFT_CURSOR | isRight, true, false);
    clr r20
    ldi r22, 1
    ori r24, LCD_INSTRUCTION_SHIFT_CURSOR
    jmp writeRaw
// }

// void lcdStartCustomGlyphWrite(char c) {
    .global lcdStartCustomGlyphWrite
lcdStartCustomGlyphWrite:

    // writeRaw(LCD_INSTRUCTION_SET_CGRAM_ADDRESS | ((c & 0x07) * 8), true, false);
    clr r20
    ldi r22, 1
    andi r24, 0x07
    lsl r24
    lsl r24
    lsl r24
    ori r24, LCD_INSTRUCTION_SET_CGRAM_ADDRESS
    jmp writeRaw
// }

// void lcdWrite(char c) {
    .global lcdWrite
lcdWrite:

    // writeRaw(c, false, false);
    clr r20
    clr r22
    jmp writeRaw
// }

// void lcdWriteString(const char* str) {
    .global lcdWriteString
lcdWriteString:
    push YL
    push YH
    movw YL, r24

    // for (; *str; ++str)
lcdWriteString_write:
    ld r24, Y+
    tst r24
    brz lcdWriteString_finish

    //     writeRaw(*str, false, false);
    clr r20
    clr r22
    call writeRaw
    rjmp lcdWriteString_write

lcdWriteString_finish:
    pop YH
    pop YL
    ret
// }

// void lcdSetup() {
    .global lcdSetup
lcdSetup:

    // LCD_CONTROL(DDR) = (1 << LCD_CONTROL_BE) | (1 << LCD_CONTROL_RW) | (1 << LCD_CONTROL_E) | (1 << LCD_CONTROL_RS);
    // LCD_CONTROL(PORT) = 0;
    // LCD_DATA(DDR) = 0;
    // LCD_DATA(PORT) = 0;
    ldi r24, (1 << LCD_CONTROL_BE) | (1 << LCD_CONTROL_RW) | (1 << LCD_CONTROL_E) | (1 << LCD_CONTROL_RS)
    out _SFR_IO_ADDR(LCD_CONTROL(DDR)), r24
    out _SFR_IO_ADDR(LCD_CONTROL(PORT)), r1
    sts _SFR_MEM_ADDR(LCD_DATA(DDR)), r1
    sts _SFR_MEM_ADDR(LCD_DATA(PORT)), r1

    // Init display
    // busyWait(15);
    ldi r24, 15
    call busyWait

    // writeRaw(LCD_INSTRUCTION_FUNCTION_SET, true, true);
    // busyWait(5);
    ldi r20, 1
    ldi r22, 1
    ldi r24, LCD_INSTRUCTION_FUNCTION_SET
    call writeRaw
    ldi r24, 5
    call busyWait

    // writeRaw(LCD_INSTRUCTION_FUNCTION_SET, true, true);
    // busyWait(1);
    ldi r20, 1
    ldi r22, 1
    ldi r24, LCD_INSTRUCTION_FUNCTION_SET
    call writeRaw
    ldi r24, 1
    call busyWait

    // writeRaw(LCD_INSTRUCTION_FUNCTION_SET, true, true);
    ldi r20, 1
    ldi r22, 1
    ldi r24, LCD_INSTRUCTION_FUNCTION_SET
    call writeRaw

    // writeRaw(LCD_INSTRUCTION_FUNCTION_SET | LCD_FUNCTION_TYPE, true, false);
    clr r20
    ldi r22, 1
    ldi r24, LCD_INSTRUCTION_FUNCTION_SET | LCD_FUNCTION_TYPE
    call writeRaw

    // writeRaw(LCD_INSTRUCTION_DISPLAY_OFF, true, false);
    clr r20
    ldi r22, 1
    ldi r24, LCD_INSTRUCTION_DISPLAY_OFF
    call writeRaw

    // writeRaw(LCD_INSTRUCTION_CLEAR_DISPLAY, true, false);
    clr r20
    ldi r22, 1
    ldi r24, LCD_INSTRUCTION_CLEAR_DISPLAY
    call writeRaw

    // writeRaw(LCD_INSTRUCTION_ENTRY_MODE_SET | LCD_DEFAULT_ENTRY_MODE, true, false);
    clr r20
    ldi r22, 1
    ldi r24, LCD_INSTRUCTION_ENTRY_MODE_SET | LCD_DEFAULT_ENTRY_MODE
    call writeRaw

    // writeRaw(LCD_INSTRUCTION_DISPLAY_ON | LCD_DEFAULT_DISPLAY_MODE, true, false);
    clr r20
    ldi r22, 1
    ldi r24, LCD_INSTRUCTION_DISPLAY_ON | LCD_DEFAULT_DISPLAY_MODE
    jmp writeRaw
// }
