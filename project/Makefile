include ../Makefile.inc

DEPENDENCIES  = ../lib/events.S
DEPENDENCIES += ../lib/circular-buffer.S
DEPENDENCIES += ../lib/divmod.S
DEPENDENCIES += ../lib/keypad.S
DEPENDENCIES += ../lib/lcd.S
DEPENDENCIES += ../lib/motor.S
DEPENDENCIES_ASM = $(DEPENDENCIES:.S=.asm)

all: main main.hex
clean:
	rm -f main *.asm *.hex

main: main.S beeper.S display.S magnetron.S timer.S turntable.S $(DEPENDENCIES)
	$(ASSEMBLER) $(DEPENDENCIES) main.S beeper.S display.S magnetron.S timer.S turntable.S -o main

main.hex: main.asm beeper.asm display.asm magnetron.asm timer.asm turntable.asm $(DEPENDENCIES_ASM)
	$(call prepareAsmFiles, $(DEPENDENCIES_ASM) main.asm beeper.asm display.asm magnetron.asm timer.asm turntable.asm, main-all.asm)
	$(AVRASM) main-all.asm -o main.hex
