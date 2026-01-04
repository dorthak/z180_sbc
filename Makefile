.PHONY: all clean

#CROSS_AS=uz80as
#CROSS_AS_FLAGS=-t hd64180

CROSS_AS=zasm
CROSS_AS_FLAGS=--z180 -u


all: blinky2

blinky1: blinky1.bin
blinky2: blinky2.bin

clean:
	rm -f *.hex
	rm -f *.bin
	rm -f *.obj
	rm -f *.lst
	rm -f *.com

%.bin: %.asm
#	$(CROSS_AS) $(CROSS_AS_FLAGS)  $(basename $@).asm $@ $(basename $@).lst
	$(CROSS_AS) $(CROSS_AS_FLAGS)  -i $(basename $@).asm -o $@ -l $(basename $@).lst
