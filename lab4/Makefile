include ../Makefile.inc

all: a b d
clean:
	rm -f a b d

a: a.S ../lib/events.S ../lib/keypad.S
	$(ASSEMBLER) ../lib/events.S ../lib/keypad.S a.S -o a

b: b.S ../lib/events.S ../lib/lcd.S
	$(ASSEMBLER) ../lib/events.S ../lib/lcd.S b.S -o b

d: d.S ../lib/events.S ../lib/keypad.S ../lib/lcd.S
	$(ASSEMBLER) ../lib/events.S ../lib/keypad.S ../lib/lcd.S d.S -o d
