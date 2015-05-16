include ../Makefile.inc

all: port-querier S2asm.js

clean:
	rm -f port-querier S2asm.js

port-querier: port-querier.c events.S events.c
	$(COMPILER) events.S events.c port-querier.c -o port-querier

S2asm.js: S2asm.jison
	jison S2asm.jison
