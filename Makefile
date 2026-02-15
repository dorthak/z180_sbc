.PHONY: all clean

#CROSS_AS=uz80as
#CROSS_AS_FLAGS=-t hd64180

CROSS_AS=~/vasm/vasmz80_oldstyle
CROSS_AS_FLAGS=-Fbin -esc -dotdir -hd64180 -ldots -I./lib -I./cpm

#CROSS_AS=zasm
#CROSS_AS_FLAGS=--z180 -u --dotnames -y -L ./lib

DATE := $(shell date +"%Y-%m-%d %H:%M:%S%z")
GIT_VERSION := $(shell git show -s --format='%h - %s - %ci')


#all: spi_test
all: firmware hello

blinky1: test/blinky1.bin
blinky2: blinky2.bin
hello_sio1: hello_sio1.bin
hello_sio2: hello_sio2.bin
hello_sio3: hello_sio3.bin
spi_test: spi_test.bin
sd_test: sd_test.bin
hello: hello.bin
firmware: firmware.bin

-include *.dep

clean:
	rm -fr *.hex
	rm -fr *.bin
	rm -fr *.obj
	rm -fr *.lst
	rm -fr *.com
	rm -fr *.tmp
	rm -fr *.dep

# .SECONDARY:

%.tmp: %.asm 
	cat $< | sed  -e "s/@@DATE@@/$(DATE)/g" -e "s/@@GIT_VERSION@@/$(GIT_VERSION)/g" > $(basename $@).tmp



%.bin: %.tmp 
	$(CROSS_AS) $(CROSS_AS_FLAGS) -depend=make -depfile $@.dep -o $@ $(basename $@).tmp

# uz80as version
#	$(CROSS_AS) $(CROSS_AS_FLAGS)  $(basename $@).asm $@ $(basename $@).lst 
# zasm version
#	$(CROSS_AS) $(CROSS_AS_FLAGS)  -i $(basename $@).tmp -o $@ -l $(basename $@).lst 
# vasm version



# blinky1.tmp: lib/io.asm lib/z180.asm
# blinky2.tmp: lib/io.asm lib/z180.asm
# hello_sio1.tmp: init.asm io.asm lib/z180.asm sio.asm
# hello_sio2.tmp: init.asm io.asm lib/z180.asm sio.asm
# hello_sio3.tmp: init.asm io.asm lib/z180.asm sio.asm puts.asm
# spi_test.tmp: init.asm lib/io.asm lib/z180.asm sio.asm puts.asm spi.asm hexdump.asm
# sd_test.tmp: init.asm lib/io.asm lib/z180.asm sio.asm puts.asm spi.asm hexdump.asm sd.asm
# firmware.tmp: init.asm lib/io.asm lib/z180.asm sio.asm puts.asm spi.asm hexdump.asm sd.asm
# hello.tmp: lib/io.asm lib/z180.asm hexdump.asm sio.asm puts.asm
