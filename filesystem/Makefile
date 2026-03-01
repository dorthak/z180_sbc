.PHONY: all clean burn lsimg

-include ../MakeInfo.default


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