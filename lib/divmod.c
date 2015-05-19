#ifdef ALL_ASSEMBLY
    #error Including C source when ALL_ASSEMBLY is set
#endif

#include "divmod.h"

uint16_t udivmod8(uint8_t dividend, uint8_t divisor) {
    uint8_t quotient = 0;
    uint8_t remainder = 0;

    for (uint8_t i = 8; i > 0; --i) {
        remainder <<= 1;
        remainder |= dividend >> 7;
        dividend <<= 1;
        quotient <<= 1;
        if (remainder >= divisor) {
            remainder -= divisor;
            quotient |= 1;
        }
    }

    return (remainder << 8) | quotient;
}

uint32_t udivmod16(uint16_t dividend, uint16_t divisor) {
    uint16_t quotient = 0;
    uint16_t remainder = 0;

    for (uint8_t i = 16; i > 0; --i) {
        remainder <<= 1;
        remainder |= dividend >> 15;
        dividend <<= 1;
        quotient <<= 1;
        if (remainder >= divisor) {
            remainder -= divisor;
            quotient |= 1;
        }
    }

    return ((uint32_t)remainder << 16) | quotient;
}
