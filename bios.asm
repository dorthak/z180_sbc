; Large portions of this code are copied from, or inspired by: 
;   John Winans' z80-retro-cpm project.  
;   Wayne Warthen's RomWBW project
; All of their Copyright is retained by original authors

; CP/M 2.2 BIOS for the z180 SBC  (SC131 or s100computers z180 SBC board)

debug:      .equ 1

    .include "z180.asm"

stacktop:   .equ 0x0000             ; end of RAM

    .org      LOAD_BASE               ; where the boot loader placed this code

    ; entry point from the boot loader.
    jp      bios_boot

	; The 'org' in cpm22.asm does not generate any fill so we must
	; padd memory out to the base location of CP/M    
    ds      CPM_BASE-$, 0xff

    .include "cpm22.asm"

    .ifne $-(CPM_BASE+0x1600)
    .fail THE BIOS VECTOR TABLE IS IN THE WRONG PLACE
    .endif

BOOT:   JP      bios_boot
WBOOT:  JP      bios_wboot
CONST:  JP      bios_const
CONIN:  JP      bios_conin
CONOUT: JP      bios_conout
LIST:   JP      bios_list
PUNCH:  JP      bios_punch
READER: JP      bios_reader
HOME:   JP      bios_home
SELDSK: JP      bios_seldsk
SETTRK: JP      bios_settrk
SETSEC: JP      bios_setsec
SETDMA: JP      bios_setdma
READ:   JP      bios_read
WRITE:  JP      bios_write
PRSTAT: JP      bios_prstat
SECTRN: JP      bios_sectrn

bios_boot:
    ld      sp, stack_top
    call    con_init                ; should be initialized from bootloader, but init anyway           
    ld      hl, boot_msg
    call    puts

    jp      halt_loop


bios_wboot:
bios_const:
bios_conin:
bios_conout:
bios_list:
bios_punch:
bios_reader:
bios_home:
bios_seldsk:
bios_settrk:
bios_setsec:
bios_setdma:
bios_read:
bios_write:
bios_prstat:
bios_sectrn:

halt_loop:
    halt
    jp      halt_loop

    
    .include "sio.asm"
    .include "puts.asm"
    .include "sd.asm"
    .include "hexdump.asm"        


boot_msg:
	ascii    '\r\n\r\n'
	ascii	'##############################################################################\r\n'
	ascii	'Z180 SBC BIOS v0.1 Copyright (C) 2026 J. Galak Consulting, Inc.\r\n'
    ascii	'       Portions Copyright (C) John Winans\r\n'
    ascii	'       CP/M 2.2 Copyright (C) 1979 Digital Research\r\n'
    ascii   '       git: @@GIT_VERSION@@\r\n'
    ascii   '       build: @@DATE@@\r\n'
	asciiz	'##############################################################################\r\n'
	


prog_end:   
        .end
