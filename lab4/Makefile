include ../Makefile.inc

all: a a.hex b b.hex d d.hex
clean:
	rm -f a b d *.asm *.hex

a: a.S ../lib/events.S ../lib/keypad.S
	$(ASSEMBLER) ../lib/events.S ../lib/keypad.S a.S -o a

a.hex: a.asm ../lib/events.asm ../lib/keypad.asm
	$(call prepareHexFiles, ../lib/events.asm ../lib/keypad.asm a.asm, a-all.asm)
	$(AVRASM) a-all.asm -o a.hex

b: b.S ../lib/events.S ../lib/lcd.S
	$(ASSEMBLER) ../lib/events.S ../lib/lcd.S b.S -o b

b.hex: b.asm ../lib/events.asm ../lib/lcd.asm
	$(call prepareHexFiles, ../lib/events.asm ../lib/lcd.asm b.asm, b-all.asm)
	$(AVRASM) b-all.asm -o b.hex

d: d.S ../lib/events.S ../lib/keypad.S ../lib/lcd.S
	$(ASSEMBLER) ../lib/events.S ../lib/keypad.S ../lib/lcd.S d.S -o d

d.hex: d.asm ../lib/events.asm ../lib/keypad.asm ../lib/lcd.asm
	$(call prepareHexFiles, ../lib/events.asm ../lib/keypad.asm ../lib/lcd.asm d.asm, d-all.asm)
	$(AVRASM) d-all.asm -o d.hex
