#ifndef BEEPER_H
#define BEEPER_H

#include <stdint.h>

void beepSetup();
void beepSet(uint16_t length, uint8_t times);

#endif
