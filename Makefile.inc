CFLAGS = -mmcu=atmega2560 -DF_CPU=16000000 -nostdlib -ggdb

COMPILER = avr-gcc $(CFLAGS) -std=c99 -Wall -Wextra -Os
ASSEMBLER = avr-gcc $(CFLAGS) -DALL_ASSEMBLY
AVRDUDE = avrdude -c stk500v2 -p m2560 -P /dev/ttyACM0 -D -b 115200

.PHONY: all clean upload-%
upload-%: %
	$(AVRDUDE) -U flash:w:"$<":e
