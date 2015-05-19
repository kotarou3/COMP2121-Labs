#ifdef ALL_ASSEMBLY
    #error Including C source when ALL_ASSEMBLY is set
#endif

#include "circular-buffer.h"

static inline uint8_t* incrementPointer(CircularBuffer* buffer, uint8_t* p) {
    ++p;
    if (p == buffer->bufferEnd)
        p = buffer->bufferStart;
    return p;
}

void CircularBuffer_init(CircularBuffer* buffer, uint8_t* rawBuffer, uint16_t rawBufferSize, bool isOverwriteAllowed) {
    buffer->isOverwriteAllowed = isOverwriteAllowed;
    buffer->isFull = false;
    buffer->bufferStart = rawBuffer;
    buffer->bufferEnd = rawBuffer + rawBufferSize;
    buffer->dataStart = buffer->dataEnd = rawBuffer;
}

uint16_t CircularBuffer_size(CircularBuffer* buffer) {
    if (buffer->isFull)
        return buffer->bufferEnd - buffer->bufferStart;
    else if (buffer->dataEnd >= buffer->dataStart)
        return buffer->dataEnd - buffer->dataStart;
    else
        return (buffer->bufferEnd - buffer->dataStart) + (buffer->dataEnd - buffer->bufferStart);
}

bool CircularBuffer_isEmpty(CircularBuffer* buffer) {
    return buffer->dataStart == buffer->dataEnd && !buffer->isFull;
}

void CircularBuffer_clear(CircularBuffer* buffer) {
    buffer->dataStart = buffer->dataEnd = buffer->bufferStart;
    buffer->isFull = false;
}

void CircularBuffer_pushBack(CircularBuffer* buffer, uint8_t data) {
    if (buffer->isFull && !buffer->isOverwriteAllowed)
        return;

    *buffer->dataEnd = data;
    buffer->dataEnd = incrementPointer(buffer, buffer->dataEnd);

    if (buffer->isFull)
        buffer->dataStart = incrementPointer(buffer, buffer->dataStart);
    else if (buffer->dataEnd == buffer->dataStart)
        buffer->isFull = true;
}

uint8_t CircularBuffer_popFront(CircularBuffer* buffer) {
    uint8_t result = *buffer->dataStart;
    buffer->dataStart = incrementPointer(buffer, buffer->dataStart);
    buffer->isFull = false;
    return result;
}

uint8_t CircularBuffer_top(CircularBuffer* buffer) {
    return *buffer->dataStart;
}
