include Makefile.inc

DIRS = $(wildcard */)

all:
	$(foreach DIR, $(DIRS), $(MAKE) all -C $(DIR) &&) true

clean:
	$(foreach DIR, $(DIRS), $(MAKE) clean -C $(DIR) &&) true
