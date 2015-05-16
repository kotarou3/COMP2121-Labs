include ../Makefile.inc

all: port-querier

clean:
	rm -f port-querier

port-querier: port-querier.c events.S events.c
	$(COMPILER) events.S events.c port-querier.c -o port-querier
