.PHONY: all clean

-include ../MakeInfo.default

DATE := $(shell date +"%Y-%m-%d %H:%M:%S%z")
GIT_VERSION := $(shell git describe --tags --long --dirty; git show -s --format='%ci')

all: test1 test2 test3

test1: test1.com
test2: test2.com
test3: test3.com

-include *.dep

%.com: %.asm
	cat $< | sed -e "s/@@DATE@@/$(DATE)/g" -e "s/@@GIT_VERSION@@/$(GIT_VERSION)/g" | $(CROSS_AS) $(CROSS_AS_FLAGS) -depend=make -depfile $@.dep -o $@ -L $(basename $@).lst


clean:
	rm -f *.hex
	rm -f *.bin
	rm -f *.obj
	rm -f *.lst
	rm -f *.com
	rm -f *.tmp
	rm -f *.dep
	rm -f *.img
	rm -f *.com