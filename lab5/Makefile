include ../Makefile.inc

all: a a.hex b b.hex c c.hex
clean:
	rm -f a b c *.asm *.hex

a: a.S ../lib/events.S ../lib/circular-buffer.S ../lib/divmod.S ../lib/lcd.S ../lib/motor.S
	$(ASSEMBLER) ../lib/events.S ../lib/circular-buffer.S ../lib/divmod.S ../lib/lcd.S ../lib/motor.S a.S -o a

a.hex: a.asm ../lib/events.asm ../lib/circular-buffer.asm ../lib/divmod.asm ../lib/lcd.asm ../lib/motor.asm
	$(call prepareHexFiles, ../lib/events.asm ../lib/circular-buffer.asm ../lib/divmod.asm ../lib/lcd.asm ../lib/motor.asm a.asm, a-all.asm)
	$(AVRASM) a-all.asm -o a.hex

b: b.S ../lib/events.S
	$(ASSEMBLER) ../lib/events.S b.S -o b

b.hex: b.asm ../lib/events.asm
	$(call prepareHexFiles, ../lib/events.asm b.asm, b-all.asm)
	$(AVRASM) b-all.asm -o b.hex

c: c.S ../lib/events.S ../lib/circular-buffer.S ../lib/divmod.S ../lib/lcd.S ../lib/motor.S
	$(ASSEMBLER) ../lib/events.S ../lib/circular-buffer.S ../lib/divmod.S ../lib/lcd.S ../lib/motor.S c.S -o c

c.hex: c.asm ../lib/events.asm ../lib/circular-buffer.asm ../lib/divmod.asm ../lib/lcd.asm ../lib/motor.asm
	$(call prepareHexFiles, ../lib/events.asm ../lib/circular-buffer.asm ../lib/divmod.asm ../lib/lcd.asm ../lib/motor.asm c.asm, c-all.asm)
	$(AVRASM) c-all.asm -o c.hex
