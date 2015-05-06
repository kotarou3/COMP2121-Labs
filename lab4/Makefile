include ../Makefile.inc

all: a b
clean:
	rm -f a b

a: a.S ../events.S ../keypad.S
	$(ASSEMBLER) ../events.S ../keypad.S a.S -o a

b: b.S ../events.S ../events.c ../lcd.c
	$(COMPILER) ../events.S ../events.c ../lcd.c b.S -o b
