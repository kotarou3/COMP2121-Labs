include ../Makefile.inc

all: main
clean:
	rm -f main *.asm *.hex

main: main.c beeper.c magnetron.c turntable.c ../lib/events.S ../lib/events.c ../lib/circular-buffer.c ../lib/divmod.c ../lib/keypad.c ../lib/lcd.c ../lib/motor.c
	$(COMPILER) ../lib/events.S ../lib/events.c ../lib/circular-buffer.c ../lib/divmod.c ../lib/keypad.c ../lib/lcd.c ../lib/motor.c main.c beeper.c magnetron.c turntable.c -o main
