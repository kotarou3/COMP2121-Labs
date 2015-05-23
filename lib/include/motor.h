#ifndef MOTOR_H
#define MOTOR_H

#include <stdint.h>

void motorSetup();
uint8_t motorGetRps();
void motorSetRps(uint8_t rps);

#endif
