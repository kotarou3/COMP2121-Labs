include ../Makefile.inc

DEPENDENCIES  = ../lib/events.S ../lib/events.c
DEPENDENCIES += ../lib/circular-buffer.c
DEPENDENCIES += ../lib/divmod.c
DEPENDENCIES += ../lib/keypad.c
DEPENDENCIES += ../lib/lcd.c
DEPENDENCIES += ../lib/motor.c

all: main
clean:
	rm -f main *.asm *.hex

main: main.c beeper.c display.c magnetron.c timer.c turntable.c $(DEPENDENCIES)
	$(COMPILER) $(DEPENDENCIES) main.c beeper.c display.c magnetron.c timer.c turntable.c -o main
