.PHONY: all clean burn lsimg

# For normal use on a plain Raspberry PI
SD_DEV=/dev/sda1

# This is used before burning an SD card image to make sure we are on the correct host!
SD_HOSTNAME=Retro

DISKDEF=z80-retro-2k-8m

all: filesystem.img

filesystem.img: ../bios.bin ../cpm/filesystem/* ../adventure/adv-B03
	rm -f filesystem.img
	mkfs.cpm -f $(DISKDEF) -b ../bios.bin filesystem.img
	cpmcp -f $(DISKDEF) filesystem.img ../cpm/filesystem/* 0:
	cpmcp -f $(DISKDEF) filesystem.img ../adventure/adv-B03/* 0:

clean:
	rm -fr *.img

# burn:
# 	sudo dd if=bios.bin of=/dev/sda1 bs=512
# 	sync

burn: filesystem.img
	@ if [ `hostname` != "$(SD_HOSTNAME)" -o ! -b "$(SD_DEV)" ]; then\
		echo "\nWARNING: You are either NOT logged into $(SD_HOSTNAME) or there is no $(SD_DEV) mounted!\n"; \
		false; \
	fi
	sudo dd if=$< of=$(SD_DEV) bs=512 conv=fsync
	sync

lsimg: filesystem.img
	cpmls -f $(DISKDEF) $^