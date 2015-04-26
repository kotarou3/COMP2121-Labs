include ../Makefile.inc

.PHONY: all clean

all: a b d
clean:
	rm a b d

a:
	$(ASSEMBLER) a.S -o a
b:
	$(ASSEMBLER) b.S -o b
d:
	$(ASSEMBLER) ../events.S ../circular-buffer.S d.S -o d
