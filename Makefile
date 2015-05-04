include Makefile.inc

DIRS = $(wildcard */)

all: port-querier
	$(foreach DIR, $(DIRS), $(MAKE) all -C $(DIR) &&) true

clean:
	rm -f port-querier
	$(foreach DIR, $(DIRS), $(MAKE) clean -C $(DIR) &&) true

port-querier: port-querier.c events.S events.c
	$(COMPILER) events.S events.c port-querier.c -o port-querier
