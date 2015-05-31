#include <avr/io.h>
#include "util.h"
#include "magnetron.h"

// In milliseconds
#define ENTRY_BEEP_LENGTH 250
#define FINISH_BEEP_LENGTH 1000
#define FINISH_BEEP_TIMES 3

#define BUTTONS(reg) reg##D
#define BUTTON_OPEN PD1
#define BUTTON_CLOSE PD0
#define BUTTON_OPEN_INT(reg) reg##1
#define BUTTON_OPEN_INT_S(reg, suf) reg##1##suf
#define BUTTON_CLOSE_INT(reg) reg##0
#define BUTTON_CLOSE_INT_S(reg, suf) reg##0##suf

#define POWER_LEDS(reg) reg##C
#define POWER_LEDS_MAX_MASK 0xff
#define POWER_LEDS_HALF_MASK 0x0f
#define POWER_LEDS_QUARTER_MASK 0x03

#define STATUS_LEDS(reg) reg##G
#define STATUS_LED_OPEN PG2

// static enum {
//     MODE_ENTRY,
//     MODE_POWER_SELECT,
//     MODE_RUNNING,
//     MODE_PAUSED,
//     MODE_FINISHED
// } currentMode;
#define MODE_ENTRY 0
#define MODE_POWER_SELECT (MODE_ENTRY + 1)
#define MODE_RUNNING (MODE_POWER_SELECT + 1)
#define MODE_PAUSED (MODE_RUNNING + 1)
#define MODE_FINISHED (MODE_PAUSED + 1)
.lcomm currentMode, 1

// static PowerSetting currentPowerSetting;
.lcomm currentPowerSetting, sizeof_PowerSetting

// static enum {
//     DOOR_CLOSED,
//     DOOR_OPENED
// } currentDoorState;
#define DOOR_CLOSED 0
#define DOOR_OPENED (DOOR_CLOSED + 1)
.lcomm currentDoorState, 1

// static void* countdownTimeInterval;
.lcomm countdownTimeInterval, 2

// static void countdownTime() {
countdownTime:

    // timerAddSeconds(-1);
    ldi r24, -1
    call timerAddSeconds

    // if (timerIsZero())
    //     stopMicrowave();
    call timerIsZero
    cpse r24, r1
    jmp stopMicrowave
    ret
// }

// static void resetMicrowave() {
resetMicrowave:

    // currentMode = MODE_ENTRY;
    ldi r24, MODE_ENTRY
    sts currentMode, r24

    // displayEnableDimming(true);
    // displayActivate();
    ldi r24, 1
    call displayEnableDimming
    call displayActivate

    // Clear any unwanted existing text
    // displayStatusClear();
    // timerClear();
    call displayStatusClear
    jmp timerClear
// }

// static void startMicrowave() {
startMicrowave:

    // timerSetDefaultIfEmpty();
    // timerAddSeconds(0); // Normalise the timer
    call timerSetDefaultIfEmpty
    clr r24
    call timerAddSeconds

    // if (timerIsZero()) {
    //     stopMicrowave();
    //     return;
    // }
    call timerIsZero
    cpse r24, r1
    jmp stopMicrowave

    // currentMode = MODE_RUNNING;
    // displayEnableDimming(false);
    // displayActivate();
    ldi r24, MODE_RUNNING
    sts currentMode, r24
    clr r24
    call displayEnableDimming
    call displayActivate

    // countdownTimeInterval = setInterval((void (*)(uint8_t, bool))countdownTime, 0, 1000, 0);
    clr r18
    clr r19
    ldi r20, lo8(1000)
    ldi r21, hi8(1000)
    clr r22
    ldi r24, lo8(gs(countdownTime))
    ldi r25, hi8(gs(countdownTime))
    call setInterval
    sts countdownTimeInterval, r24
    sts countdownTimeInterval + 1, r25

    // turntableReverseDirection();
    // turntableSetActive(true);
    // magnetronSetPower(currentPowerSetting);
    call turntableReverseDirection
    ldi r24, 1
    call turntableSetActive
    lds r24, currentPowerSetting
    jmp magnetronSetPower
// }

// static void pauseMicrowave() {
pauseMicrowave:

    // currentMode = MODE_PAUSED;
    // displayEnableDimming(true);
    // displayActivate();
    ldi r24, MODE_PAUSED
    sts currentMode, r24
    ldi r24, 1
    call displayEnableDimming
    call displayActivate

    // magnetronSetPower(POWER_OFF);
    // turntableSetActive(false);
    ldi r24, POWER_OFF
    call magnetronSetPower
    clr r24
    call turntableSetActive

    // if (countdownTimeInterval) {
    lds r24, countdownTimeInterval
    lds r25, countdownTimeInterval + 1
    sbiw r24, 0
    breq pauseMicrowave_end

    //     clearInterval(countdownTimeInterval);
    call clearInterval

    //     countdownTimeInterval = 0;
    sts countdownTimeInterval, r1
    sts countdownTimeInterval + 1, r1

    // }

pauseMicrowave_end:
    ret
// }

// static void stopMicrowave() {
stopMicrowave:

    // pauseMicrowave();
    // currentMode = MODE_FINISHED;
    call pauseMicrowave
    ldi r24, MODE_FINISHED
    sts currentMode, r24

    // displayStatusRemoveFood();
    // beepSet(FINISH_BEEP_LENGTH, FINISH_BEEP_TIMES);
    call displayStatusRemoveFood
    ldi r22, FINISH_BEEP_TIMES
    ldi r24, lo8(FINISH_BEEP_LENGTH)
    ldi r25, hi8(FINISH_BEEP_LENGTH)
    jmp beepSet
// }

// static void onEntryKeypadPress(char key) {
onEntryKeypadPress:

    // if ('0' <= key && key <= '9') {
    //     timerInput(key - '0');
    mov r22, r24
    subi r24, '0'
    cpi r24, 10
    skipIf sh // key - '0' < 10
    jmp timerInput

    // } else if (key == '*') {
    //     startMicrowave();
    cpi r22, '*'
    skipIf ne
    jmp startMicrowave

    // } else if (key == '#') {
    //     timerClear();
    cpi r22, '#'
    skipIf ne
    jmp timerClear

    // } else if (key == 'A') {
    cpi r22, 'A'
    skipIf eq
    ret

    //     currentMode = MODE_POWER_SELECT;
    //     displayStatusSetPower();
    ldi r24, MODE_POWER_SELECT
    sts currentMode, r24
    jmp displayStatusSetPower
    // }
// }

// static void onPowerSelectKeypadPress(char key) {
onPowerSelectKeypadPress:

    // if (key == '#' || ('1' <= key && key <= '3')) {
    cpi r24, '#'
    breq onPowerSelectKeypadPress_exitMode
    mov r22, r24
    subi r22, '1'
    cpi r22, 3
    skipIf lo // key - '1' < 3
    ret

onPowerSelectKeypadPress_validKey:
    //     if (key == '1') {
    cpi r24, '1'
    brne onPowerSelectKeypadPress_keyNot1

    //         currentPowerSetting = POWER_MAX;
    //         POWER_LEDS(PORT) = POWER_LEDS_MAX_MASK;
    ldi r22, POWER_MAX
    ldi r24, POWER_LEDS_MAX_MASK
    rjmp onPowerSelectKeypadPress_saveSetting

onPowerSelectKeypadPress_keyNot1:
    //     } else if (key == '2') {
    cpi r24, '2'
    brne onPowerSelectKeypadPress_keyNot2

    //         currentPowerSetting = POWER_HALF;
    //         POWER_LEDS(PORT) = POWER_LEDS_HALF_MASK;
    ldi r22, POWER_HALF
    ldi r24, POWER_LEDS_HALF_MASK
    rjmp onPowerSelectKeypadPress_saveSetting

onPowerSelectKeypadPress_keyNot2:
    //     } else if (key == '3') {
    //         currentPowerSetting = POWER_QUARTER;
    //         POWER_LEDS(PORT) = POWER_LEDS_QUARTER_MASK;
    ldi r22, POWER_QUARTER
    ldi r24, POWER_LEDS_QUARTER_MASK
    //     }

onPowerSelectKeypadPress_saveSetting:
    sts currentPowerSetting, r22
    out _SFR_IO_ADDR(POWER_LEDS(PORT)), r24

onPowerSelectKeypadPress_exitMode:
    //     currentMode = MODE_ENTRY;
    //     displayStatusClear(); // Remove the "set power" text
    ldi r24, MODE_ENTRY
    sts currentMode, r24
    jmp displayStatusClear
    // }
// }

// static void onRunningKeypadPress(char key) {
onRunningKeypadPress:

    // if (key == '#') {
    //     pauseMicrowave();
    cpi r24, '#'
    skipIf ne
    jmp pauseMicrowave

    // } else if (key == '*') {
    //     timerAddSeconds(60);
    cpi r24, '*'
    skip2If ne
    ldi r24, 60
    jmp timerAddSeconds

    // } else if (key == 'C') {
    //     timerAddSeconds(30);
    cpi r24, 'C'
    skip2If ne
    ldi r24, 30
    jmp timerAddSeconds

    // } else if (key == 'D') {
    cpi r24, 'D'
    brne onRunningKeypadPress_end

    //     timerAddSeconds(-30);
    ldi r24, -30
    call timerAddSeconds

    //     if (timerIsZero())
    //         stopMicrowave();
    call timerIsZero
    cpse r24, r1
    jmp stopMicrowave
    // }

onRunningKeypadPress_end:
    ret
// }

// static void onPausedKeypadPress(char key) {
onPausedKeypadPress:

    // if (key == '#')
    //     resetMicrowave();
    cpi r24, '#'
    skipIf ne
    jmp resetMicrowave

    // else if (key == '*')
    //     startMicrowave();
    cpi r24, '*'
    skipIf ne
    jmp startMicrowave

    ret
// }

// static void onFinishedKeypadPress(char key) {
onFinishedKeypadPress:

    // if (key == '#')
    //     resetMicrowave();
    cpi r24, '#'
    skipIf ne
    jmp resetMicrowave
    ret
// }

// static void onKeypad(char key) {
onKeypad:

    // beepSet(ENTRY_BEEP_LENGTH, 1);
    // displayActivate();
    push r24
    ldi r22, 1
    ldi r24, ENTRY_BEEP_LENGTH
    call beepSet
    call displayActivate
    pop r24

    // if (currentDoorState == DOOR_OPENED)
    //     return;
    lds r22, currentDoorState
    cpi r22, DOOR_OPENED
    skipIf ne
    ret

    // switch (currentMode) {
    //     case MODE_ENTRY:
    //         onEntryKeypadPress(key);
    //         break;

    //     case MODE_POWER_SELECT:
    //         onPowerSelectKeypadPress(key);
    //         break;

    //     case MODE_RUNNING:
    //         onRunningKeypadPress(key);
    //         break;

    //     case MODE_PAUSED:
    //         onPausedKeypadPress(key);
    //         break;

    //     case MODE_FINISHED:
    //         onFinishedKeypadPress(key);
    //         break;
    // }
    lds ZL, currentMode
    lsl ZL
    clr ZH
    subi ZL, lo8(-(onKeypad_switch_jumptable))
    sbci ZH, hi8(-(onKeypad_switch_jumptable))
    lpm r0, Z+
    lpm ZH, Z
    mov ZL, r0
    eijmp

onKeypad_switch_jumptable:
    .word gs(onEntryKeypadPress)
    .word gs(onPowerSelectKeypadPress)
    .word gs(onRunningKeypadPress)
    .word gs(onPausedKeypadPress)
    .word gs(onFinishedKeypadPress)
// }

// static void onOpenButton() {
onOpenButton:

    // beepSet(ENTRY_BEEP_LENGTH, 1);
    // displayActivate();
    ldi r22, 1
    ldi r24, ENTRY_BEEP_LENGTH
    call beepSet
    call displayActivate

    // if (currentDoorState == DOOR_OPENED)
    //     return;
    lds r24, currentDoorState
    cpi r24, DOOR_OPENED
    breq onOpenButton_end

    // currentDoorState = DOOR_OPENED;
    ldi r24, DOOR_OPENED
    sts currentDoorState, r24

    // displayUpdateDoor(true);
    // STATUS_LEDS(PORT) |= 1 << STATUS_LED_OPEN;
    ldi r24, 1
    call displayUpdateDoor
    sbi _SFR_IO_ADDR(STATUS_LEDS(PORT)), STATUS_LED_OPEN

    // if (currentMode == MODE_RUNNING)
    //     pauseMicrowave();
    lds r24, currentMode
    cpi r24, MODE_RUNNING
    skipIf ne
    jmp pauseMicrowave

    // else if (currentMode == MODE_FINISHED)
    //     resetMicrowave();
    cpi r24, MODE_FINISHED
    skipIf ne
    jmp resetMicrowave

onOpenButton_end:
    ret
// }

// static void onCloseButton() {
onCloseButton:

    // beepSet(ENTRY_BEEP_LENGTH, 1);
    // displayActivate();
    ldi r22, 1
    ldi r24, ENTRY_BEEP_LENGTH
    call beepSet
    call displayActivate

    // if (currentDoorState == DOOR_CLOSED)
    //     return;
    lds r24, currentDoorState
    cpi r24, DOOR_CLOSED
    breq onCloseButton_end

    // currentDoorState = DOOR_CLOSED;
    ldi r24, DOOR_CLOSED
    sts currentDoorState, r24

    // displayUpdateDoor(false);
    // STATUS_LEDS(PORT) &= ~(1 << STATUS_LED_OPEN);
    clr r24
    call displayUpdateDoor
    cbi _SFR_IO_ADDR(STATUS_LEDS(PORT)), STATUS_LED_OPEN

onCloseButton_end:
    ret
// }

// void setup() {
    .global setup
setup:

    // displaySetup();
    // keypadSetup();
    // magnetronSetup();
    // turntableSetup();
    // beepSetup();
    call displaySetup
    call keypadSetup
    call magnetronSetup
    call turntableSetup
    call beepSetup

    // BUTTONS(DDR) &= ~((1 << BUTTON_OPEN) | (1 << BUTTON_CLOSE));
    cbi _SFR_IO_ADDR(BUTTONS(DDR)), BUTTON_OPEN
    cbi _SFR_IO_ADDR(BUTTONS(DDR)), BUTTON_CLOSE

    // BUTTONS(PORT) |= (1 << BUTTON_OPEN) | (1 << BUTTON_CLOSE);
    sbi _SFR_IO_ADDR(BUTTONS(PORT)), BUTTON_OPEN
    sbi _SFR_IO_ADDR(BUTTONS(PORT)), BUTTON_CLOSE

    // // Falling edge for buttons
    // EICRA &= ~(0 << BUTTON_OPEN_INT(ISC, 0)) & ~(0 << BUTTON_CLOSE_INT(ISC, 0));
    // EICRA |= (1 << BUTTON_OPEN_INT(ISC, 1)) | (1 << BUTTON_CLOSE_INT(ISC, 1));
    lds r24, _SFR_MEM_ADDR(EICRA)
    andi r24, ~(0 << BUTTON_OPEN_INT_S(ISC, 0)) & ~(0 << BUTTON_CLOSE_INT_S(ISC, 0))
    ori r24, (1 << BUTTON_OPEN_INT_S(ISC, 1)) | (1 << BUTTON_CLOSE_INT_S(ISC, 1))
    sts _SFR_MEM_ADDR(EICRA), r24

    // EIMSK |= (1 << BUTTON_OPEN_INT(INT)) | (1 << BUTTON_CLOSE_INT(INT));
    sbi _SFR_IO_ADDR(EIMSK), BUTTON_OPEN_INT(INT)
    sbi _SFR_IO_ADDR(EIMSK), BUTTON_CLOSE_INT(INT)

    // POWER_LEDS(DDR) = 0xff;
    // POWER_LEDS(PORT) = POWER_LEDS_MAX_MASK;
    ldi r24, 0xff
    out _SFR_IO_ADDR(POWER_LEDS(DDR)), r24
    ldi r24, POWER_LEDS_MAX_MASK
    out _SFR_IO_ADDR(POWER_LEDS(PORT)), r24

    // STATUS_LEDS(DDR) = 0xff;
    // STATUS_LEDS(PORT) = 0;
    ldi r24, 0xff
    out _SFR_IO_ADDR(STATUS_LEDS(DDR)), r24
    clr r24
    out _SFR_IO_ADDR(STATUS_LEDS(PORT)), r24

    // onKeypadPress(onKeypad);
    ldi r24, lo8(gs(onKeypad))
    ldi r25, hi8(gs(onKeypad))
    call onKeypadPress

    // onDebouncedInterrupt(BUTTON_OPEN_INT(INT, _vect_num), (void (*)(uint8_t))onOpenButton);
    ldi r22, lo8(gs(onOpenButton))
    ldi r23, hi8(gs(onOpenButton))
    ldi r24, BUTTON_OPEN_INT_S(INT, _vect_num)
    call onDebouncedInterrupt

    // onDebouncedInterrupt(BUTTON_CLOSE_INT(INT, _vect_num), (void (*)(uint8_t))onCloseButton);
    ldi r22, lo8(gs(onCloseButton))
    ldi r23, hi8(gs(onCloseButton))
    ldi r24, BUTTON_CLOSE_INT_S(INT, _vect_num)
    call onDebouncedInterrupt

    // resetMicrowave();
    jmp resetMicrowave
// }
