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
    buffer->bufferStart = rawBuffer;
    buffer->bufferEnd = rawBuffer + rawBufferSize;
    buffer->dataStart = buffer->dataEnd = rawBuffer;
}

uint16_t CircularBuffer_size(CircularBuffer* buffer) {
    if (buffer->dataEnd >= buffer->dataStart)
        return buffer->dataEnd - buffer->dataStart;
    else
        return (buffer->bufferEnd - buffer->dataStart) + (buffer->dataEnd - buffer->bufferStart);
}

bool CircularBuffer_isEmpty(CircularBuffer* buffer) {
    return buffer->dataStart == buffer->dataEnd;
}

void CircularBuffer_clear(CircularBuffer* buffer) {
    buffer->dataStart = buffer->dataEnd = buffer->bufferStart;
}

void CircularBuffer_pushBack(CircularBuffer* buffer, uint8_t data) {
    *buffer->dataEnd = data;

    uint8_t* newDataEnd = incrementPointer(buffer, buffer->dataEnd);
    if (newDataEnd == buffer->dataStart) {
        if (buffer->isOverwriteAllowed) {
            buffer->dataStart = incrementPointer(buffer, buffer->dataStart);
            buffer->dataEnd = newDataEnd;
        }
    } else {
        buffer->dataEnd = newDataEnd;
    }
}

uint8_t CircularBuffer_popFront(CircularBuffer* buffer) {
    uint8_t result = *buffer->dataStart;
    buffer->dataStart = incrementPointer(buffer, buffer->dataStart);
    return result;
}

uint8_t CircularBuffer_top(CircularBuffer* buffer) {
    return *buffer->dataStart;
}
