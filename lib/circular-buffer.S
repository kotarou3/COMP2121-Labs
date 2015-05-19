#include <avr/io.h>
#include "circular-buffer.h"
#include "util.h"

// static inline uint8_t* incrementPointer(CircularBuffer* buffer, uint8_t* p) {
.macro incrementPointer, buffer, pH, pL // `buffer` must be in `Y` or `Z`
//     ++p;
    adiw \pL, 1

//     if (p == buffer->bufferEnd)
//         p = buffer->bufferStart;
    ldd r0, \buffer + CircularBuffer_bufferEnd
    cp \pL, r0
    ldd r0, \buffer + CircularBuffer_bufferEnd + 1
    cpc \pH, r0
    skip2If ne
    ldd \pL, \buffer + CircularBuffer_bufferStart
    ldd \pH, \buffer + CircularBuffer_bufferStart + 1

//     return p;
.endm
// }

// void CircularBuffer_init(CircularBuffer* buffer, uint8_t* rawBuffer, uint16_t rawBufferSize, bool isOverwriteAllowed) {
    .global CircularBuffer_init
CircularBuffer_init: // r25:r24: buffer, r23:r22: rawBuffer, r21:r20: rawBufferSize, r18: isOverwriteAllowed
    movw ZL, r24

    // buffer->isOverwriteAllowed = isOverwriteAllowed;
    std Z + CircularBuffer_isOverwriteAllowed, r18

    // buffer->isFull = false;
    std Z + CircularBuffer_isFull, r1

    // buffer->bufferStart = rawBuffer;
    std Z + CircularBuffer_bufferStart, r22
    std Z + CircularBuffer_bufferStart + 1, r23

    // buffer->bufferEnd = rawBuffer + rawBufferSize;
    add r20, r22
    adc r21, r23
    std Z + CircularBuffer_bufferEnd, r20
    std Z + CircularBuffer_bufferEnd + 1, r21

    // buffer->dataStart = buffer->dataEnd = rawBuffer;
    std Z + CircularBuffer_dataEnd, r22
    std Z + CircularBuffer_dataEnd + 1, r23
    std Z + CircularBuffer_dataStart, r22
    std Z + CircularBuffer_dataStart + 1, r23

    ret
// }

// uint16_t CircularBuffer_size(CircularBuffer* buffer) {
    .global CircularBuffer_size
CircularBuffer_size:
    movw ZL, r24

    // if (buffer->isFull)
    ldd r24, Z + CircularBuffer_isFull
    tst r24
    brz CircularBuffer_size_notFull

    //     return buffer->bufferEnd - buffer->bufferStart;
    ldd r24, Z + CircularBuffer_bufferEnd
    ldd r25, Z + CircularBuffer_bufferEnd + 1
    ldd r22, Z + CircularBuffer_bufferStart
    ldd r23, Z + CircularBuffer_bufferStart + 1
    sub r24, r22
    sbc r25, r23
    ret

CircularBuffer_size_notFull:
    ldd r20, Z + CircularBuffer_dataStart
    ldd r21, Z + CircularBuffer_dataStart + 1
    ldd r18, Z + CircularBuffer_dataEnd
    ldd r19, Z + CircularBuffer_dataEnd + 1
    // else if (buffer->dataEnd >= buffer->dataStart)
    cp r18, r20
    cpc r19, r21
    brlo CircularBuffer_size_wrapped

    //     return buffer->dataEnd - buffer->dataStart;
    movw r24, r18
    sub r24, r20
    sbc r25, r21
    ret

    // else
CircularBuffer_size_wrapped:
    //     return (buffer->bufferEnd - buffer->dataStart) + (buffer->dataEnd - buffer->bufferStart);
    ldd r24, Z + CircularBuffer_bufferEnd
    ldd r25, Z + CircularBuffer_bufferEnd + 1
    sub r24, r20
    sbc r25, r21
    ldd r20, Z + CircularBuffer_bufferStart
    ldd r21, Z + CircularBuffer_bufferStart + 1
    sub r18, r20
    sbc r19, r21
    add r24, r18
    adc r25, r19
    ret
// }

// bool CircularBuffer_isEmpty(CircularBuffer* buffer) {
    .global CircularBuffer_isEmpty
CircularBuffer_isEmpty:
    movw ZL, r24

    // return buffer->dataStart == buffer->dataEnd && !buffer->isFull;
    clr r24
    ldd r20, Z + CircularBuffer_dataStart
    ldd r21, Z + CircularBuffer_dataStart + 1
    ldd r18, Z + CircularBuffer_dataEnd
    ldd r19, Z + CircularBuffer_dataEnd + 1
    cp r20, r18
    cpc r21, r19
    brne CircularBuffer_isEmpty_end
    ldd r24, Z + CircularBuffer_isFull
    ldi r25, 1
    eor r24, r25

CircularBuffer_isEmpty_end:
    ret
// }

// void CircularBuffer_clear(CircularBuffer* buffer) {
    .global CircularBuffer_clear
CircularBuffer_clear:
    movw ZL, r24

    // buffer->dataStart = buffer->dataEnd = buffer->bufferStart;
    ldd r24, Z + CircularBuffer_bufferStart
    ldd r25, Z + CircularBuffer_bufferStart + 1
    std Z + CircularBuffer_dataEnd, r24
    std Z + CircularBuffer_dataEnd + 1, r25
    std Z + CircularBuffer_dataStart, r24
    std Z + CircularBuffer_dataStart + 1, r25

    // buffer->isFull = false;
    std Z + CircularBuffer_isFull, r1

    ret
// }

// void CircularBuffer_pushBack(CircularBuffer* buffer, uint8_t data) {
    .global CircularBuffer_pushBack
CircularBuffer_pushBack:
    movw ZL, r24

    // if (buffer->isFull && !buffer->isOverwriteAllowed)
    //     return;
    ldd r20, Z + CircularBuffer_isFull
    tst r20
    brz CircularBuffer_pushBack_canWrite
    ldd r21, Z + CircularBuffer_isOverwriteAllowed
    tst r21
    brz CircularBuffer_pushBack_end

CircularBuffer_pushBack_canWrite:
    // *buffer->dataEnd = data;
    ldd XL, Z + CircularBuffer_dataEnd
    ldd XH, Z + CircularBuffer_dataEnd + 1
    st X, r22

    // buffer->dataEnd = incrementPointer(buffer, buffer->dataEnd);
    incrementPointer Z, XH, XL
    std Z + CircularBuffer_dataEnd, XL
    std Z + CircularBuffer_dataEnd + 1, XH

    ldd r24, Z + CircularBuffer_dataStart
    ldd r25, Z + CircularBuffer_dataStart + 1
    // if (buffer->isFull)
    tst r20
    brz CircularBuffer_pushBack_notAlreadyFull

    //     buffer->dataStart = incrementPointer(buffer, buffer->dataStart);
    incrementPointer Z, r25, r24
    std Z + CircularBuffer_dataStart, r24
    std Z + CircularBuffer_dataStart + 1, r25
    ret

CircularBuffer_pushBack_notAlreadyFull:
    // else if (buffer->dataEnd == buffer->dataStart)
    cp XL, r24
    cpc XH, r25
    brne CircularBuffer_pushBack_end

    //     buffer->isFull = true;
    ldi r24, 1
    std Z + CircularBuffer_isFull, r24

CircularBuffer_pushBack_end:
    ret
// }

// uint8_t CircularBuffer_popFront(CircularBuffer* buffer) {
    .global CircularBuffer_popFront
CircularBuffer_popFront:
    movw ZL, r24

    // uint8_t result = *buffer->dataStart;
    ldd XL, Z + CircularBuffer_dataStart
    ldd XH, Z + CircularBuffer_dataStart + 1
    ld r24, X

    // buffer->dataStart = incrementPointer(buffer, buffer->dataStart);
    incrementPointer Z, XH, XL
    std Z + CircularBuffer_dataStart, XL
    std Z + CircularBuffer_dataStart + 1, XH

    // buffer->isFull = false;
    std Z + CircularBuffer_isFull, r1

    // return result;
    ret
// }

// uint8_t CircularBuffer_top(CircularBuffer* buffer) {
    .global CircularBuffer_top
CircularBuffer_top:
    movw ZL, r24

    // return *buffer->dataStart;
    ldd XL, Z + CircularBuffer_dataStart
    ldd XH, Z + CircularBuffer_dataStart + 1
    ld r24, X
    ret
// }
