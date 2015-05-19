#ifndef DIVMOD_H
#define DIVMOD_H

#include <stdint.h>

// Binary long division: http://en.wikipedia.org/wiki/Division_algorithm#Integer_division_.28unsigned.29_with_remainder
// Modified to be more optimal for AVR

// All functions return remainder in upper half and quotient in lower half
uint16_t udivmod8(uint8_t dividend, uint8_t divisor);
uint32_t udivmod16(uint16_t dividend, uint16_t divisor);

#endif
