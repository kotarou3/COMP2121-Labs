SHELL = /bin/bash

CFLAGS = -mmcu=atmega2560 -DF_CPU=16000000 -I../lib/include -nostdlib -ggdb

COMPILER = avr-gcc $(CFLAGS) -std=c99 -Wall -Wextra -Os
ASSEMBLER = avr-gcc $(CFLAGS) -DALL_ASSEMBLY
AVRDUDE = avrdude -c stk500v2 -p m2560 -P /dev/ttyACM0 -D -b 115200

S2ASM = ../lib/S2asm.js
AVRASM = wine ../lib/avrasm2.exe -I ../lib/include -fI
ifeq ("$(wildcard S2asm.jison)", "")
../lib/S2asm.js:
	$(MAKE) S2asm.js -C ../lib
endif

prepareAsmFiles = echo -n $$'\#define __ASSEMBLER__\n\#define F_CPU 16000000\n$(foreach file, $(1), \#include "$(file)"\n)' > $(2)

.PHONY: all clean upload-%

upload-%.hex: %.hex
	$(AVRDUDE) -U flash:w:"$<":i
upload-%: %
	$(AVRDUDE) -U flash:w:"$<":e

%.asm: %.S $(S2ASM)
	nodejs $(S2ASM) $< > $@
