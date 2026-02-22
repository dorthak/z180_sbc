; Large portions of this code are copied from, or inspired by: 
;   John Winans' z80-retro-cpm project.  
;   Wayne Warthen's RomWBW project
; All of their Copyright is retained by original authors

; CP/M 2.2 BIOS for the z180 SBC  (SC131 or s100computers z180 SBC board)

;##########################################################################
; set .debug to:
;    0 = no debug output
;    1 = print messages from new code under development
;    2 = print all the above plus the primairy 'normal' debug messages
;    3 = print all the above plus verbose 'noisy' debug messages
;##########################################################################

debug:      .equ 3


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
    ld      sp, bios_stack

    ; preserve info about flash loader location in RAM
    push    hl                      
    push    de

    call    con_init                ; should be initialized from bootloader, but init anyway           
    
    .if debug > 0
        call    iputs
        asciiz  "\r\nbios_boot entered\r\n"
	    call	iputs
	    asciiz	"NOTICE: Debug level is set to: 0x"
	    ld	    a, debug		    ; A = the current debug level
	    call	hexdump_a		    ; print the current level number
	    call	puts_crlf		    ; and a newline
    .endif
    
    ld      hl, .boot_msg
    call    puts

    ; Wipe the space occupied by loader
    pop     hl                      ; loader code in RAM starts here

    push    hl                      ; put code start +1 into de
    pop     de                      
    inc     de

    pop     bc                      ; size of bootloader (was in de before)

    ld      (hl), 0                 ; set byte at addr 0 to 0, it'll be copied to rest of range
    ldir
    
    .if debug >=3
        call    iputs
        asciiz  "\r\nflash bios wiped\r\n"
    .endif

    ; Wipe the zero-page from random stuff from boot loader or noise
    ld      hl, 0                   ; Start from here
    ld      de, 1                   ; ldir copies from (HL) to (DE), so this will copy one byte ahead
    ld      bc, $FF                 ; Wipe entire zero page ($0-$FF)
    ld      (hl), 0                 ; set byte at addr 0 to 0, it'll be copied to rest of range
    ldir  

     .if debug >=3
        call    iputs
        asciiz  "\r\nzero page wiped\r\n"
    .endif

    jp      gocpm

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
    .if debug >=2
        call    iputs
        asciiz  "\r\nbios_wboot entered\r\n"
    .endif

    ; TODO: Reload CCP and BDOS here
   	call	iputs
	db	    "\r\n\r\nERROR: THE WBOOT FUNCTION IS UNIMPLEMENTED.  HALTING."
	db	    "\r\n\n*** PRESS RESET TO REBOOT ***\r\n"
	db	    0
	jp	    $		; endless spin loop 

gocpm:
    .if debug >=2
        call    iputs
        asciiz  "\r\ngocpm entered\r\n"
    .endif

	ld	    a,0xc3		            ; opcode for JP
	ld	    (0), a
	ld	    hl, WBOOT
	ld	    (1), hl		            ; address 0 now = JP WBOOT

	ld	    (5), a		            ; opcode for JP
	ld	    hl, FBASE
	ld	    (6), hl		            ; address 6 now = JP FBASE

	ld	    bc, 0x80		        ; this is here because it is in the example CBIOS (AG p.52)
	call	bios_setdma             

    .if debug >=3
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
    jp      con_tx_char

;##########################################################################
;
; CP/M 2.2 Alteration Guide p18:
; Send the character from register C to the currently assigned listing
; device.  The character is in ASCII with zero parity.
;
;##########################################################################
bios_list:
    ret


;##########################################################################
;
; CP/M 2.2 Alteration Guide p20:
; Return the ready status of the list device.  Used by the DESPOOL program
; to improve console response during its operation.  The value 00 is
; returned in A of the list device is not ready to accept a character, and
; 0FFH if a character can be sent to the printer. 
;
; Note that a 00 value always suffices.
;
; Clobbers AF
;##########################################################################
bios_prstat:
    ld      a, 0                    ; printer is never ready
    ret

;##########################################################################
;
; CP/M 2.2 Alteration Guide p18:
; Send the character from register C to the currently assigned punch device.
; The character is in ASCII with zero parity.
;
; The z180 SBC currently has no punch device. Discard any data written.
;
;##########################################################################    
bios_punch:
    ret
 
;##########################################################################
;
; CP/M 2.2 Alteration Guide p18:
; Read the next character from the currently assigned reader device into
; register A with zero parity (high order bit must be zero), an end of
; file condition is reported by returning an ASCII control-Z (1AH).
;
; The z180 SBC currently has no tape device. Return the EOF character.
;
;##########################################################################  
bios_reader:
    ld      a, $1A
    ret

;##########################################################################
;
; CP/M 2.2 Alteration Guide p18:
; Return the disk head of the currently selected disk to the track 
; 00 position.
;
; The z180 SBC currently does not have a mechanical disk drive. So just treat
; this like a SETTRK 0.
;
;##########################################################################
bios_home:
    .if debug >=2
        call	iputs
        asciiz  "bios_home entered\r\n"
    .endif

	ld	    bc, 0

	; Fall into bios_settrk <--------------- NOTICE!!

;##########################################################################
;
; CP/M 2.2 Alteration Guide p19:
; Register BC contains the track number for subsequent disk
; accesses on the currently selected drive.  BC can take on
; values from 0-65535.
;
;##########################################################################
bios_settrk:
	ld	    (disk_track), bc

    .if debug >=2
        call	iputs
        asciiz  "bios_settrk entered: "
        call	debug_disk
    .endif

	ret

;##########################################################################
;
; CP/M 2.2 Alteration Guide p18:
; Select the disk drive given by register C for further operations, where
; register C contains 0 for drive A, 1 for drive B, and so-forth UP to 15
; for drive P.
;
; On each disk select, SELDSK must return in HL the base address of a 
; l6-byte area, called the Disk Parameter Header for the selected drive.
;
; If there is an attempt to select a non-existent drive, SELDSK returns
; HL=0000H as an error indicator.
;
; The z180 SBC currently only has one drive. However, I implemented this to allow
; more disks to be added without a rewrite.
;
;##########################################################################
bios_seldsk:
	ld	    a, c
	ld	    (disk_disk), a          ; Should this be done after validation?

    .if debug >=2
        call	iputs
        asciiz	"bios_seldsk entered: "
        call	debug_disk
    .endif

	ld	    hl, 0			        ; HL = 0 = invalid disk 
    ld      a, (disk_disk)
    or      a                       ; did drive A (0) get selected?
    ret     nz                      ; if not 0, error

    ld      hl, bios_dph            ; the DPH table for disk A
	ret


;##########################################################################
;
; CP/M 2.2 Alteration Guide p19:
; Register BC contains the sector number for subsequent disk accesses on
; the currently selected drive.
;
;##########################################################################
bios_setsec:
    ld      (disk_sector), bc


	.if debug >=2
        call	iputs
        asciiz	"bios_setsec entered: "
        call	debug_disk
    .endif

    ret

;##########################################################################
;
; CP/M 2.2 Alteration Guide p19:
; Register BC contains the DMA (disk memory access) address for subsequent
; read or write operations.  For example, if B = 00H and C = 80H when SETDMA
; is called, then all subsequent read operations read their data into 80H
; through 0FFH, and all subsequent write operations get their data from
; 80H through 0FFH, until the next call to SETDMA changes it.
;
;##########################################################################
bios_setdma:
    ld      (disk_dma), bc

    .if debug >=2
        call	iputs
        asciiz	"bios_setdma entered: "
        call	debug_disk
    .endif

    ret


;##########################################################################
;
; CP/M 2.2 Alteration Guide p19:
; Assuming the drive has been selected, the track has been set, the sector
; has been set, and the DMA address has been specified, the READ subroutine
; attempts to read one sector based upon these parameters, and returns the
; following error codes in register A:
;
;    0 no errors occurred
;    1 non-recoverable error condition occurred
;
; When an error is reported the BDOS will print the message "BDOS ERR ON
; x: BAD SECTOR".  The operator then has the option of typing <cr> to ignore
; the error, or ctl-C to abort.
;
;##########################################################################    

bios_read:

    .if debug >=1
        call	iputs
        asciiz	"bios_read entered: "
        call	debug_disk
    .endif


    .if 0

	    ; fake a 'blank'/formatted sector
	    ld	    hl, (disk_dma)		; HL = buffer address
	    ld	    de, (disk_dma)
	    inc	    de			        ; DE = buffer address + 1
	    ld	    bc, $007f		    ; BC = 127
	    ld	    (hl), $e5
	    ldir    				    ; set 128 bytes from (hl) to 0xe5
	    xor	    a			        ; A = 0 = OK
    .else
      	; switch to a local stack (we only have a few levels when called from the BDOS!)
        push	hl			        ; save HL into the caller's stack
        ld	    hl, 0
        add	    hl, sp			    ; HL = SP
        ld	    sp, bios_stack		; SP = temporary private BIOS stack area
        push	hl			        ; save the old SP value in the BIOS stack

        push	bc			        ; save the register pairs we wilol otherwise clobber
        push	de			        ; this is not critical but may make WBOOT cleaner later

        ld	    hl, (disk_track)	; HL = CP/M track number

        ; XXX This is a hack that won't work unless the disk partition < 0x10000
        ; XXX This has the SD card partition offset hardcoded in it!!!
  .sd_partition_base: equ	$0800
        ld	    de, .sd_partition_base	; XXX add the starting partition block number
    	add	    hl, de			    ; HL = SD physical block number

    	; push the 32-bit physical SD block number into the stack in little-endian order
    	ld	    de, 0
    	push	de			        ; 32-bit SD block number (big end)
    	push	hl			        ; 32-bit SD block number (little end)
    	ld	    de, .bios_sdbuf		; DE = target buffer to read the 512-byte block
    	call	sd_cmd17		    ; read the SD block
    	pop	    hl			        ; clean the SD block number from the stack
    	pop	    de

    	or	    a			        ; was the SD driver read OK?
    	jr	    z, .bios_read_sd_ok

    	call	iputs
    	asciiz  "BIOS_READ FAILED!\r\n"
    	ld	    a, 1			    ; tell CP/M the read failed
    	jp	    .bios_read_ret

.bios_read_sd_ok:
    	; calculate the CP/M sector offset address (.disk_sector*128)
    	ld	    hl, (.disk_sector)	; must be 0..3
    	add	    hl, hl			    ; HL *= 2
    	add	    hl, hl			    ; HL *= 4
    	add	    hl, hl			    ; HL *= 8
    	add	    hl, hl			    ; HL *= 16
    	add	    hl, hl			    ; HL *= 32
    	add	    hl, hl			    ; HL *= 64
    	add	    hl, hl			    ; HL *= 128
 
    	; calculate the address of the CP/M sector in the .bios_sdbuf
    	ld	    bc ,.bios_sdbuf
    	add	    hl, bc			    ; HL = @ of cpm sector in the .bios_sdbuf

    	; copy the data of interest from the SD block
    	ld	    de, (.disk_dma)		; target address
    	ld	    bc, $0080		    ; number of bytes to copy
    	ldir

    	xor	    a			        ; A = 0 = read OK

.bios_read_ret:
    	pop	    de			        ; restore saved regs
    	pop	    bc

    	pop	    hl			        ; HL = original saved stack pointer
    	ld	    sp, hl			    ; SP = original stack address
    	pop	    hl			        ; restore the original  HL value
    .endif

	ret

;##########################################################################
;
; CP/M 2.2 Alteration Guide p19:
; Write the data from the currently selected DMA address to the currently
; selected drive, track, and sector.  The error codes given in the READ
; command are returned in register A.
;
; Upon entry the value of C will be useful for deblocking and deblocking a
; drive's physical sector sizes:
;  0 = normal sector write
;  1 = write into a directory sector
;  2 = first sector of a newly used block
;
; Return the following completion status in register A:
;
;    0 no errors occurred
;    1 non-recoverable error condition occurred
;
; When an error is reported the BDOS will print the message "BDOS ERR ON
; x: BAD SECTOR".  The operator then has the option of typing <cr> to ignore
; the error, or ctl-C to abort.
;
;##########################################################################
bios_write:

    .if debug >=1
        call	iputs
        asciiz	"bios_write entered: "
        call	debug_disk
    .endif

    ld      a, 1                    ; XXX  <--------- stub in an error for every write

    ret

;##########################################################################
;
; CP/M 2.2 Alteration Guide p20:
; Performs sector logical to physical sector translation in order to improve
; the overall response of CP/M.
;
; Xlate the sector number in BC using table in DE & return in HL
; If DE=0 here then translation is 1:1
;
; The Z80 Retro! does not translate its sectors.  Therefore it will return
; HL = BC for a 1:1 translation.
;
;##########################################################################
bios_sectrn:
	; 1:1 translation  (no skew factor)
	ld	    h, b
	ld	    l, c
	ret

;##########################################################################
; A debug routing for displaying the settings before a read or write
; operation.
;
; Clobbers AF, C
;##########################################################################
    .if debug >=1
    debug_disk:
        call	iputs
        asciiz	'disk=0x'

        ld	    a, (disk_disk)
        call	hexdump_a

        call    iputs
        asciiz	", track=0x"
        ld	    a, (disk_track+1)
        call	hexdump_a
        ld	    a, (disk_track)
        call	hexdump_a

        call	iputs
        asciiz	", sector=0x"
        ld	    a, (disk_sector+1)
        call	hexdump_a
        ld	    a,(disk_sector)
        call	hexdump_a

        call	iputs
        asciiz	", dma=0x"
        ld	    a, (disk_dma+1)
        call	hexdump_a
        ld	    a, (disk_dma)
        call	hexdump_a
        call	puts_crlf

        ret
    .endif

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

;##########################################################################
; Goal: Define a CP/M-compatible filesystem that can be implemented using
; an SDHC card.  An SDHC card is comprised of a number of 512-byte blocks.
;
; Plan:
; - Put 4 128-byte CP/M sectors into each 512-byte SDHC block.
; - Treat each SDHC block as a CP/M track.
;
; This CP/M filesystem has:
;  128 bytes/sector (CP/M requirement)
;  4 sectors/track (Retro BIOS designer's choice)
;  65536 total sectors (max CP/M limit)
;  65536*128 = 8388608 gross bytes (max CP/M limit)
;  65536/4 = 16384 tracks
;  2048 allocation block size BLS (Retro BIOS designer's choice)
;  8388608/2048 = 4096 gross allocation blocks in our filesystem
;  32 = number of reserved tracks to hold the O/S
;  32*512 = 16384 total reserved track bytes
;  floor(4096-16384/2048) = 4088 total allocation blocks, absent the reserved tracks
;  512 directory entries (Retro BIOS designer's choice)
;  512*32 = 16384 total bytes in the directory
;  ceiling(16384/2048) = 8 allocation blocks for the directory
;
;                  DSM<256   DSM>255
;  BLS  BSH BLM    ------EXM--------
;  1024  3    7       0         x
;  2048  4   15       1         0  <----------------------
;  4096  5   31       3         1
;  8192  6   63       7         3
; 16384  7  127      15         7
;
; ** NOTE: This filesystem design is inefficient because it is unlikely
;          that ALL of the allocation blocks will ultimately get used!
;
;##########################################################################

bios_dph:
	dw	0		            ; XLT sector translation table (no xlation done)
	dw	0		            ; scratchpad
	dw	0		            ; scratchpad
	dw	0		            ; scratchpad
	dw	bios_dirbuf 	    ; DIRBUF pointer
	dw	bios_dpb_a	        ; DPB pointer
	dw	0		            ; CSV pointer (optional, not implemented)
	dw	bios_alv_a	        ; ALV pointer

bios_dirbuf:
	ds	128		            ; scratch directory buffer

bios_dpb_a:
	dw	4		            ; SPT
	db	4		            ; BSH
	db	15		            ; BLM
	db	0		            ; EXM
	dw	4087	            ; DSM (max allocation block number)
	dw	511		            ; DRM
	db	$ff	                ; AL0
	db	$00	                ; AL1
	dw	0		            ; CKS
	dw	32		            ; OFF

bios_alv_a:
	ds	(4087/8)+1	        ; scratchpad used by BDOS for disk allocation info
bios_alv_a_end:

bios_sd_buf:
    ds  512, $a5

bios_stack_lo:
    ds  64, $55            ; 32 stack levels = 64 bytes 
bios_stack:                 ; full descending stack starts after the storage area

    dw  0                   ; just to make sure spacing for alv_a is done right.
    
    .if $ < BOOT
        .fail THE BIOS WRAPPED AROUND PAST 0xffff
    .endif

prog_end:   
        .end
