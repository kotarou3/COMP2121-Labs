#ifndef DISPLAY_H
#define DISPLAY_H

#include <stdbool.h>
#include <stdint.h>

void displaySetup();
void displayActivate();
void displayEnableDimming(bool isEnabling);

void displayUpdateTime(uint8_t minutes, uint8_t seconds, uint8_t digitsToDisplay);
void displayUpdateDoor(bool isOpen);

void displayStatusRemoveFood();
void displayStatusSetPower();
void displayStatusClear();

#endif
