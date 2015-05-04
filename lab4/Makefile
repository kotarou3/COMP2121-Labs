include ../Makefile.inc

all: a
clean:
	rm a

a: a.S ../events.S ../keypad.S
	$(ASSEMBLER) ../events.S ../keypad.S a.S -o a
