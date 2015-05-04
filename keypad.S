#include <avr/io.h>
#include "events.h"
#include "keypad.h"
#include "util.h"

#define KEYPAD(reg) reg##L
#define KEYPAD_ROW0 PL0
#define KEYPAD_ROW1 PL1
#define KEYPAD_ROW2 PL2
#define KEYPAD_ROW3 PL3
#define KEYPAD_COL0 PL4
#define KEYPAD_COL1 PL5
#define KEYPAD_COL2 PL6
#define KEYPAD_COL3 PL7
#define KEYPAD_ROWS ((1 << KEYPAD_ROW0) | (1 << KEYPAD_ROW1) | (1 << KEYPAD_ROW2) | (1 << KEYPAD_ROW3))
#define KEYPAD_COLS (~KEYPAD_ROWS)

#define KEYPAD_INT(reg, ...) reg##0##__VA_ARGS__
#define KEYPAD_INT_PINS(reg) reg##B

// static char keymap[4][4];
.lcomm keymap, 4 * 4

// static void (*onKeypadPressCallback)(char);
.lcomm onKeypadPressCallback, 2

// static void onPress() {
onPress:

    // Don't trigger any interrupts while strobing the keypad
    // KEYPAD_INT(PCMSK) = 0;
    sts _SFR_MEM_ADDR(KEYPAD_INT(PCMSK)), r1

    // Pull low each row one by one to find which buttons are pressed

    // uint8_t row = 0;
    // KEYPAD(PORT) = (~(1 << KEYPAD_ROW0) & KEYPAD_ROWS) | KEYPAD_COLS;
    // __builtin_avr_delay_cycles(2);
    // uint8_t input = ~KEYPAD(PIN) & KEYPAD_COLS;
    clr r24
    ldi r23, (~(1 << KEYPAD_ROW0) & KEYPAD_ROWS) | KEYPAD_COLS
    sts _SFR_MEM_ADDR(KEYPAD(PORT)), r23
    nop
    nop
    lds r22, _SFR_MEM_ADDR(KEYPAD(PIN))
    com r22
    andi r22, KEYPAD_COLS

    // if (!input) {
    brnz onPress_gotInput

    //     row = 1;
    //     KEYPAD(PORT) = (~(1 << KEYPAD_ROW1) & KEYPAD_ROWS) | KEYPAD_COLS;
    //     __builtin_avr_delay_cycles(2);
    //     input = ~KEYPAD(PIN) & KEYPAD_COLS;
    ldi r24, 1
    ldi r23, (~(1 << KEYPAD_ROW1) & KEYPAD_ROWS) | KEYPAD_COLS
    sts _SFR_MEM_ADDR(KEYPAD(PORT)), r23
    nop
    nop
    lds r22, _SFR_MEM_ADDR(KEYPAD(PIN))
    com r22
    andi r22, KEYPAD_COLS
    // }

    // if (!input) {
    brnz onPress_gotInput

    //     row = 2;
    //     KEYPAD(PORT) = (~(1 << KEYPAD_ROW2) & KEYPAD_ROWS) | KEYPAD_COLS;
    //     __builtin_avr_delay_cycles(2);
    //     input = ~KEYPAD(PIN) & KEYPAD_COLS;
    ldi r24, 2
    ldi r23, (~(1 << KEYPAD_ROW2) & KEYPAD_ROWS) | KEYPAD_COLS
    sts _SFR_MEM_ADDR(KEYPAD(PORT)), r23
    nop
    nop
    lds r22, _SFR_MEM_ADDR(KEYPAD(PIN))
    com r22
    andi r22, KEYPAD_COLS
    // }

    // if (!input) {
    brnz onPress_gotInput

    //     row = 3;
    //     KEYPAD(PORT) = (~(1 << KEYPAD_ROW3) & KEYPAD_ROWS) | KEYPAD_COLS;
    //     __builtin_avr_delay_cycles(2);
    //     input = ~KEYPAD(PIN) & KEYPAD_COLS;
    ldi r24, 3
    ldi r23, (~(1 << KEYPAD_ROW3) & KEYPAD_ROWS) | KEYPAD_COLS
    sts _SFR_MEM_ADDR(KEYPAD(PORT)), r23
    nop
    nop
    lds r22, _SFR_MEM_ADDR(KEYPAD(PIN))
    com r22
    andi r22, KEYPAD_COLS
    // }

onPress_gotInput:
    // Restore the keypad's state
    // KEYPAD(PORT) = KEYPAD_COLS;
    ldi r23, KEYPAD_COLS;
    sts _SFR_MEM_ADDR(KEYPAD(PORT)), r23

    // KEYPAD_INT(PCMSK) = 0xff;
    ser r23
    sts _SFR_MEM_ADDR(KEYPAD_INT(PCMSK)), r23

    // Decode the column
    // uint8_t col;
    // if (input & (1 << KEYPAD_COL0))
    //     col = 0;
    // else if (input & (1 << KEYPAD_COL1))
    //     col = 1;
    // else if (input & (1 << KEYPAD_COL2))
    //     col = 2;
    // else if (input & (1 << KEYPAD_COL3))
    //     col = 3;
    sbrc r22, KEYPAD_COL3
    ldi XL, 3
    sbrc r22, KEYPAD_COL2
    ldi XL, 2
    sbrc r22, KEYPAD_COL1
    ldi XL, 1
    sbrc r22, KEYPAD_COL0
    ldi XL, 0

    // Call the callback
    // onKeypadPressCallback(keymap[row][col]);
    lsl r24
    lsl r24
    add XL, r24
    clr XH
    subi XL, lo8(-(keymap))
    sbci XH, hi8(-(keymap))
    ld r24, X
    lds ZL, onKeypadPressCallback
    lds ZH, onKeypadPressCallback + 1
    eijmp
// }


// void onKeypadPress(void (*callback)(char)) {
    .global onKeypadPress
onKeypadPress:

    // onKeypadPressCallback = callback;
	sts onKeypadPressCallback, r24
	sts onKeypadPressCallback + 1, r25

    // onDebouncedInterrupt(KEYPAD_INT(PCINT, _vect_num), (void (*)(uint8_t))onPress);
	ldi r22, lo8(gs(onPress))
	ldi r23, hi8(gs(onPress))
	ldi r24, KEYPAD_INT(PCINT, _vect_num)
	jmp onDebouncedInterrupt
// }

// void keypadSetup() {
    .global keypadSetup
keypadSetup:

    // keymap[0][0] = '1';
    // keymap[0][1] = '2';
    // keymap[0][2] = '3';
    // keymap[0][3] = 'A';
    ldi r24, '1'
    sts keymap + 0 * 4 + 0, r24
    ldi r24, '2'
    sts keymap + 0 * 4 + 1, r24
    ldi r24, '3'
    sts keymap + 0 * 4 + 2, r24
    ldi r24, 'A'
    sts keymap + 0 * 4 + 3, r24

    // keymap[1][0] = '4';
    // keymap[1][1] = '5';
    // keymap[1][2] = '6';
    // keymap[1][3] = 'B';
    ldi r24, '4'
    sts keymap + 1 * 4 + 0, r24
    ldi r24, '5'
    sts keymap + 1 * 4 + 1, r24
    ldi r24, '6'
    sts keymap + 1 * 4 + 2, r24
    ldi r24, 'B'
    sts keymap + 1 * 4 + 3, r24

    // keymap[2][0] = '7';
    // keymap[2][1] = '8';
    // keymap[2][2] = '9';
    // keymap[2][3] = 'C';
    ldi r24, '7'
    sts keymap + 2 * 4 + 0, r24
    ldi r24, '8'
    sts keymap + 2 * 4 + 1, r24
    ldi r24, '9'
    sts keymap + 2 * 4 + 2, r24
    ldi r24, 'C'
    sts keymap + 2 * 4 + 3, r24

    // keymap[3][0] = '*';
    // keymap[3][1] = '0';
    // keymap[3][2] = '#';
    // keymap[3][3] = 'D';
    ldi r24, '*'
    sts keymap + 3 * 4 + 0, r24
    ldi r24, '0'
    sts keymap + 3 * 4 + 1, r24
    ldi r24, '#'
    sts keymap + 3 * 4 + 2, r24
    ldi r24, 'D'
    sts keymap + 3 * 4 + 3, r24

    // KEYPAD(DDR) = KEYPAD_ROWS;
    // KEYPAD(PORT) = KEYPAD_COLS; // Rows pulled low; Columns pulled high
    ldi r24, KEYPAD_ROWS
    sts _SFR_MEM_ADDR(KEYPAD(DDR)), r24
    ldi r24, KEYPAD_COLS
    sts _SFR_MEM_ADDR(KEYPAD(PORT)), r24

    // KEYPAD_INT_PINS(DDR) = 0;
    // KEYPAD_INT_PINS(PORT) = 0xff;
    // KEYPAD_INT(PCMSK) = 0xff;
    // PCICR = 1 << KEYPAD_INT(PCIE);
    sts _SFR_MEM_ADDR(KEYPAD_INT_PINS(DDR)), r1
    ser r24
    sts _SFR_MEM_ADDR(KEYPAD_INT_PINS(PORT)), r24
    sts _SFR_MEM_ADDR(KEYPAD_INT(PCMSK)), r24
    ldi r24, 1 << KEYPAD_INT(PCIE)
    sts _SFR_MEM_ADDR(PCICR), r24

    ret
// }
