#ifndef TIMER_H
#define TIMER_H

#include <stdbool.h>
#include <stdint.h>

void timerClear();
bool timerIsZero();
void timerSetDefaultIfEmpty();
void timerAddSeconds(int8_t seconds);
void timerInput(uint8_t n);

#endif
