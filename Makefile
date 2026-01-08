.PHONY: all clean

#CROSS_AS=uz80as
#CROSS_AS_FLAGS=-t hd64180

CROSS_AS=zasm
CROSS_AS_FLAGS=--z180 -u --dotnames 


all: hello_sio3

blinky1: blinky1.bin
blinky2: blinky2.bin
hello_sio1: hello_sio1.bin
hello_sio2: hello_sio2.bin
hello_sio3: hello_sio3.bin

clean:
	rm -f *.hex
	rm -f *.bin
	rm -f *.obj
	rm -f *.lst
	rm -f *.com

%.bin: %.asm 
#	$(CROSS_AS) $(CROSS_AS_FLAGS)  $(basename $@).asm $@ $(basename $@).lst
	$(CROSS_AS) $(CROSS_AS_FLAGS)  -i $(basename $@).asm -o $@ -l $(basename $@).lst

blinky1.bin: init.asm io.asm z180.asm
blinky2.bin: init.asm io.asm z180.asm
hello_sio1.bin: init.asm io.asm z180.asm sio.asm
hello_sio2.bin: init.asm io.asm z180.asm sio.asm
hello_sio3.bin: init.asm io.asm z180.asm sio.asm puts.asm
