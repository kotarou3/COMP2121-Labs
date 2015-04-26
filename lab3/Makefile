include ../Makefile.inc

.PHONY: all clean

all: a b d
clean:
	rm a b d

a: a.S
	$(ASSEMBLER) a.S -o a
b: b.S
	$(ASSEMBLER) b.S -o b
d: d.S ../events.S ../circular-buffer.S
	$(ASSEMBLER) ../events.S ../circular-buffer.S d.S -o d
