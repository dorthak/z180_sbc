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


;##########################################################################
;
; CP/M 2.2 Alteration Guide p17:
; The BOOT entry point gets control from the cold start loader and is
; responsible for basic system initialization, including sending a signon
; message.
;
; If the IOBYTE function is implemented, it must be set at this point.
;
; The various system parameters which are set by the WBOOT entry point
; must be initialized (see .go_cpm), and control is transferred to the CCP 
; at 3400H+b for further processing.
;
; Note that reg C must be set to zero to select drive A.
;
;##########################################################################

bios_boot:
    ld      sp, stack_top
    call    con_init                ; should be initialized from bootloader, but init anyway           
    ld      hl, .boot_msg
    call    puts

    ; Wipe the zero-page from random stuff from boot loader or noise
    ld      hl, 0                   ; Start from here
    ld      de, 1                   ; ldir copies from (HL) to (DE), so this will copy one byte ahead
    ld      bc, $FF                 ; Wipe entire zero page ($0-$FF)
    ld      (hl), 0                 ; set byte at addr 0 to 0, it'll be copied to rest of range
    ldir  

    jp      go_cpm

.boot_msg:
	ascii    '\r\n\r\n'
	ascii	'##############################################################################\r\n'
	ascii	'Z180 SBC BIOS v0.1 Copyright (C) 2026 J. Galak Consulting, Inc.\r\n'
    ascii	'       Portions Copyright (C) John Winans\r\n'
    ascii	'       CP/M 2.2 Copyright (C) 1979 Digital Research\r\n'
    ascii   '       git: @@GIT_VERSION@@\r\n'
    ascii   '       build: @@DATE@@\r\n'
	asciiz	'##############################################################################\r\n'
	
;##########################################################################
;
; CP/M 2.2 Alteration Guide p17:
; The WBOOT entry point gets control when a warm start occurs.  A warm
; start is performed whenever a user program branches to location 0x0000.
;
; The CP/M CCP and BDOS must be re-loaded from the first two tracks of 
; drive A up to, but not including, the BIOS.
;
; The WBOOT & BDOS jump instructions in page-zero must be initialized 
; (see .go_cpm), and control is transferred to the CCP at 3400H+b for 
; further processing.
;
; Upon completion of the initialization, the WBOOT program must branch
; to the CCP at 3400H+b to (re)start the system. Upon entry to the CCP,
; register C is set to the drive to select after system initialization.
;
;##########################################################################

bios_wboot:
    call    iputs
    asciiz  "\r\nbios_wboot entered\r\n"

    ; TODO: Reload CCP and BDOS here

go_cpm:
	ld	    a,0xc3		            ; opcode for JP
	ld	    (0), a
	ld	    hl, WBOOT
	ld	    (1), hl		            ; address 0 now = JP WBOOT

	ld	    (5), a		            ; opcode for JP
	ld	    hl, FBASE
	ld	    (6), hl		            ; address 6 now = JP FBASE

	ld	    bc, 0x80		        ; this is here because it is in the example CBIOS (AG p.52)
	call	bios_setdma             

    .ifdef debug
	; dump the zero-page for reference
	ld	    hl, 0		            ; start address
	ld	    bc, 0x100	            ; number of bytes
	ld	    e, 1		            ; fancy format
	call	hexdump    
    .endif

	ld	    a, (4)		            ; load the current disk # from page-zero into a/c
	ld	    c, a
	jp	    CPM_BASE	            ; start the CCP

    jp      halt_loop

    
;##########################################################################
;
; CP/M 2.2 Alteration Guide p17:
; If the console device is ready for reading then return 0FFH in register A.
; Else return 00H in register A.
;
;##########################################################################

bios_const:
    call    con_rx_ready
    ret     z                       ; A=0 - not ready
    ld      a, $FF
    ret                             ; A=1 - ready

 ;##########################################################################
;
; CP/M 2.2 Alteration Guide p17:
; Read the next console character into register A and set the parity bit
; (high order bit) to zero.  If no console character is ready, wait until
; a character is typed before returning.
;
;##########################################################################

bios_conin:
    jp      con_rx_char

;##########################################################################
;
; CP/M 2.2 Alteration Guide p18:
; Send the character from register C to the console output device.  The
; character is in ASCII, with high order parity bit set to zero.
;
;##########################################################################

bios_conout:
    JP      con_tx_char

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

;##########################################################################
; The .disk_XXX values are used to retain the most recent values that
; have been set by the .bios_setXXX routines.
; These are used by the .bios_read and .bios_write routines.
;##########################################################################
disk_dma:				; last set value of the DMA buffer address
	dw	0xa5a5

disk_track:				; last set value of the disk track
	dw	0xa5a5

disk_disk:				; last set value of the selected disk
	db	0xa5

disk_sector:				; last set value of of the disk sector
	dw	0xa5a5



prog_end:   
        .end
