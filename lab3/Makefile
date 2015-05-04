include ../Makefile.inc

all: a b d
clean:
	rm -f a b d d-events.S

a: a.S
	$(ASSEMBLER) a.S -o a
b: b.S
	$(ASSEMBLER) b.S -o b

d-events.S: d-events.S.patch ../events.S
	cp ../events.S d-events.S
	patch -mp1 d-events.S < d-events.S.patch
d: d.S d-events.S ../circular-buffer.S
	$(ASSEMBLER) d-events.S ../circular-buffer.S d.S -o d
