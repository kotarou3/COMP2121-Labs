#include <avr/io.h>
#include "util.h"

    .section .vectors
.org 0
    rjmp _start
    nop

.set currentVectorNum, 1
.rept (_VECTORS_SIZE >> 2) - 1
    ldi r24, currentVectorNum << 1
    rjmp _emitInterrupt
    .set currentVectorNum, currentVectorNum + 1
.endr

    .section .text
_start:
    cli

    clr r1

    ldi r24, (1 << WDCE) | (1 << WDE)
    wdr
    sts _SFR_MEM_ADDR(WDTCSR), r24
    sts _SFR_MEM_ADDR(WDTCSR), r1

    ldi r24, lo8(RAMEND)
    out _SFR_IO_ADDR(SPL), r24
    ldi r24, hi8(RAMEND)
    out _SFR_IO_ADDR(SPH), r24

    out _SFR_IO_ADDR(RAMPZ), r1
    out _SFR_IO_ADDR(EIND), r1

    jmp start

_emitInterrupt:
    ldi YL, lo8(interrupts)
    ldi YH, hi8(interrupts)
    add YL, r24
    adc YH, r1
    ld ZL, Y
    ldd ZH, Y + 1

    lsr r24
    eicall

    reti

#ifndef ALL_ASSEMBLY

// GCC needs these for jump tables
    .global __tablejump2__
__tablejump2__:
    lsl ZL
    rol ZH
    .global __tablejump__
__tablejump__:
    lpm r0, Z+
    lpm ZH, Z
    mov ZL, r0
    ijmp

#else

#include "events.h"

#define MAX_CALLBACKS 100
#define DEBOUNCE_TIME 30

/*
typedef struct _IntervalCallback {
    uint8_t arg;
    uint16_t ticks;
    uint16_t times;

    uint32_t when;
    struct _IntervalCallback* prev;
    struct _IntervalCallback* next;
    void (*callback)(uint8_t, bool);
} IntervalCallback;
*/
#define IntervalCallback_arg 0
#define IntervalCallback_ticks (IntervalCallback_arg + 1)
#define IntervalCallback_times (IntervalCallback_ticks + 2)

#define IntervalCallback_when (IntervalCallback_times + 2)
#define IntervalCallback_prev (IntervalCallback_when + 4)
#define IntervalCallback_next (IntervalCallback_prev + 2)
#define IntervalCallback_callback (IntervalCallback_next + 2)
#define sizeof_IntervalCallback (IntervalCallback_callback + 2)

/*
typedef struct _DebounceCallback {
    void* timeout;
    void (*callback)(uint8_t);
} DebounceCallback;
*/
#define DebounceCallback_timeout 0
#define DebounceCallback_callback (DebounceCallback_timeout + 2)
#define sizeof_DebounceCallback (DebounceCallback_callback + 2)

// static IntervalCallback callbacksBuffer[MAX_CALLBACKS];
.lcomm callbacksBuffer, sizeof_IntervalCallback * MAX_CALLBACKS
// static IntervalCallback* callbacksBufferTop;
.lcomm callbacksBufferTop, 2

// static uint32_t ticks;
.lcomm ticks, 4
// static IntervalCallback* callbacks;
.lcomm callbacks, 2
// static void (*interrupts[_VECTORS_SIZE >> 2])(uint8_t);
.lcomm interrupts, 2 * (_VECTORS_SIZE >> 2)
// static DebounceCallback debounceCallbacks[PCINT2_vect_num - INT0_vect_num + 1];
.lcomm debounceCallbacks, sizeof_DebounceCallback * (PCINT2_vect_num - INT0_vect_num + 1)

// void* setTimeout(void (*callback)(uint8_t), uint8_t arg, uint16_t milliseconds) {
    .global setTimeout
setTimeout:
    push r16
    push r17

    // return setIntervalWithDelay((void (*)(uint8_t, bool))callback, arg, 0, milliseconds, 1);
    movw r18, r20
    ldi r16, lo8(1)
    ldi r17, hi8(1)
    ldi r20, lo8(0)
    ldi r21, hi8(0)
    call setIntervalWithDelay

    pop r17
    pop r16
    ret
// }

// void* setInterval(void (*callback)(uint8_t, bool), uint8_t arg, uint16_t milliseconds, uint16_t times) {
    .global setInterval
setInterval:
    push r16
    push r17

    // return setIntervalWithDelay(callback, arg, 0, milliseconds, times);
    movw r16, r18
    movw r18, r20
    ldi r20, lo8(0)
    ldi r21, hi8(0)
    call setIntervalWithDelay

    pop r17
    pop r16
    ret
// }

// void* setIntervalWithDelay(void (*callback)(uint8_t, bool), uint8_t arg, uint16_t delay, uint16_t milliseconds, uint16_t times) {
    .global setIntervalWithDelay
setIntervalWithDelay: // r25:r24: callback, r22: arg, r21:r20: delay, r19:r18: milliseconds, r17:r16: times
    push YL
    push YH

    // Deallocate any cleared buffers
    lds XL, callbacksBufferTop
    lds XH, callbacksBufferTop + 1
    ldi r23, hi8(callbacksBuffer)
    // while (callbacksBufferTop > callbacksBuffer && callbacksBufferTop[-1].callback == 0)
setIntervalWithDelay_deallocateClearedBuffers:
    cpi XL, lo8(callbacksBuffer)
    cpc XH, r23
    breq setIntervalWithDelay_deallocateClearedBuffers_end // callbacksBufferTop > callbacksBuffer &&

    movw YL, XL
    sbiw YL, sizeof_IntervalCallback
    ldd r30, Y + IntervalCallback_callback
    cp r30, r1
    ldd r30, Y + IntervalCallback_callback + 1
    cpc r30, r1
    brne setIntervalWithDelay_deallocateClearedBuffers_end // callbacksBufferTop[-1].callback == 0

    //    --callbacksBufferTop;
    movw XL, YL
    rjmp setIntervalWithDelay_deallocateClearedBuffers
setIntervalWithDelay_deallocateClearedBuffers_end:

    // Abort if no more space
    // if (callbacksBufferTop - callbacksBuffer >= MAX_CALLBACKS) {
    ldi r23, hi8(callbacksBuffer + MAX_CALLBACKS)
    cpi XL, lo8(callbacksBuffer + MAX_CALLBACKS)
    cpc XH, r23
    brlo setIntervalWithDelay_haveSpace

    //    wdt_enable(WDTO_15MS);
    //    while (1)
    //        ;
    ldi r23, (1 << WDCE) | (1 << WDE)
    sts _SFR_MEM_ADDR(WDTCSR), r23
    ldi r23, (1 << WDE)
    sts _SFR_MEM_ADDR(WDTCSR), r23
setIntervalWithDelay_abort:
    rjmp setIntervalWithDelay_abort

    // }
setIntervalWithDelay_haveSpace:
    // IntervalCallback* buffer = callbacksBufferTop++;
    movw YL, XL
    adiw XL, sizeof_IntervalCallback // At this point, Y is `buffer` and X is `callbacksBufferTop`
    sts callbacksBufferTop, XL
    sts callbacksBufferTop + 1, XH

    // buffer->arg = arg;
    std Y + IntervalCallback_arg, r22

    // #define MILLISECONDS_TO_TICKS(a) (((a) + 7) >> 3) // 8 ticks per millisecond for 16 Hz
    // buffer->ticks = MILLISECONDS_TO_TICKS(milliseconds);
    movw r22, r18
    subi r22, lo8(-7)
    sbci r23, hi8(-7)
    lsr r23
    ror r22
    lsr r23
    ror r22
    lsr r23
    ror r22
    std Y + IntervalCallback_ticks, r22
    std Y + IntervalCallback_ticks + 1, r23

    // buffer->times = times;
    std Y + IntervalCallback_times, r16
    std Y + IntervalCallback_times + 1, r17

    // buffer->when = MILLISECONDS_TO_TICKS(delay + milliseconds);
    add r18, r20
    adc r19, r21
    subi r18, lo8(-7)
    sbci r19, hi8(-7)
    lsr r19
    ror r18
    lsr r19
    ror r18
    lsr r19
    ror r18
    lds r20, ticks
    lds r21, ticks + 1
    lds r22, ticks + 2
    lds r23, ticks + 3
    add r20, r18
    adc r21, r19
    adc r22, r1
    adc r23, r1
    std Y + IntervalCallback_when, r20
    std Y + IntervalCallback_when + 1, r21
    std Y + IntervalCallback_when + 2, r22
    std Y + IntervalCallback_when + 3, r23

    // buffer->callback = callback;
    std Y + IntervalCallback_callback, r24
    std Y + IntervalCallback_callback + 1, r25

    // buffer->prev = 0;
    std Y + IntervalCallback_prev, r1
    std Y + IntervalCallback_prev + 1, r1

    // if (callbacks) {
    lds ZL, callbacks
    lds ZH, callbacks + 1
    sbiw ZL, 0
    breq setIntervalWithDelay_noExistingCallbacks

    //     buffer->next = callbacks;
    std Y + IntervalCallback_next, ZL
    std Y + IntervalCallback_next + 1, ZH
    //     callbacks->prev = buffer;
    std Z + IntervalCallback_prev, YL
    std Z + IntervalCallback_prev + 1, YH

    rjmp setIntervalWithDelay_pushCallback_end
    // } else {
setIntervalWithDelay_noExistingCallbacks:
    //     buffer->next = 0;
    std Y + IntervalCallback_next, r1
    std Y + IntervalCallback_next + 1, r1

    // }
setIntervalWithDelay_pushCallback_end:
    // callbacks = buffer;
    sts callbacks, YL
    sts callbacks + 1, YH

    // return buffer;
    movw r24, YL

    pop YH
    pop YL
    ret
// }

// void clearInterval(void* interval) {
    .global clearInterval
clearInterval:
    push YL
    push YH

    // IntervalCallback* buffer = interval;
    movw YL, r24

    ldd ZL, Y + IntervalCallback_prev
    ldd ZH, Y + IntervalCallback_prev + 1
    ldd XL, Y + IntervalCallback_next
    ldd XH, Y + IntervalCallback_next + 1
    // if (buffer->prev)
    sbiw ZL, 0
    breq clearInterval_noPreviousCallback

    //     buffer->prev->next = buffer->next;
    std Z + IntervalCallback_next, XL
    std Z + IntervalCallback_next + 1, XH
    rjmp clearInterval_updatePreviousCallback_end

    // else
clearInterval_noPreviousCallback:
    //     callbacks = buffer->next;
    sts callbacks, XL
    sts callbacks + 1, XH

clearInterval_updatePreviousCallback_end:
    // if (buffer->next)
    sbiw XL, 0
    breq clearInterval_noNextCallback

    //     buffer->next->prev = buffer->prev;
    adiw XL, IntervalCallback_prev
    st X+, ZL
    st X, ZH

clearInterval_noNextCallback:
    // Mark buffer for cleanup
    // buffer->callback = 0;
    std Y + IntervalCallback_callback, r1
    std Y + IntervalCallback_callback + 1, r1

    pop YH
    pop YL
    ret
// }

// void onInterrupt(uint8_t vectorNumber, void (*callback)(uint8_t)) {
    .global onInterrupt
onInterrupt:
    // interrupts[vectorNumber] = callback;
    mov ZL, r24
    ldi ZH, 0
    lsl ZL
    rol ZH
    subi ZL, lo8(-(interrupts))
    sbci ZH, hi8(-(interrupts))
    std Z + 0, r22
    std Z + 1, r23
    ret
// }

// static void debounceEnd(uint8_t vectorNumber) {
debounceEnd:

    // bool isPinHigh = false;
    clr r25

    // switch (vectorNumber) {
    mov ZL, r24
    lsl ZL
    clr ZH
    subi ZL, lo8(-(debounceEnd_switch_jumptable - INT0_vect_num * 2))
    sbci ZH, hi8(-(debounceEnd_switch_jumptable - INT0_vect_num * 2))
    lpm r0, Z+
    lpm ZH, Z
    mov ZL, r0
    eijmp

debounceEnd_switch_jumptable:
    .word gs(debounceEnd_switch_case_int0)
    .word gs(debounceEnd_switch_case_int1)
    .word gs(debounceEnd_switch_case_int2)
    .word gs(debounceEnd_switch_case_int3)
    .word gs(debounceEnd_switch_case_int4)
    .word gs(debounceEnd_switch_case_int5)
    .word gs(debounceEnd_switch_case_int6)
    .word gs(debounceEnd_switch_case_int7)
    .word gs(debounceEnd_switch_case_pcint0)
    .word gs(debounceEnd_switch_case_pcint1)
    .word gs(debounceEnd_switch_case_pcint2)

    //     case INT0_vect_num:
debounceEnd_switch_case_int0:
    //         isPinHigh = PIND & (1 << PD0);
    //         break;
    in r25, _SFR_IO_ADDR(PIND)
    andi r25, 1 << PD0
    rjmp debounceEnd_switch_end

    //     case INT1_vect_num:
debounceEnd_switch_case_int1:
    //         isPinHigh = PIND & (1 << PD1);
    //         break;
    in r25, _SFR_IO_ADDR(PIND)
    andi r25, 1 << PD1
    rjmp debounceEnd_switch_end

    //     case INT2_vect_num:
debounceEnd_switch_case_int2:
    //         isPinHigh = PIND & (1 << PD2);
    //         break;
    in r25, _SFR_IO_ADDR(PIND)
    andi r25, 1 << PD2
    rjmp debounceEnd_switch_end

    //     case INT3_vect_num:
debounceEnd_switch_case_int3:
    //         isPinHigh = PIND & (1 << PD3);
    //         break;
    in r25, _SFR_IO_ADDR(PIND)
    andi r25, 1 << PD3
    rjmp debounceEnd_switch_end

    //     case INT4_vect_num:
debounceEnd_switch_case_int4:
    //         isPinHigh = PINE & (1 << PE4);
    //         break;
    in r25, _SFR_IO_ADDR(PINE)
    andi r25, 1 << PE4
    rjmp debounceEnd_switch_end

    //     case INT5_vect_num:
debounceEnd_switch_case_int5:
    //         isPinHigh = PINE & (1 << PE5);
    //         break;
    in r25, _SFR_IO_ADDR(PINE)
    andi r25, 1 << PE5
    rjmp debounceEnd_switch_end

    //     case INT6_vect_num:
debounceEnd_switch_case_int6:
    //         isPinHigh = PINE & (1 << PE6);
    //         break;
    in r25, _SFR_IO_ADDR(PINE)
    andi r25, 1 << PE6
    rjmp debounceEnd_switch_end

    //     case INT7_vect_num:
debounceEnd_switch_case_int7:
    //         isPinHigh = PINE & (1 << PE7);
    //         break;
    in r25, _SFR_IO_ADDR(PINE)
    andi r25, 1 << PE7
    rjmp debounceEnd_switch_end

    //     case PCINT0_vect_num:
debounceEnd_switch_case_pcint0:
    //         isPinHigh = PINB == 0xff; // Only when all of the pins are high
    //         break;
    in r22, _SFR_IO_ADDR(PINB)
    cpi r22, 0xff
    skipIf ne
    inc r25
    rjmp debounceEnd_switch_end

    //     case PCINT1_vect_num:
debounceEnd_switch_case_pcint1:
    //         isPinHigh = (((PINJ & ~(1 << PJ7)) << 1) | (PINE & (1 << PE0))) == 0xff;
    //         break;
    lds r22, _SFR_MEM_ADDR(PINJ)
    andi r22, ~(1 << PJ7)
    lsl r22
    in r23, _SFR_IO_ADDR(PINE)
    andi r23, 1 << PE0
    or r22, r23
    cpi r22, 0xff
    inc r25
    rjmp debounceEnd_switch_end

    //     case PCINT2_vect_num:
debounceEnd_switch_case_pcint2:
    //         isPinHigh = PINK == 0xff;
    //         break;
    lds r22, _SFR_MEM_ADDR(PINK)
    cpi r22, 0xff
    skipIf ne
    inc r25

    // }
debounceEnd_switch_end:

    // DebounceCallback* callbackInfo = &debounceCallbacks[vectorNumber - INT0_vect_num];
    mov ZL, r24
    clr ZH
    lsl ZL
    rol ZH
    lsl ZL
    rol ZH
    subi ZL, lo8(-(debounceCallbacks - (INT0_vect_num * 4)))
    sbci ZH, hi8(-(debounceCallbacks - (INT0_vect_num * 4)))

    // callbackInfo->timeout = 0;
    std Z + DebounceCallback_timeout, r1
    std Z + DebounceCallback_timeout + 1, r1

    // if (!isPinHigh) // Is the button still held down?
    tst r25
    brnz debounceEnd_end

    //     callbackInfo->callback(vectorNumber);
    ldd r0, Z + DebounceCallback_callback
    ldd ZH, Z + DebounceCallback_callback + 1
    mov ZL, r0
    eijmp

debounceEnd_end:
    ret
// }

// static void debounceStart(uint8_t vectorNumber) {
debounceStart:
    push r16
    push YL
    push YH
    mov r16, r24

    // DebounceCallback* callbackInfo = &debounceCallbacks[vectorNumber - INT0_vect_num];
    mov YL, r24
    clr YH
    lsl YL
    rol YH
    lsl YL
    rol YH
    subi YL, lo8(-(debounceCallbacks - (INT0_vect_num * 4)))
    sbci YH, hi8(-(debounceCallbacks - (INT0_vect_num * 4)))

    // if (callbackInfo->timeout)
    ldd r24, Y + DebounceCallback_timeout
    ldd r25, Y + DebounceCallback_timeout + 1
    sbiw r24, 0
    breq debounceStart_noExistingDebounce

    //     clearTimeout(callbackInfo->timeout);
    call clearTimeout

debounceStart_noExistingDebounce:
    // callbackInfo->timeout = setTimeout(debounceEnd, vectorNumber, DEBOUNCE_TIME);
    ldi r20, lo8(DEBOUNCE_TIME)
    ldi r21, hi8(DEBOUNCE_TIME)
    mov r22, r16
    ldi r24, lo8(gs(debounceEnd))
    ldi r25, hi8(gs(debounceEnd))
    call setTimeout
    std Y + DebounceCallback_timeout, r24
    std Y + DebounceCallback_timeout + 1, r25

    pop YH
    pop YL
    pop r16
    ret
// }

// void onDebouncedInterrupt(uint8_t vectorNumber, void (*callback)(uint8_t)) {
    .global onDebouncedInterrupt
onDebouncedInterrupt:

    // DebounceCallback* callbackInfo = &debounceCallbacks[vectorNumber - INT0_vect_num];
    mov ZL, r24
    clr ZH
    lsl ZL
    rol ZH
    lsl ZL
    rol ZH
    subi ZL, lo8(-(debounceCallbacks - (INT0_vect_num * 4)))
    sbci ZH, hi8(-(debounceCallbacks - (INT0_vect_num * 4)))

    // callbackInfo->timeout = 0;
    std Z + DebounceCallback_timeout, r1
    std Z + DebounceCallback_timeout + 1, r1

    // callbackInfo->callback = callback;
    std Z + DebounceCallback_callback, r22
    std Z + DebounceCallback_callback + 1, r23

    // onInterrupt(vectorNumber, debounceStart);
    ldi r22, lo8(gs(debounceStart))
    ldi r23, hi8(gs(debounceStart))
    jmp onInterrupt
// }

// void busyWait(uint8_t milliseconds) {
    .global busyWait
busyWait:

    // #define MILLISECONDS_TO_TICKS(a) (((a) + 7) >> 3) // 8 ticks per millisecond for 16 Hz
    // uint16_t target = TCNT5 + MILLISECONDS_TO_TICKS((uint16_t)milliseconds * 125);
    lds r22, _SFR_MEM_ADDR(TCNT5L)
    lds r23, _SFR_MEM_ADDR(TCNT5H)
    ldi r20, 125
    mul r24, r20
    movw r24, r0
    clr r1
    adiw r24, 7
    lsr r25
    ror r24
    lsr r25
    ror r24
    lsr r25
    ror r24
    add r24, r22
    adc r25, r23

    // while (target != TCNT5)
    //     ;
busyWait_wait:
    lds r22, _SFR_MEM_ADDR(TCNT5L)
    lds r23, _SFR_MEM_ADDR(TCNT5H)
    cp r24, r22
    cpc r25, r23
    brne busyWait_wait

    ret
// }

// static void onTick() {
onTick:
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15
    push r16
    push r17
    push YL
    push YH

    lds r16, ticks
    lds r17, ticks + 1
    lds r18, ticks + 2
    lds r19, ticks + 3
    // while (TCNT5 >= 125) {
onTick_clearTickCounter_start:
    lds r20, _SFR_MEM_ADDR(TCNT5L)
    lds r21, _SFR_MEM_ADDR(TCNT5H)
    subi r20, 125
    sbc r21, r1
    brlo onTick_clearTickCounter_end

    //     TCNT5 -= 125;
    sts _SFR_MEM_ADDR(TCNT5H), r21
    sts _SFR_MEM_ADDR(TCNT5L), r20

    //     ++ticks;
    subi r16, lo8(-1)
    sbci r17, hi8(-1)
    sbci r18, hlo8(-1)
    sbci r19, hhi8(-1)

    rjmp onTick_clearTickCounter_start
    // }
onTick_clearTickCounter_end:
    sts ticks, r16
    sts ticks + 1, r17
    sts ticks + 2, r18
    sts ticks + 3, r19
    movw r14, r18

    lds YL, callbacks
    lds YH, callbacks + 1
    // for (IntervalCallback* buffer = callbacks; buffer; buffer = buffer->next)
onTick_iterateCallbacks_start:
    sbiw YL, 0
    skip2If ne
    jmp onTick_end

    //     if (ticks >= buffer->when) {
    ldd r18, Y + IntervalCallback_when
    ldd r19, Y + IntervalCallback_when + 1
    ldd r20, Y + IntervalCallback_when + 2
    ldd r21, Y + IntervalCallback_when + 3
    cp r16, r18
    cpc r17, r19
    cpc r14, r20
    cpc r15, r21
    brlo onTick_iterateCallbacks_next

    //         buffer->when += buffer->ticks;
    ldd r26, Y + IntervalCallback_ticks
    ldd r27, Y + IntervalCallback_ticks + 1
    add r18, r26
    adc r19, r27
    adc r20, r1
    adc r21, r1
    std Y + IntervalCallback_when, r18
    std Y + IntervalCallback_when + 1, r19
    std Y + IntervalCallback_when + 2, r20
    std Y + IntervalCallback_when + 3, r21

    //         void (*callback)(uint8_t, bool) = buffer->callback;
    ldd r12, Y + IntervalCallback_callback
    ldd r13, Y + IntervalCallback_callback + 1

    //         uint8_t arg = buffer->arg;
    ldd r10, Y + IntervalCallback_arg

    //         bool isLastTime = buffer->times == 1;
    ldd r24, Y + IntervalCallback_times
    ldd r25, Y + IntervalCallback_times + 1
    clr r11
    cpi r24, 1
    cpc r25, r1
    skipIf ne
    inc r11

    //         if (isLastTime) {
    tst r11
    brz onTick_iterateCallbacks_notLastTime

    //             // Clear callback first to not run out of callback buffer memory if setIntervalWithDelay() is called
    //             IntervalCallback* prev = buffer->prev;
    ldd r22, Y + IntervalCallback_prev
    ldd r23, Y + IntervalCallback_prev + 1

    //             clearInterval(buffer);
    //             buffer = prev;
    movw r24, YL
    movw YL, r22
    call clearInterval
    rjmp onTick_iterateCallbacks_checkLastTime_end

    //         } else if (buffer->times > 0) {
onTick_iterateCallbacks_notLastTime:
    cp r24, r1
    cpc r25, r1
    breq onTick_iterateCallbacks_checkLastTime_end

    //             --buffer->times;
    sbiw r24, 1
    std Y + IntervalCallback_times, r24
    std Y + IntervalCallback_times + 1, r25

    //         }
onTick_iterateCallbacks_checkLastTime_end:

    //         callback(arg, isLastTime);
    mov r24, r10
    mov r22, r11
    movw ZL, r12
    eicall

    //         if (!buffer)
    //             break;
    sbiw YL, 0
    breq onTick_end

    //     }
onTick_iterateCallbacks_next: // (buffer = buffer->next)
    ldd r0, Y + IntervalCallback_next
    ldd YH, Y + IntervalCallback_next + 1
    mov YL, r0
    rjmp onTick_iterateCallbacks_start

onTick_end:
    pop YH
    pop YL
    pop r17
    pop r16
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    ret
// }

// static void unhandledInterrupt(uint8_t vectorNum) {
unhandledInterrupt:
    // PORTC = vectorNum;
    out _SFR_IO_ADDR(PORTC), r24
    ret
// }

// static void start() {
start:

    // Clear RAM
    // for (uint8_t* b = (uint8_t*)0x200; b < (uint8_t*)RAMEND; ++b)
    //     *b = 0;
    ldi ZL, lo8(0x200)
    ldi ZH, hi8(0x200)
    ldi r24, hi8(RAMEND)
start_clearRam_start:
    st Z+, r1
    cpi ZL, lo8(RAMEND)
    cpc ZH, r24
    brne start_clearRam_start

    // callbacksBufferTop = callbacksBuffer;
    ldi r24, lo8(callbacksBuffer)
    ldi r25, hi8(callbacksBuffer)
    sts callbacksBufferTop, r24
    sts callbacksBufferTop + 1, r25

    // for (uint8_t i = 0; i < (_VECTORS_SIZE >> 2); ++i)
    //     interrupts[i] = unhandledInterrupt;
    ldi ZL, lo8(interrupts)
    ldi ZH, hi8(interrupts)
    ldi r24, lo8(gs(unhandledInterrupt))
    ldi r25, hi8(gs(unhandledInterrupt))
    ldi r23, hi8(interrupts + 2 * (_VECTORS_SIZE >> 2))
start_setupUnhandledInterrupts_start:
    st Z+, r24
    st Z+, r25
    cpi ZL, lo8(interrupts + 2 * (_VECTORS_SIZE >> 2))
    cpc ZH, r23
    brne start_setupUnhandledInterrupts_start

    // Setup Timer5 to interrupt every 1024 * 125 cycles
    // TCCR5B = (1 << CS52) | (1 << CS50);
    ldi r24, (1 << CS52) | (1 << CS50)
    sts _SFR_MEM_ADDR(TCCR5B), r24

    // OCR5A = 125;
    ldi r24, 125
    sts _SFR_MEM_ADDR(OCR5AL), r24
    sts _SFR_MEM_ADDR(OCR5AH), r1

    // TIMSK5 = (1 << OCIE5A);
    ldi r24, (1 << OCIE5A)
    sts _SFR_MEM_ADDR(TIMSK5), r24

    // onInterrupt(TIMER5_COMPA_vect_num, (void (*)(uint8_t))onTick);
    ldi r22, lo8(gs(onTick))
    ldi r23, hi8(gs(onTick))
    ldi r24, TIMER5_COMPA_vect_num
    call onInterrupt

    // setup();
    call setup

    // set_sleep_mode(SLEEP_MODE_IDLE);
    ldi r24, (1 << SE)
    out _SFR_IO_ADDR(SMCR), r24

    // sei();
    sei

    // while (1)
    //     sleep_cpu();
start_sleep:
    sleep
    rjmp start_sleep
// }

#endif
