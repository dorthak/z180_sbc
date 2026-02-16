; Large portions of this code are copied from, or inspired by: 
;   John Winans' z80-retro-cpm project.  
;   Wayne Warthen's RomWBW project
; All of their Copyright is retained by original authors

    .include "init.asm"
    .include "sio.asm"
    .include "puts.asm"
    .include "sd.asm"
    .include "hexdump.asm"


debug: .equ 1

boot_rom_version:	.equ	1
load_blks:	.equ	(0x10000-LOAD_BASE)/512

prog_start:
    di                                      ; just in case
    call    con_init
    call    spi_init

    ld      hl, boot_msg
    call    puts
    call    puts_crlf

    call    boot_sd

    call    iputs
    asciiz  "\r\nIf we got here, system didn't load from SD Card. Fail.\r\n"


halt_loop:
    halt
    jp      halt_loop


;##############################################################################
; Load 16K from the first blocks of partition 1 on the SD card into
; memory starting at 'LOAD_BASE' and jump to it.
; If reading the SD card should fail then this function will return.
;
; TODO: Sanity-check the partition type, size and design some sort of 
; signature that can be used to recognize the SD card partition as viable.
;##############################################################################

boot_sd:
    call	iputs
	asciiz	'\r\nBooting SD card partition 1\r\n\r\n'
    ;call	iputs
	;db	    CR, LF, 'Entering boot_sd (80 clocks and CMD0)', CR, LF, LF, 0

    call    sd_boot                         ; send 74+Clks

    call    sd_cmd0                         ; response should be 0x01
    cp      $01
    jr      z, boot_sd_1
    
    call	iputs                           ; otherwise, there's an error
	asciiz  "\r\nError: Can't read SD card, (cmd0 command status isn't idle)\r\n\r\n"
    ret

boot_sd_1:
    .ifdef debug
    call	iputs
	asciiz  '\r\nEntering boot_sd_1 (CMD8)\r\n\r\n'
    .endif

    ld      de, LOAD_BASE                   ; temporary buffer
    call    sd_cmd8                         ; CMD9 sent to verify SD card version and voltage

	; The response should be: 0x01 0x00 0x00 0x01 0xAA.
	ld	    a, (LOAD_BASE)
	cp	    1
	jr	    z, boot_sd_2

    call	iputs                           ; otherwise, there's an error
	asciiz  "\r\nError: Can't read SD card, (cmd8 command status not valid)\r\n\r\n"

	; dump the command response buffer
	ld	    hl, LOAD_BASE	                ; dump bytes from here
	ld	    e, 0		                    ; no fancy formatting
	ld	    bc, 5		                    ; dump 5 bytes
	call	hexdump
	call	puts_crlf
    ret

boot_sd_2:
    .ifdef debug
    call	iputs
	asciiz	'\r\nEntering boot_sd_2 (ACMD41)\r\n\r\n'
    .endif

.ac41_max_retry: .equ	$80		            ; limit the number of ACMD41 retries to 128

	ld	    b, .ac41_max_retry
.ac41_loop:
	push	bc			                    ; save BC since B contains the retry count 
	ld	    de, LOAD_BASE		            ; store command response into LOAD_BASE
	call	sd_acmd41		                ; ask if the card is ready
	pop	    bc			                    ; restore our retry counter
	or	    a			                    ; check to see if A is zero
	jr	    z, .ac41_done		            ; is A is zero, then the card is ready

	; Card is not ready, waste some time before trying again
	ld	    hl, $1000		                ; count to 0x1000 to consume time
.ac41_dly:
	dec	    hl			                    ; HL = HL -1
	ld	    a, h			                ; does HL == 0?
	or	    l
	jr	    nz,.ac41_dly		            ; if HL != 0 then keep counting

	djnz	.ac41_loop		                ; if (--retries != 0) then try again

.ac41_fail:
	call	iputs
	asciiz  'Error: Can not read SD card (ac41 command failed)\r\n\r\n'
	ret

.ac41_done:
    .ifdef  debug
	call    iputs
	asciiz  '** Note: Called ACMD41 0x'
	ld	    a,.ac41_max_retry
	sub	    b
	inc	    a			                    ; account for b not yet decremented on last time
	call	hexdump_a
	call	iputs
	asciiz  ' times.\r\n\r\n'



    call	iputs
	asciiz  '\r\nExiting ac41_done (CMD58)\r\n'

    .endif

	; Find out the card capacity (SDHC or SDXC)
	; This status is not valid until after ACMD41.
	ld	    de, LOAD_BASE
	call	sd_cmd58

    .ifdef  debug
	call	iputs
	asciiz  '** Note: Called CMD58: R3: '
	ld	    hl, LOAD_BASE
	ld	    bc, 5
	ld	    e, 0
	call	hexdump							; dump the response message from CMD58
    .endif

	; Check that CCS=1 here to indicate that we have an HC/XC card
	ld		a, (LOAD_BASE+1)
	and		0x40							; CCS bit is here (See SD spec p275)
	jr		nz, .boot_hcxc_ok

	call	iputs
	asciiz  '\r\nError: SD card capacity is not SDHC or SDXC.\r\n\0'
	ret


.boot_hcxc_ok:

    ; READ THE MBR

    .ifdef debug
    call	iputs
	asciiz  '\r\nEntering hcxc_ok (CMD17) - read MBR\r\n\r\n'
    .endif


	ld		hl, 0							; SD card block number to read
	push	hl								; high half
	push	hl								; low half
	ld		de, LOAD_BASE					; where to read the sector data into
	call	sd_cmd17
	pop		hl								; remove the block number from the stack
	pop		hl

	or		a
	jr		z, .boot_cmd17_ok				; if CMD17 ended OK then run the code

	call	iputs
	asciiz	'\r\nError: SD card CMD17 failed to read block zero.\r\n\r\n'
	ret

.boot_cmd17_ok:

    .ifdef debug
	call	iputs
	asciiz	'\r\nThe block has been read!\r\n'

    call	iputs
	asciiz  '\r\nPartition Table:\r\n'

    ld	    hl, LOAD_BASE+0x01BE	        ; address of the first partiton entry
	ld	    e, 0			                ; no fancy formatting
	ld	    bc, 16  	                    ; dump 16 bytes
	call	hexdump

	ld	    hl, LOAD_BASE+0x01CE	        ; address of the second partiton entry
	ld	    e, 0			                ; no fancy formatting
	ld	    bc, 16			                ; dump 16 bytes
	call    hexdump

	ld	    hl, LOAD_BASE+0x01DE	        ; address of the third partiton entry
	ld	    e, 0			                ; no fancy formatting
	ld	    bc, 16			                ; dump 16 bytes
	call    hexdump

	ld	    hl, LOAD_BASE+0x01EE	        ; address of the fourth partiton entry
	ld	    e, 0			                ; no fancy formatting
	ld	    bc, 16			                ; dump 16 bytes
	call	hexdump

    .endif

; XXX validate that we really HAVE an MBR and that it looks OK to boot! XXX

	; Find the geometry of the first partition record:
	ld	    ix, LOAD_BASE+0x01BE+0x08

	call	iputs
	asciiz	'\nPartition 1 starting block number: '
	ld	    a, (ix+3)
	call	hexdump_a
	ld	    a, (ix+2)
	call	hexdump_a
	ld	    a, (ix+1)
	call	hexdump_a
	ld	    a, (ix+0)
	call	hexdump_a
	call	puts_crlf

	call	iputs
	asciiz	'Partition 1 number of blocks:      '
	ld	    a, (ix+7)
	call	hexdump_a
	ld	    a, (ix+6)
	call	hexdump_a
	ld	    a, (ix+5)
	call	hexdump_a
	ld	    a, (ix+4)
	call	hexdump_a
	call	puts_crlf

	; ############ Read the first sectors of the first partition ############
	ld	    ix, LOAD_BASE + 0x01BE + 0x08
	ld	    d, (ix+3)
	ld	    e, (ix+2)
	push	de
	ld	    d, (ix+1)
	ld	    e, (ix+0)
	push	de
    ld	    de, LOAD_BASE		            ; where to read the sector data into
	ld	    b, load_blks		            ; number of blocks to load (should be 32/16KB)

    .ifdef  debug
    ; Print the details of what we are going to load and where it will go
	call	iputs
	asciiz	'\nLoading 0x'
	ld	    a, b
	call	hexdump_a
	call	iputs
	asciiz	' 512-byte blocks into 0x'
	ld	    a, d
	call	hexdump_a
	ld	    a, e
	call	hexdump_a
	call	iputs
	asciiz	' - 0x'

	; Calculate the ending address of the load area
	ld	    hl, LOAD_BASE
	ld	    a, load_blks
	add	    a
	ld	    b, a
	ld	    c, 0
	dec	    bc
	add	    hl, bc
	ld	    a, h
	call	hexdump_a
	ld	    a, l
	call	hexdump_a
	call	puts_crlf

	; re-load these if the debug logic messed them up
	ld	    de, LOAD_BASE		            ; where to read the sector data into
	ld	    b, load_blks		            ; number of blocks to load (should be 32/16KB)

    .endif

    call    read_blocks
	pop	    hl			                    ; Remove the 32-bit block number from the stack.
	pop	    de

	ld	    c, 1			                ; XXX note we booted from partition #1

	or	    a
	ld	    a, boot_rom_version
	jp	    z, LOAD_BASE		            ; Run the code that we just read in from the SD card.

	call	iputs
	asciiz	'Error: Could not load O/S from partition 1.\r\n'
	ret

;############################################################################
;### Read B number of blocks into memory at address DE starting with
;### 32-bit little-endian block number on the stack.
;### Return A=0 = success!
;############################################################################
read_blocks:
					                        ; +12 = starting block number
					                        ; +10 = return @
	push	bc			                    ; +8
	push	de			                    ; +6
	push	iy			                    ; +4

	ld	    iy, -4                          ; make space for 4 more bytes on the stack
	add	    iy, sp			                ; iy = &block_number
	ld	    sp, iy

	; copy the first block number 
	ld	    a, (iy+12)
	ld	    (iy+0), a
	ld	    a, (iy+13)
	ld	    (iy+1) ,a
	ld	    a, (iy+14)
	ld	    (iy+2) ,a
	ld	    a, (iy+15)
	ld	    (iy+3) ,a

	;call	spi_read8f_init for the 8f version of CMD17

.read_block_n:

    .if 1
	ld	    c, '.'
	call	con_tx_char
    .endif

    .ifdef debug
	call	iputs
	asciiz	'Read Block: '

	ld	    a, (iy+3)
	call	hexdump_a
	ld	    a, (iy+2)
	call	hexdump_a
	ld	    a, (iy+1)
	call	hexdump_a
	ld	    a, (iy+0)
	call	hexdump_a
	call	puts_crlf
    .endif

	; SP is currently pointing at the block number
	call	sd_cmd17
	or	    a
	jr	    nz, .rb_fail                     ; note that a=0 here = success!

	; count the block
	dec	    b
	jr	    z, .rb_success		           

	; increment the target address by 512
	inc	    d
	inc	    d

	; increment the 32-bit block number
	inc	    (iy+0)
	jr	    nz, .read_block_n
	inc	    (iy+1)
	jr	    nz, .read_block_n
	inc	    (iy+2)
	jr	    nz,.read_block_n
	inc	    (iy+3)
	jr	    .read_block_n

.rb_success:
	xor	    a

.rb_fail:
	ld	    iy, 4                               ; Restore stack to where it was
	add	    iy, sp
	ld	    sp, iy
	pop	    iy
	pop	    de
	pop	    bc
	ret




boot_msg:
	defb    '\r\n\r\n'
	defb	'##############################################################################\r\n'
	defb	'Z180 SBC Flash Boot loader 0.1\r\n'
    defb    '       git: @@GIT_VERSION@@\r\n'
    defb    '     build: @@DATE@@\r\n'
	defb	'##############################################################################\r\n'
	


; the prog_end label must be defined at the bottom of every program!
prog_end:   
        .end
