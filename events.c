#ifdef ALL_ASSEMBLY
    #error Including C source when ALL_ASSEMBLY is set
#endif

#include <avr/interrupt.h>
#include <avr/sleep.h>
#include <avr/wdt.h>

#include "events.h"

#define MAX_CALLBACKS 100
#define MILLISECONDS_TO_TICKS(a) (((a) + 7) >> 3) // 8 ticks per millisecond for 16 Hz
#define DEBOUNCE_TIME 30

typedef struct _IntervalCallback {
    uint8_t arg;
    uint16_t ticks;
    uint16_t times;

    uint32_t when;
    struct _IntervalCallback* prev;
    struct _IntervalCallback* next;
    void (*callback)(uint8_t, bool);
} IntervalCallback;

typedef struct _DebounceCallback {
    void* timeout;
    void (*callback)(uint8_t);
} DebounceCallback;

static IntervalCallback callbacksBuffer[MAX_CALLBACKS];
static IntervalCallback* callbacksBufferTop;

static uint32_t ticks;
static IntervalCallback* callbacks;

/*static*/ void (*interrupts[_VECTORS_SIZE >> 2])(uint8_t); // events.S needs access, so not static
static DebounceCallback debounceCallbacks[PCINT2_vect_num - INT0_vect_num + 1];

void* setTimeout(void (*callback)(uint8_t), uint8_t arg, uint16_t milliseconds) {
    return setIntervalWithDelay((void (*)(uint8_t, bool))callback, arg, 0, milliseconds, 1);
}
void* setInterval(void (*callback)(uint8_t, bool), uint8_t arg, uint16_t milliseconds, uint16_t times) {
    return setIntervalWithDelay(callback, arg, 0, milliseconds, times);
}

void* setIntervalWithDelay(void (*callback)(uint8_t, bool), uint8_t arg, uint16_t delay, uint16_t milliseconds, uint16_t times) {
    // Deallocate any cleared buffers
    while (callbacksBufferTop > callbacksBuffer && callbacksBufferTop[-1].callback == 0)
        --callbacksBufferTop;

    // Abort if no more space
    if (callbacksBufferTop - callbacksBuffer >= MAX_CALLBACKS) {
        wdt_enable(WDTO_15MS);
        while (1)
            ;
    }

    IntervalCallback* buffer = callbacksBufferTop++;
    buffer->arg = arg;
    buffer->ticks = MILLISECONDS_TO_TICKS(milliseconds);
    buffer->times = times;
    buffer->when = ticks + MILLISECONDS_TO_TICKS(delay + milliseconds);
    buffer->callback = callback;

    buffer->prev = 0;
    if (callbacks) {
        buffer->next = callbacks;
        callbacks->prev = buffer;
    } else {
        buffer->next = 0;
    }
    callbacks = buffer;

    return buffer;
}

void clearInterval(void* interval) {
    IntervalCallback* buffer = interval;

    if (buffer->prev)
        buffer->prev->next = buffer->next;
    else
        callbacks = buffer->next;

    if (buffer->next)
        buffer->next->prev = buffer->prev;

    // Mark buffer for cleanup
    buffer->callback = 0;
}

void onInterrupt(uint8_t vectorNumber, void (*callback)(uint8_t)) {
    interrupts[vectorNumber] = callback;
}

static void debounceEnd(uint8_t vectorNumber) {
    bool isPinHigh = false;

    switch (vectorNumber) {
        case INT0_vect_num:
            isPinHigh = PIND & (1 << PD0);
            break;
        case INT1_vect_num:
            isPinHigh = PIND & (1 << PD1);
            break;
        case INT2_vect_num:
            isPinHigh = PIND & (1 << PD2);
            break;
        case INT3_vect_num:
            isPinHigh = PIND & (1 << PD3);
            break;
        case INT4_vect_num:
            isPinHigh = PINE & (1 << PE4);
            break;
        case INT5_vect_num:
            isPinHigh = PINE & (1 << PE5);
            break;
        case INT6_vect_num:
            isPinHigh = PINE & (1 << PE6);
            break;
        case INT7_vect_num:
            isPinHigh = PINE & (1 << PE7);
            break;
        case PCINT0_vect_num:
            isPinHigh = PINB == 0xff; // Only when all of the pins are high
            break;
        case PCINT1_vect_num:
            isPinHigh = (((PINJ & ~(1 << PJ7)) << 1) | (PINE & (1 << PE0))) == 0xff;
            break;
        case PCINT2_vect_num:
            isPinHigh = PINK == 0xff;
            break;
    }

    DebounceCallback* callbackInfo = &debounceCallbacks[vectorNumber - INT0_vect_num];
    callbackInfo->timeout = 0;

    if (!isPinHigh) // Is the button still held down?
        callbackInfo->callback(vectorNumber);
}

static void debounceStart(uint8_t vectorNumber) {
    DebounceCallback* callbackInfo = &debounceCallbacks[vectorNumber - INT0_vect_num];
    if (callbackInfo->timeout)
        clearTimeout(callbackInfo->timeout);
    callbackInfo->timeout = setTimeout(debounceEnd, vectorNumber, DEBOUNCE_TIME);
}

void onDebouncedInterrupt(uint8_t vectorNumber, void (*callback)(uint8_t)) {
    DebounceCallback* callbackInfo = &debounceCallbacks[vectorNumber - INT0_vect_num];
    callbackInfo->timeout = 0;
    callbackInfo->callback = callback;
    onInterrupt(vectorNumber, debounceStart);
}

void busyWait(uint8_t milliseconds) {
    uint16_t target = TCNT5 + MILLISECONDS_TO_TICKS((uint16_t)milliseconds * 125);
    while (target != TCNT5)
        ;
}

static void onTick() {
    while (TCNT5 >= 125) {
        TCNT5 -= 125;
        ++ticks;
    }

    for (IntervalCallback* buffer = callbacks; buffer; buffer = buffer->next)
        if (ticks >= buffer->when) {
            void (*callback)(uint8_t, bool) = buffer->callback;
            uint8_t arg = buffer->arg;
            bool isLastTime = buffer->times == 1;

            buffer->when += buffer->ticks;
            if (isLastTime) {
                // Clear callback first to not run out of callback buffer memory if setIntervalWithDelay() is called
                IntervalCallback* prev = buffer->prev;
                clearInterval(buffer);
                buffer = prev;
            } else if (buffer->times > 0) {
                --buffer->times;
            }

            callback(arg, isLastTime);

            if (!buffer)
                break;
        }
}

static void unhandledInterrupt(uint8_t vectorNum) {
    PORTC = vectorNum;
}

void setup();
/*static*/ void start() { // events.S needs access, so not static
    // Clear RAM
    for (uint8_t* b = (uint8_t*)0x200; b < (uint8_t*)RAMEND; ++b)
        *b = 0;

    callbacksBufferTop = callbacksBuffer;
    for (uint8_t i = 0; i < (_VECTORS_SIZE >> 2); ++i)
        interrupts[i] = unhandledInterrupt;

    // Setup Timer5 to interrupt every 1024 * 125 cycles
    TCCR5B = (1 << CS52) | (1 << CS50);
    OCR5A = 125;
    TIMSK5 = (1 << OCIE5A);
    onInterrupt(TIMER5_COMPA_vect_num, (void (*)(uint8_t))onTick);

    setup();

    set_sleep_mode(SLEEP_MODE_IDLE);
    sei();
    while (1)
        sleep_cpu();
}
