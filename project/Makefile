include ../Makefile.inc

all: main
clean:
	rm -f main *.asm *.hex

main: main.c magnetron.c ../lib/events.S ../lib/events.c ../lib/keypad.c ../lib/lcd.c
	$(COMPILER) ../lib/events.S ../lib/events.c ../lib/keypad.c ../lib/lcd.c main.c magnetron.c -o main
