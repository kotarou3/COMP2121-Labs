# Microwave Emulator Design Manual

## Overview
The code is seperated into two sections:
 - **Library** code are highly reusable components designed to be easily included in any project.
 - **Project** code are the more specific components designed to be used for the project only.

All functions (except interrupt entry points) follow the [GCC AVR ABI](http://www.atmel.com/webdoc/AVRLibcReferenceManual/FAQ_1faq_reg_usage.html) for ease of debugging, interoperability and consistency. This also means that module descriptions can be easily given in C.<br />
AVR Assembler's preprocessor is used for including files (`#include`) and defining constants (`#define`) rather than using the pseudo-ops (`.include` and `.equ`).<br />
The code itself is mostly self-documenting (via the equivalent C code above each block of opcodes).

The entire system is event-based, with everything running under non-nested interrupts, whether timer or hardware, to avoid potential problems that might arise from re-entrant code.

## Module Descriptions
![](https://rawgit.com/kotarou3/COMP2121-Labs/master/project/dependencies.svg "Dependency Graph")

Please refer to the above dependency graph.<br />
Blue nodes are project code, while orange nodes are library code.<br />
Blue edges are dependencies on project code, while black edges are dependencies on libraries.

Each module description will be given in a C API-style description.

### `lib/events`
This module is the entry point of the program, as well as any interrupts.<br />
After some internal housekeeping and initialisation, it will call `setup()`, which must be defined as a global elsewhere in the codebase.

This module controls the main event loop, which is a timer triggered to interrupt every 8 ms. Other modules can register callbacks to be called at these timer interrupts through the `set*` functions. It is somewhat modelled after the javascript `setTimeout` and `setInterval` functions.

This module also provides `onInterrupt` and `onDebouncedInterrupt` to register interrupt callbacks from anywhere in the codebase. This allows modules to bind their own interrupts without having to directly edit the interrupt vector table.

    void _start();

Internal entry point of the program.<br />
It does some low-level housekeeping (e.g., setting up the stack) before jumping to `start()`

    void _emitInterrupt(uint8_t vectorNumber);

Interrupts will load their vector number into the first argument and immediately jump to this internal function.<br />
The function will immediately look up the bound callback to the interrupt and call it as a normal function.

    void start();

Called by the internal entry point of the program.<br />
The function will perform some housekeeping (e.g., clear all RAM to 0) and then set up the main event loop timer. It then calls `setup()` before enabling interrupts and entering an infinite sleep loop.

    void* setTimeout(void (*callback)(uint8_t), uint8_t arg, uint16_t milliseconds);
 - `void (*callback)(uint8_t)`: Callback to be registered. First argument passed will be `arg`
 - `uint8_t arg`: Argument that will be passed to `callback()`
 - `uint16_t milliseconds`: Delay before `callback()` is called
 - Returns `void*` opaque type that can be passed to `clearTimeout()`

Registers `callback` to be called with `arg` once, after `milliseconds` milliseconds or more have passed.

    void* setInterval(void (*callback)(uint8_t, bool), uint8_t arg, uint16_t milliseconds, uint16_t times);
    void* setIntervalWithDelay(void (*callback)(uint8_t, bool), uint8_t arg, uint16_t delay, uint16_t milliseconds, uint16_t times);
 - `void (*callback)(uint8_t, bool)`: Callback to be registered. First argument passed will be `arg`. Second argument will be if this is the last time the callback will be called.
 - `uint8_t arg`: First argument that will be passed to `callback`
 - `uint16_t delay`: Extra time that will be added on to `milliseconds` for only the first call
 - `uint16_t milliseconds`: Delay between each `callback` call
 - `uint16_t times`: Number of times to call the callback. Set to `0` for an indefinite number of times
 - Returns `void*` opaque type that can be passed to `clearInterval()`

These functions register `callback` to be called with `arg` every `milliseconds` milliseconds, with an optional first extra delay of `delay` and number of times `times`.<br />
The second argument passed to `callback` represents if it is the last time it will be called for a specific `setInterval`. It will only ever be true if `times` is non-zero.

    void clearTimeout(void* timeout);
    void clearInterval(void* interval);
 - `void* timeout/interval`: The timeout or interval to be cleared

These functions clear a timeout or interval, respectively, so the registered callback will no longer be called.<br />
They must not be called on an expired timeout or interval (i.e., already called for the last time).

    void onInterrupt(uint8_t vectorNumber, void (*callback)(uint8_t));
    void onDebouncedInterrupt(uint8_t vectorNumber, void (*callback)(uint8_t));
 - `uint8_t vectorNumber`: Vector number of the interrupt to bind `callback` to
 - `void (*callback)(uint8_t)`: Callback to be called whenever the interrupt is triggered. First argument is the vector number

Binds `callback` to the interrupt specified by `vectorNumber`.<br />
Only one callback can be bound to each interrupt at a time. Subsequent calls with the same vector number will overwrite the previous callback.<br />
Optionally software-debounces the interrupt on a falling edge with a debounce interval of 30 ms.

    void busyWait(uint8_t milliseconds);
- `uint8_t milliseconds`: Number of milliseconds to wait

Waits for `milliseconds` milliseconds without handing back control to the event loop.

### `lib/circular-buffer`
Implements a circular buffer.

    void CircularBuffer_init(CircularBuffer* buffer, uint8_t* rawBuffer, uint16_t rawBufferSize, bool isOverwriteAllowed);
 - `CircularBuffer* buffer`: The buffer to initialise
 - `uint8_t* rawBuffer`: The raw buffer to use as the circular buffer's backing storage
 - `uint16_t rawBufferSize`: Size of `rawBuffer` in bytes
 - `bool isOverwriteAllowed`: Disable/enable overwriting of old data in the buffer

Intialises circular buffer `buffer` with backing storage `rawBuffer`, while specifying if old data is allowed to be overwritten.

    uint16_t CircularBuffer_size(CircularBuffer* buffer);
    bool CircularBuffer_isEmpty(CircularBuffer* buffer);
    bool CircularBuffer_isFull(CircularBuffer* buffer);
 - `CircularBuffer* buffer`: The buffer to query

Various functions for querying the number of elements currently stored in the buffer.

    void CircularBuffer_clear(CircularBuffer* buffer);
 - `CircularBuffer* buffer`: The buffer to clear

Clears all elements currently stored in the buffer.

    void CircularBuffer_pushBack(CircularBuffer* buffer, uint8_t data);
    uint8_t CircularBuffer_popFront(CircularBuffer* buffer);
 - `CircularBuffer* buffer`: The buffer to modify

Pushes a single element to the back of the buffer, or pops from the front.<br />
`isOverwriteAllowed` specified in the `CircularBuffer_init()` call to the buffer controls whether pushing overwrites old data or not.

    uint8_t CircularBuffer_top(CircularBuffer* buffer);
 - `CircularBuffer* buffer`: The buffer to query
 - Returns `uint8_t` as the backmost element in the buffer

Returns the backmost element in the buffer.<br />
Cannot be called when the buffer is empty.

### `lib/divmod`
Implements binary long division as specified in the [wikipedia article](http://en.wikipedia.org/wiki/Division_algorithm#Integer_division_.28unsigned.29_with_remainder).<br />
All functions return the remainder in upper half and the quotient in lower half.

    uint16_t udivmod8(uint8_t dividend, uint8_t divisor);
    uint32_t udivmod16(uint16_t dividend, uint16_t divisor);
 - `uint8_t/uint16_t dividend`: The dividend
 - `uint8_t/uint16_t divisor`: The divisor
 - Returns a `uint16_t/uint32_t` with the quotient in the lower half and remainder in the upper half.

Performs binary long division on two unsigned 8-bit or 16-bit values.<br />
The quotient is returned in the lower byte for `udivmod8` and lower word for `udivmod16`, while the remainder will be in the upper byte/word.

### `lib/keypad`
Provides helper functions for easily interfacing with the keypad.

    void keypadSetup();
Must be called to setup IO pins and interrupts for the keypad.

    void onKeypadPress(void (*callback)(char));
 - `void (*callback)(char)`: Callback to be called when a key has been pressed. The first argument will be the detected key

Registers `callback` to be called whenever a key press on the keypad is detected. The first argument to `callback` will be the ASCII representation of the key pressed.<br />
Only one callback can be registered at a time. Subsequent registrations will overwrite previous ones.

### `lib/lcd`
Provides helper functions for easily interfacing with the LCD.

    void lcdSetup();
Must be called to setup IO pins for the LCD and initialising the LCD itself.

    void lcdClear();
Clears the LCD.

    void lcdClearSection(bool isBottomRow, uint8_t startCol, uint8_t length);
 - `bool isBottomRow`: The row to start clearing from
 - `uint8_t startCol`: The column to start clearing from
 - `uint8_t length`: The number of characters to clear

Clears a specific section of the LCD by writing spaces to it. Also moves cursor to the start of the cleared section.

    void lcdSetCursor(bool isBottomRow, uint8_t col);
 - `bool isBottomRow`: The row to move the cursor to
 - `uint8_t col`: The column to move the cursor to

Moves the cursor to the specified row and column.

    void lcdShiftCursor(bool isRight);
 - `bool isRight`: Specifies shifting the cursor left or right

Shift the cursor left or right by a single column

    void lcdStartCustomGlyphWrite(char c);
 - `char c`: Character code of the glyph to define. Must be between `0` and `8` inclusive

Moves the cursor to glyph `c` in CGRAM so subsequent writes will define the glyph for `c`.

    void lcdWrite(char c);
 - `char c`: Character to write

Writes a single character to the LCD.

    void lcdWriteString(const char* str);
    void lcdWriteStringProgMem(const char* str);
 - `const char* str`: String to write

Write a C string, that optionally can be in program memory, to the LCD.

    void lcdWriteUInt(uint16_t n);
 - `uint16_t n`: Number to write

Writes a number in base-10 to the LCD.<br />
Uses functions from `lib/divmod` to perform the conversion from base-2 to base-10.

### `lib/motor`
Provides helper functions for easily interfacing with the motor.

    void motorSetup();
Must be called to setup IO pins and interrupts for the motor and optical detector, and other various initialisation.

    uint8_t motorGetRps();
 - Returns `uint8_t` with the current RPS

Get the current motor RPS calculated from the optical detector interrupts, and averaged over a full rotation.<br />
Uses functions from `lib/circular-buffer` to store and average the detected RPSes.

    void motorSetRps(uint8_t rps);
 - `uint8_t rps`: Target RPS to set the motor to

Configure the code to attempt to match the real motor speed to `rps` through PWM.

### `project/main`
