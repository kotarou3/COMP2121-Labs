include ../Makefile.inc

all: a b d
clean:
	rm -f a b d

a: a.S ../events.S ../keypad.S
	$(ASSEMBLER) ../events.S ../keypad.S a.S -o a

b: b.S ../events.S ../lcd.S
	$(ASSEMBLER) ../events.S ../lcd.S b.S -o b

d: d.S ../events.S ../keypad.S ../lcd.S
	$(ASSEMBLER) ../events.S ../keypad.S ../lcd.S d.S -o d
