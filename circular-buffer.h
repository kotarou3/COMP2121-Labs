#ifndef CIRCULAR_BUFFER_H
#define CIRCULAR_BUFFER_H

#ifndef __ASSEMBLER__

#include <stdbool.h>
#include <stdint.h>

typedef struct _CircularBuffer {
    bool isOverwriteAllowed;
    uint8_t* dataStart;
    uint8_t* dataEnd;
    uint8_t* bufferStart;
    uint8_t* bufferEnd;
} CircularBuffer;

void CircularBuffer_init(CircularBuffer* buffer, uint8_t* rawBuffer, uint16_t rawBufferSize, bool isOverwriteAllowed);

uint16_t CircularBuffer_size(CircularBuffer* buffer);
bool CircularBuffer_isEmpty(CircularBuffer* buffer);

void CircularBuffer_clear(CircularBuffer* buffer);
void CircularBuffer_pushBack(CircularBuffer* buffer, uint8_t data);
uint8_t CircularBuffer_popFront(CircularBuffer* buffer);

uint8_t CircularBuffer_top(CircularBuffer* buffer);

#else

#define CircularBuffer_isOverwriteAllowed 0
#define CircularBuffer_dataStart (CircularBuffer_isOverwriteAllowed + 1)
#define CircularBuffer_dataEnd (CircularBuffer_dataStart + 2)
#define CircularBuffer_bufferStart (CircularBuffer_dataEnd + 2)
#define CircularBuffer_bufferEnd (CircularBuffer_bufferStart + 2)
#define sizeof_CircularBuffer (CircularBuffer_bufferEnd + 2)

#endif

#endif
