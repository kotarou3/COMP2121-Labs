#ifndef LCD_H
#define LCD_H

#ifndef ALL_ASSEMBLEY

#include <stdbool.h>
#include <stdint.h>

void lcdClear();
void lcdSetCursor(bool isTopRow, uint8_t col);
void lcdShiftCursor(bool isRight);

void lcdWrite(char c);
void lcdWriteString(const char* str);

void lcdSetup();

#endif

#endif
