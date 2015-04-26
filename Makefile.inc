CFLAGS = -mmcu=atmega2560 -DF_CPU=16000000 -nostdlib -ggdb

COMPILER = avr-gcc $(CFLAGS) -std=c99 -Wall -Wextra -Os
ASSEMBLER = avr-gcc $(CFLAGS) -DALL_ASSEMBLY
