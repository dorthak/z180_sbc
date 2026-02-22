.PHONY: all clean

all: filesystem.img

filesystem.img: ../bios.bin 
	rm -f filesystem.img
	mkfs.cpm -f z80-retro-2k-8m -b ../bios.bin filesystem.img

clean:
	rm -fr *.img