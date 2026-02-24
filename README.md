Development code for CP/M bios and drivers for the s100 computes z180 sbc board (https://s100computers.com/My%20System%20Pages/Z180%20SBC/Z180%20SBC1.htm) based on the code created by John Winans in his z80 Retro project (https://github.com/Z80-Retro)

This project is currently designed to be assembled using the vasm assembler, found here: http://sun.hasenbraten.de/vasm/ and here: https://github.com/StarWolf3000/vasm-mirror  It needs to be built to support the oldstyle syntax module and the z80 CPU module.

See Makefile for assembler options.

Some other Makefile notes:

`make` or `make all` will build the firmware and the bios.  To build test programs, run, for example `make blinky1`.

`make clean` will delete all intermediate and compiled files.

`make flash` will install firmware.bin onto the z180 SBC board using a z80 Retro programmer (hardware and software here: https://github.com/Z80-Retro/2065-Z80-programmer) and my adapter board (link TBD).  Note a change needs to be made in the programmer code - in `pi/flash.c`, line 520, needs to be changed from:

`if (d != 0xbfb5 && d != 0xbfb6 && d != 0xbfb7)` to `if (d != 0xbfb5 && d != 0xbfb6 && d != 0xbfb7 && d != 0x3ec0)` to support the ROM chip on the z180 SBC board.  The programmer then needs to be re-built.

`make install` will generate a file system to place on an SD card.  You must install cpm tools using `sudo apt install cpmtools` or equivalent, and you must have a valid diskdefs file in the correct location.

`make burn` will put the file system onto the SD card.  Be sure to look carefully at the `Makefile` in the `filesystem` directory to make certain the correct device is being written to, and the code is being run on the correct device.  The settings there work on my RPi.  Getting this wrong can brick your computer!