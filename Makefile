.PHONY: all clean

#CROSS_AS=uz80as
#CROSS_AS_FLAGS=-t hd64180

CROSS_AS=zasm
CROSS_AS_FLAGS=--z180 -u --dotnames -y -L ./lib

DATE := $(shell date +"%Y-%m-%d %H:%M:%S%z")
GIT_VERSION := $(shell git show -s --format='%h - %s - %ci')

.SECONDARY:

#all: spi_test
all: firmware hello

blinky1: blinky1.bin
blinky2: blinky2.bin
hello_sio1: hello_sio1.bin
hello_sio2: hello_sio2.bin
hello_sio3: hello_sio3.bin
spi_test: spi_test.bin
sd_test: sd_test.bin
hello: hello.bin
firmware: firmware.bin

clean:
	rm -f *.hex
	rm -f *.bin
	rm -f *.obj
	rm -f *.lst
	rm -f *.com
	rm -f *.tmp

%.tmp: %.asm 
	cat $< | sed  -e "s/@@DATE@@/$(DATE)/g" -e "s/@@GIT_VERSION@@/$(GIT_VERSION)/g" > $(basename $@).tmp



%.bin: %.tmp 
# uz80as version
#	$(CROSS_AS) $(CROSS_AS_FLAGS)  $(basename $@).asm $@ $(basename $@).lst 
# zasm version
	$(CROSS_AS) $(CROSS_AS_FLAGS)  -i $(basename $@).tmp -o $@ -l $(basename $@).lst 

blinky1.tmp: io.asm z180.asm
blinky2.tmp: io.asm z180.asm
hello_sio1.tmp: init.asm io.asm z180.asm sio.asm
hello_sio2.tmp: init.asm io.asm z180.asm sio.asm
hello_sio3.tmp: init.asm io.asm z180.asm sio.asm puts.asm
spi_test.tmp: init.asm io.asm z180.asm sio.asm puts.asm spi.asm hexdump.asm
sd_test.tmp: init.asm io.asm z180.asm sio.asm puts.asm spi.asm hexdump.asm sd.asm
firmware.tmp: init.asm io.asm z180.asm sio.asm puts.asm spi.asm hexdump.asm sd.asm
hello.tmp: io.asm z180.asm hexdump.asm sio.asm puts.asm
