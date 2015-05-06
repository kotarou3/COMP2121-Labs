include ../Makefile.inc

all: a b d
clean:
	rm -f a b d

a: a.S ../events.S ../keypad.S
	$(ASSEMBLER) ../events.S ../keypad.S a.S -o a

b: b.S ../events.S ../events.c ../lcd.c
	$(COMPILER) ../events.S ../events.c ../lcd.c b.S -o b

d: d.c ../events.S ../events.c ../keypad.c ../lcd.c
	$(COMPILER) ../events.S ../events.c ../keypad.c ../lcd.c d.c -o d
