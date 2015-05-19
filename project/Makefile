include ../Makefile.inc

all: main
clean:
	rm -f main *.asm *.hex

main: main.c beeper.c magnetron.c turntable.c ../lib/events.S ../lib/events.c ../lib/divmod.c ../lib/keypad.c ../lib/lcd.c
	$(COMPILER) ../lib/events.S ../lib/events.c ../lib/divmod.c ../lib/keypad.c ../lib/lcd.c main.c beeper.c magnetron.c turntable.c -o main
