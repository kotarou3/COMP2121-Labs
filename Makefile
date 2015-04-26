include Makefile.inc

DIRS = $(wildcard */)

.PHONY: all clean upload-%

all: port-querier
	$(foreach DIR, $(DIRS), $(MAKE) all -C $(DIR) &&) true

clean:
	rm port-querier
	$(foreach DIR, $(DIRS), $(MAKE) clean -C $(DIR) &&) true

port-querier:
	$(COMPILER) events.S events.c port-querier.c -o port-querier
