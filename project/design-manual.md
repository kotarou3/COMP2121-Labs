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

Each module description will be given in a C API-style description.<br />
Only the main functions in each module will be described.

### `lib/events`
This module is the entry point of the program, as well as any interrupts.<br />
After some internal housekeeping and initialisation, it will call `setup()`, which must be defined as a global elsewhere in the codebase.

This module controls the main event loop, which is a timer triggered to interrupt every 8 ms. Other modules can register callbacks to be called at these timer interrupts through the `set*` functions. It is somewhat modelled after the javascript `setTimeout` and `setInterval` functions.

This module also provides `onInterrupt` and `onDebouncedInterrupt` to register interrupt callbacks from anywhere in the codebase. This allows modules to bind their own interrupts without having to directly edit the interrupt vector table.

    static void _start();

Internal entry point of the program.<br />
It does some low-level housekeeping (e.g., setting up the stack) before jumping to `start()`

    static void _emitInterrupt(uint8_t vectorNumber);

Interrupts will load their vector number into the first argument and immediately jump to this internal function.<br />
The function will immediately look up the bound callback to the interrupt and call it as a normal function.

    static void start();

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
Main code for the microwave, mapping inputs to do things as well as controlling the microwave's state.<br />
Usually calls the other `project/*` modules to output actions to hardware.

    void setup();
Called from `lib/events` to set up the main code.<br />
Sets up all the hardware components in each of the `project/*` modules, IO pins for the LEDs and buttons, and interrupts for the buttons.<br />
Registers `onKeypad()` as the keypad press callback, and `on*Button()` for the buttons, before calling `resetMicrowave()`.

    static void resetMicrowave();
    static void startMicrowave();
    static void pauseMicrowave();
    static void stopMicrowave();
Functions that are called to change between the four main microwave modes.<br />
Performs all the actions required upon a mode change, such as pausing the magnetron when entering pause mode.

    static void onKeypad(char key);
    static void onEntryKeypadPress(char key);
    static void onPowerSelectKeypadPress(char key);
    static void onRunningKeypadPress(char key);
    static void onPausedKeypadPress(char key);
    static void onFinishedKeypadPress(char key);
Functions that are called upon a key press on the keypad.<br />
Entry first enters in `onKeypad()`, where it will dispatch the keypress to the appropiate `on*KeypadPress()` function depending on the current microwave mode.<br />
The `on*KeypadPress()` functions will perform the appropiate actions depending on which key was pressed.

    static void onOpenButton();
    static void onCloseButton();
Functions that are called upon a button press, and performs the appropiate actions.

### `project/beeper`
Controls the speaker for the purpose of outputting beeps.<br />
The beep is a 3125 Hz sine wave.

    void beepSetup();
Initialises the IO pin and PWM for outputting to the speaker.

    void beepSet(uint16_t length, uint8_t times);
 - `uint16_t length`: Length of time for each beep and silence, in milliseconds
 - `uint8_t times`: Number of times to beep. Set to `0` to clear any existing beep

Set the beeper to output `times` beeps of length `length` milliseconds, with each pause in between also of `length` milliseconds.<br />
If a new beep is set before the old one has finished, it ends the old beep immediately.

### `project/display`
Controls the LCD and backlight for the purposes of displaying the timer and other status text.

    void displaySetup();
Sets up the LCD, and PWM for the backlight.

    void displayActivate();
Lights up the backlight and restarts the timer for dimming, if dimming is enabled.

    void displayEnableDimming(bool isEnabling);
 - `bool isEnabling`: Specifies if the backlight should be allowed to dim or not.

Disables/enables dimming of the backlight.<br />
`displayActivate()` must be called for the changes to take effect.

    void displayUpdateTime(uint8_t minutes, uint8_t seconds);
 - `uint8_t minutes/seconds`: Minutes and seconds values to display

Displays `minutes` and `seconds` as a time value. That is, mm:ss.<br />
Leading zeros are not displayed. This means that if both `minutes` and `seconds` are zero, only a single seperating colon (`:`) will be displayed.

    void displayUpdateDoor(bool isOpen);
 - `bool isOpen`: Specifies if the door is opened or not

Updates the display with the door status.

    void displayStatusRemoveFood();
    void displayStatusSetPower();
    void displayStatusClear();
These functions updates or clears the status messages. That is, "Done; Remove food" and "Set Power 1/2/3".

### `project/magnetron`
Controls the motor to function as a magnetron.

    void magnetronSetup();
Sets up the magnetron.

    void magnetronSetPower(PowerSetting power);
 - `PowerSetting power`: Specifies the power level for the magnetron to output. Possible values are: `POWER_MAX`, `POWER_HALF`, `POWER_QUARTER`, `POWER_OFF`

### `project/turntable`
Controls a single character on the LCD to function as a turntable.<br />
A custom glyph is used for the backslash (`\`) because the LCD does not have it by default.

    void turntableSetup();
Sets up the turntable.

    void turntableSetActive(bool isActive);
 - `bool isActive`: Specifies if the turntable should be rotating or not


    void turntableReverseDirection();
Reverses the direction of the turntable rotation.

### `project/timer`
Controls the display, input and arithmetic on the timer. Actual counting down is controlled by `project/main`.<br />
Automatically updates the timer display whenever the timer mutates.

    void timerClear();
Clears the timer to 0 (blank) and any saved input.

    bool timerIsZero();
 - Returns `bool` representing if the timer is 0 or not


    void timerSetDefaultIfEmpty();
Sets the timer to the default value of `1:00` if no input has been detected for the timer.

    void timerAddSeconds(int8_t seconds);
 - `int8_t seconds`: Number of seconds to add (or subtract)

Performs addition/subtraction on the timer value.<br />
It clamps the result to `[00:00, 99:99]` while also normalising the seconds place to be &lt;60 if possible.

    void timerInput(uint8_t n);
 - `uint8_t n`: Number to input. Must be between `0` and `9` inclusive

Inputs the timer value one digit at a time.<br />
Tracks how many digits have been entered and ignores any further input after four digits have been entered.<br />
Leading zeros are ignored and do not contribute to the input counter.

## System Flow
![](https://rawgit.com/kotarou3/COMP2121-Labs/master/project/io-flow.svg "IO Flow Graph")

Please refer to the above flow graph.<br />
Blue nodes are project code, orange nodes are library code and grey nodes are hardware components.<br />
Blue edges are hardware interrupts, red edges are timer interrupts and green edges represents command passing or output.

For ease of understanding, even though all interrupts go through `lib/events` first, we instead assume that all interrupts go directly into the module that set it (i.e., we skip the interrupt dispatch step that exists inside `lib/events`).<br />
This means that only the system timer interrupts comes from `lib/events`.

Additionally, we will assume all modules/components have already been set up and initialised.

Because the system is event-based, all system flow starts at an interrupt. In this case, the majority starts from `hardware/keypad` and the system timer `lib/events`.

### `hardware/buttons`
When a button is pressed, a hardware interrupt is triggered and execution is passed to `project/main`, calling either its `onOpenButtonPress()` or `onCloseButtonPress()`.

### `hardware/keypad`
When a keypad button is pressed, a hardware interrupt is triggered and execution is passed to `lib/keypad`, calling its `onKeypad()`.

### `hardware/leds`
The LEDs receive `project/main`'s changes to the LED output pins and update themselves accordingly.

### `hardware/lcd`
The LCD receives instructions from `lib/lcd` and updates itself accordingly.

### `hardware/lcd-backlight`
The backlight receives a PWM signal from `project/display` and adjusts its own brightness accordingly.

### `hardware/motor`
The motor receives a PWM signal from `lib/motor` and changes torque accordingly.

### `hardware/optical-detector`
When a hole passes the detector (on the disk attached to the motor), a hardware interrupt is triggered and execution is passed to `lib/motor`, calling its `onDetectorFallingEdge()`.

### `hardware/speaker`
The speaker receives a PWM signal from `project/beeper` and changes its displacement accordingly.

### `lib/events`
Calls the callbacks registered by `lib/motor`, `project/main`, `project/magnetron` and `project/turntable` through the `setTimeout()` and `setInterval()` set of functions with the appropiate delays.<br />
See the respective module's descriptions for more detailed information.

### `lib/keypad`
Receives the interrupt generated by `hardware/keypad` and then scans through each row to detect exactly which key was pressed.<br />
When the key is found, `project/main`'s `onKeypad()` is called with the found key.

### `lib/lcd`
Receives commands from `project/display` and `project/turntable` to turn into instructions to pass to `hardware/lcd`.

### `lib/motor`
Receives commands from `project/magnetron` with regards to the target speed (i.e., 75 rps or 0). Also receives interrupts from `hardware/optical-detector` so the current real RPS of the motor can be estimated.<br />
`lib/event` calls `checkRps()` every 250 ms through the system timer, which then adjusts the output PWM to `hardware/motor` depending on the target and current motor RPS.

### `project/main`
Receives interrupts from `hardware/buttons` and commands from `lib/keypad` as user input.<br />
Depending on the current state of the microwave, commands may be dispatched to each of the other `project/*` modules to update the hardware they respectively control with regards to the input.<br />
This module also writes directly to the LED pins to update `hardware/leds` with the current power level and door state.

`lib/event` calls `countdownTime()` every second when the microwave is running to count down the timer, which then in turn may send commands to the other `project/*` modules.

This modules relationship with `project/timer` is somewhat special in that it manually checks if the timer is zero each time the timer is updated, rather than using a callback, to detect if cooking should be ended.

### `project/beeper`
Receives commands from `project/main` telling it how it should beep.

When outputting sound (i.e., during a beep), `updateWaveform()` is called every 31250 Hz via the PWM timer to adjust the PWM duty cycle such that it resembles a 3125 Hz sine wave when low-passed.<br />
The PWM signal is directly sent to `hardware/speaker` for it to output the sound.

### `project/display`
Receives commands from `project/main` (to update the status text and door status) and `project/timer` (to update the timer text), which is then processed and passed onto `lib/lcd`.

Also controls the dimming via PWM of `hardware/lcd-backlight` by resetting a 10 second timeout every time `displayActivate()` is called (from `project/main`), and having `doDim()` called every 8 ms to perform the actual dimming.

### `project/magnetron`
Receives commands from `project/main` specifying the magnetron power level to use.<br />
It then updates two intervals, one for turning the magnetron on and one for off, with the intervals required for the power levels.

Actual magnetron on and off commands are sent to `lib/motor` as RPS settings of `75` and `0` respectively.

### `project/turntable`
Receives commands from `project/main` specifying whether the turntable should be turning or not, and if the direction needs to be reversed.

Implemented by having `lib/events` call `rotateTurntable()` once per 2.5 seconds, which then updates the LCD with the appropiate character through `lib/lcd`.

### `project/timer`
Receives commands from `project/main` specifying how the timer should be updated, processes them, and then passes the current timer to `project/display` to be displayed.<br />
Also returns whether the timer is zero or not back to `project/main`.

## Data Structures
While the majority of the source files have some kind of data structure to them, most of them are merely timeout/interval variables, and are not very important to understanding how data is stored. Thus, they will be ignored for the purposes of this section.

### `lib/events`
Uses two main structures, `IntervalCallback` and `DebounceCallback`, along a few other state variables.

    typedef struct _IntervalCallback {
        uint8_t arg;
        uint16_t ticks;
        uint16_t times;

        uint32_t when;
        struct _IntervalCallback* prev;
        struct _IntervalCallback* next;
        void (*callback)(uint8_t, bool); // = 0 for unallocated
    } IntervalCallback;
    static IntervalCallback callbacksBuffer[MAX_CALLBACKS];
    static IntervalCallback* callbacks;
Each `IntervalCallback` instance represents a node in a doubly linked list. They are all stored within `callbacksBuffer`, with the first node pointed to by `callbacks`.<br />
This structure stores the information needed to call the system timer callbacks:
 - `uint8_t arg`: The argument to pass to the callback
 - `uint16_t ticks`: The number of system timer ticks between each call
 - `uint16_t times`: The number of times to call the callback. Decremented after each call unless it is `0`, where the callback will be called indefinitely
 - `uint32_t when`: The system tick counter that must be passed to call this callback. Incremented by `ticks` every callback call
 - `struct _IntervalCallback* prev/next`: Pointers to the previous/next nodes in the linked list. `0` if there is no more nodes in that direction
 - `void (*callback)(uint8_t, bool)`: The callback to call. `0` when the node is unallocated (used in the code for allocating a `IntervalCallback` from `callbacksBuffer`)


    typedef struct _DebounceCallback {
        void* timeout;
        void (*callback)(uint8_t);
    } DebounceCallback;
    static DebounceCallback debounceCallbacks[PCINT2_vect_num - INT0_vect_num + 1];
Simple structure holding the callback to call (`callback`) and the timeout used for debouncing an interrupt (`timeout`). `debounceCallbacks` contains a slot for one `DebounceCallback` per hardware interrupt.

Other state variables include:
 - `static uint32_t ticks`: The system tick counter. Gets incremented by one every 8 ms
 - `static void (*interrupts[_VECTORS_SIZE >> 2])(uint8_t)`: Callbacks for all the interrupts. One is available per interrupt

### `lib/circular-buffer`

    typedef struct _CircularBuffer {
        bool isOverwriteAllowed;
        bool isFull;
        uint8_t* dataStart;
        uint8_t* dataEnd;
        uint8_t* bufferStart;
        uint8_t* bufferEnd;
    } CircularBuffer;
 - `bool isOverwriteAllowed`: Whether old data overwriting is allowed or not in this circular buffer
 - `bool isFull`: Whether the buffer is full or not. Used to differentiate between the two `dataStart == dataEnd` states, one where the buffer is empty and one when full
 - `uint8_t* dataStart/dataEnd`: Pointers to the current start and end of the buffer. Wraps around at `bufferEnd` to `bufferStart`
 - `uint8_t* bufferStart/bufferEnd`: Pointers to the backing storage used for this buffer

### `lib/motor`
 - `static CircularBuffer rpsBuffer`: The circular buffer used to store the past four RPS values
 - `static uint8_t rpsRawBuffer[RPS_SAMPLE_SIZE]`: The backing storage used for the above circular buffer
 - `static uint8_t targetRps`: The target RPS the code attempts to reach
 - `static uint16_t topDutyCycle/bottomDutyCycle`: The top and button duty cycles used in the binary search to find the correct duty cycle

### `project/main`
Three `enum`s are used to represent microwave state.

    static enum {
        MODE_ENTRY,
        MODE_POWER_SELECT,
        MODE_RUNNING,
        MODE_PAUSED,
        MODE_FINISHED
    } currentMode;
Current microwave mode. Modifies how inputs are interpreted.

    static enum {
        DOOR_CLOSED,
        DOOR_OPENED
    } currentDoorState;
Current door state. All input is ignored if it is `DOOR_OPENED`.

    typedef enum _PowerSetting {
        POWER_MAX,
        POWER_HALF,
        POWER_QUARTER,
        POWER_OFF
    } PowerSetting;
    static PowerSetting currentPowerSetting;
The currently configured magnetron power level.

### `project/display`
 - `static bool isDimmingEnabled`: Configures whether `displayActivate()` will set a new backlight dim timeout

### `project/timer`

    static struct {
        uint8_t minutes;
        uint8_t seconds;
    } currentTimer;
The current timer value in minutes and seconds.

    static uint8_t inputBuffer[4];
    static uint8_t enteredDigits;
The digits inputted to the timer.

### `project/turntable`
Two `enum`s are used to represent the turntable state.

    static enum {
        TURNTABLE_ZERO,
        TURNTABLE_FIFTY,
        TURNTABLE_ONE_HUNDRED,
        TURNTABLE_ONE_HUNDRED_AND_FIFTY,
        TURNTABLE_LOOP
    } currentTurntablePosition;
The current turntable position in gradians, with `TURNTABLE_LOOP` signifying that it should be looped back to `TURNTABLE_ZERO`.

    static enum {
        TURNTABLE_ANTICLOCKWISE,
        TURNTABLE_CLOCKWISE
    } currentTurntableDirection;
The direction to spin the turntable.

## Algorithms
Only the "algorithms" that aren't simple case bashing or timer actions will be described.

### `lib/divmod`
The division algorithm used is binary long division, described by the [wikipedia article](http://en.wikipedia.org/wiki/Division_algorithm#Integer_division_.28unsigned.29_with_remainder).<br />
It is modified to take advantages of bit shifts and rotates rather using individual bit accesses.

Describing exactly how this algorithm works is outside the scope of this manual, but as an overview, it shifts the divisor one bit at a time from left to right under the dividend, and if the dividend is greater than the shifted divisor, it is subtracted by the shifted divisor and the corresponding bit in the quotient is set.

### `lib/events`
Two "algorithms" are used in this module: One for trasversing the timer callbacks linked list and calling its callbacks, and one for debouncing hardware interrupts.

#### Trasversing Timer Callbacks
The `onTick()` function is called every 8 ms, updates the system clock, and trasverses the timer callbacks linked list as follows:
 1. Load the pointer to the first `IntervalCallback` node into `buffer`
 2. If `buffer` is `0`, finish trasversal
 3. Check if the current system clock has passed the value in `buffer->when`
 4. If not, continue execution from (9)<br />
    If so, continue
 5. Save `buffer->callback`, `buffer->arg` and `buffer->times == 1` to local variables
 6. Increment `buffer->when` by `buffer->ticks`
 7. If `buffer->times` is 1, save `buffer->prev` to a temporary variable, deallocate the buffer, and set `buffer` to the temporary variable<br />
    Otherwise if `buffer->times` is not 0, decrement it
 8. Call the callback using the saved values from (5), as if it were `buffer->callback(buffer->arg, buffer->times == 1)`
 9. Load `buffer->next` into `buffer`
 10. Repeat from (2)

Callback buffers are checked and cleared if neccessary before the callback is called is the result of legacy code, where the callback buffer allocator would fail if more timer callbacks were added in the callback if this was not done.<br />
The bad callback buffer allocated has now been replaced with a better one, but this code has not been updated.

### Debouncing Hardware Interrupts
Hardware interrupts are debounced as follows:
 1. When a hardware interrupt is received, set a `debounceEnd()` to be called with a timeout of 30 ms
 2. If another hardware interrupt is received when the above timeout is still pending (i.e., 30 ms has not passed), reset it to 30 ms again
 3. When `debounceEnd()` is finally called, check if the input pin is still low. If it isn't, end execution
 4. Call the callback

Step (2) debounces any bouncy button pressing, while (3) is for preventing the callback being called again upon bouncy button releasing.

### `lib/lcd`
Only one "algorithm" is used in this module, and it is used for converting a number into a base-10 string to be displayed:
 1. Allocate a bottom-up stack of 6 bytes (Maximum 5 digits for 16 bits + terminating null)
 2. Push an initial null byte
 3. While the quotient is greater or equal to 10, divide it by 10 and push the remainder as an ASCII digit onto the stack
 4. Push the final quotient (which is now less than 10) as an ASCII digit onto the stack
 5. The pointer to the top of the stack is now a C string representing the base-10 value of the number

### `lib/motor`
Both binary and semi-linear search is combined to be used in finding the correct duty cycle for a target RPS value, and adjusting it dynamically if the load changes. It can be described as follows:
 - Upon a target RPS change:
    1. If the RPS change is greater than 50, take a linear estimate for the new correct duty cycle and set the current duty cycle to it
    2. Reset `topDutyCycle` and `bottomDutyCycle` to equal the current duty cycle.
 - `stepInterval` starts with an initial value of 1%
 - The following cases are checked every 250 ms:
    - If the current RPS is equal to the target RPS, do nothing
    - If the current RPS is less than the target RPS
       - If `topDutyCycle` is equal to the current duty cycle
          1. Set `bottomDutyCycle` to the current duty cycle
          2. Increment `topDutyCycle` by `stepInterval` but clamp it to a maximum of 100%
          3. Double `stepInterval` but clamp it to a maximum of 10%
          4. Set the current duty cycle to `topDutyCycle`
       - Otherwise
          1. Set `stepInterval` to 1%
          2. Perform a binary search between `topDutyCycle` and `bottomDutyCycle`
    - Otherwise
       - If `bottomDutyCycle` is equal to the current duty cycle
          1. Set `topDutyCycle` to the current duty cycle
          2. Decrement `bottomDutyCycle` by `stepInterval` but clamp it to a minimum of 0%
          3. Double `stepInterval` but clamp it to a maximum of 10%
          4. Set the current duty cycle to `bottomDutyCycle`
       - Otherwise
          1. Set `stepInterval` to 1%
          2. Perform a binary search between `topDutyCycle` and `bottomDutyCycle`

The above algorithm allows the current duty cycle to quickly converge to the correct duty cycle, while avoiding large jumps in speed when the target RPS is only changed by a small amount.

### `project/timer`
The "algorithm" used here is simply slightly more complex case bashing for normalising and clamping the timer value when doing timer arithmetic:
 1. Calculate the new seconds place as a signed integer
 2. Check if the seconds to be added is positive and if the new seconds is negative
    - If so, it means the new seconds overflowed, so set it to 99
 3. Perform the following case checks:
    - `newSeconds >= 60 && currentTimer.minutes == 99 && newSeconds > 99`
       - Seconds overflowed, but minutes place is already 99, so set the new seconds to 99 (Clamping maximum timer value to 99:99)
    - `newSeconds >= 60 && currentTimer.minutes != 99`
       - Seconds overflowed, and minutes place is not 99, so subtract 60 from the seconds and increment the minutes place (Normalising the timer for addition)
    - `newSeconds < 0 && currentTimer.minutes == 0`
       - Seconds underflowed, but minutes place is already 0, so set the new seconds too 0 (Clamping minimum timer value to 00:00)
    - `newSeconds < 0 && currentTimer.minutes != 0`
       - Seconds underflowed, and minutes place is not 0, so add 60 to the seconds and decrement the minutes place (Normalising the timer for subtraction)

The above algorithm will clamp the timer value to `[00:00, 99:99]`, and also normalise it so that the seconds place is never >=60 except when minutes is 99.
