include ../Makefile.inc

all: a a.hex b b.hex d d.hex
clean:
	rm -f a b d d-events.S *.asm *.hex

a: a.S
	$(ASSEMBLER) a.S -o a

a.hex: a.asm
	$(call prepareAsmFiles, a.asm, a-all.asm)
	$(AVRASM) a-all.asm -o a.hex

b: b.S
	$(ASSEMBLER) b.S -o b

b.hex: b.asm
	$(call prepareAsmFiles, b.asm, b-all.asm)
	$(AVRASM) b-all.asm -o b.hex

d-events.S: d-events.S.patch ../lib/events.S
	cp ../lib/events.S d-events.S
	patch -mp1 d-events.S < d-events.S.patch

d: d.S d-events.S ../lib/circular-buffer.S
	$(ASSEMBLER) d-events.S ../lib/circular-buffer.S d.S -o d

d.hex: d.asm d-events.asm ../lib/circular-buffer.asm
	$(call prepareAsmFiles, d-events.asm d.asm ../lib/circular-buffer.asm, d-all.asm)
	$(AVRASM) d-all.asm -o d.hex
