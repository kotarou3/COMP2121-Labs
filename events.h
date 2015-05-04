#ifndef EVENTS_H
#define EVENTS_H

#ifndef ALL_ASSEMBLY

#include <stdbool.h>
#include <stdint.h>

void* setTimeout(void (*callback)(uint8_t), uint8_t arg, uint16_t milliseconds);
void* setInterval(void (*callback)(uint8_t, bool), uint8_t arg, uint16_t milliseconds, uint16_t times);
void* setIntervalWithDelay(void (*callback)(uint8_t, bool), uint8_t arg, uint16_t delay, uint16_t milliseconds, uint16_t times);
void clearInterval(void* interval);
#define clearTimeout(a) clearInterval(a)

void onInterrupt(uint8_t vectorNumber, void (*callback)(uint8_t));

// Falling edge trigger must be enabled. Will callback on a debounced falling edge.
void onDebouncedInterrupt(uint8_t vectorNumber, void (*callback)(uint8_t));

#else

#define clearTimeout clearInterval

#endif

#endif
