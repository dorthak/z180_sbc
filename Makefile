.PHONY: all clean

CROSS_AS=uz80as
CROSS_AS_FLAGS=-t hd64180


all: blinky1

blinky1: blinky1.hex

clean:
	rm -f *.hex
	rm -f *.bin
	rm -f *.obj
	rm -f *.lst
	rm -f *.com

%.hex: %.asm
	$(CROSS_AS) $(CROSS_AS_FLAGS)  $(basename $@).asm $@ $(basename $@).lst
