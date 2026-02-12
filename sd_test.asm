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
;debug: equ 1


prog_start:
    di                                      ; just in case
    call    con_init
    call    spi_init

    ld      hl, boot_msg
    call    puts
    call    puts_crlf

    call    test_sd

    call    iputs
    defb    CR, LF, "If we got here, system didn't load from SD Card. Fail.", CR, LF, 0


halt_loop:
    halt
    jp      halt_loop


test_sd:
    call	iputs
	db	    CR, LF, 'Reading SD card block zero', CR, LF, LF, 0
    call	iputs
	db	    CR, LF, 'Entering test_sd (80 clocks and CMD0)', CR, LF, LF, 0

    call    sd_boot                         ; send 74+Clks

    call    sd_cmd0                         ; response should be 0x01
    cp      $01
    jr      z, boot_sd_1
    
    call	iputs                           ; otherwise, there's an error
	db	    CR, LF, "Error: Can't read SD card, (cmd0 command status isn't idle)", CR, LF, LF, 0
    ret

boot_sd_1:
    call	iputs
	db	    CR, LF, 'Entering boot_sd_1 (CMD8)', CR, LF, LF, 0

    ld      de, LOAD_BASE                   ; temporary buffer
    call    sd_cmd8                         ; CMD9 sent to verify SD card version and voltage

	; The response should be: 0x01 0x00 0x00 0x01 0xAA.
	ld	    a, (LOAD_BASE)
	cp	    1
	jr	    z, boot_sd_2

    call	iputs                           ; otherwise, there's an error
	db	    CR, LF, "Error: Can't read SD card, (cmd8 command status not valid)", CR, LF, LF, 0

	; dump the command response buffer
	ld	    hl, LOAD_BASE	                ; dump bytes from here
	ld	    e, 0		                    ; no fancy formatting
	ld	    bc, 5		                    ; dump 5 bytes
	call	hexdump
	call	puts_crlf
    ret

boot_sd_2:
    call	iputs
	db	    CR, LF, 'Entering boot_sd_2 (ACMD41)', CR, LF, LF, 0


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
	db	    'Error: Can not read SD card (ac41 command failed)', CR, LF, LF, 0
	ret

.ac41_done:
	.ifdef debug
	call    iputs
	db	    '** Note: Called ACMD41 0x', 0
	ld	    a,.ac41_max_retry
	sub	    b
	inc	    a			                    ; account for b not yet decremented on last time
	call	hexdump_a
	call	iputs
	db	    ' times.', CR, LF, LF, 0
	.endif


    call	iputs
	db	    CR, LF, 'Exiting ac41_done (CMD58)', CR, LF, LF, 0

	; Find out the card capacity (SDHC or SDXC)
	; This status is not valid until after ACMD41.
	ld	    de, LOAD_BASE
	call	sd_cmd58

	.ifdef debug
	call	iputs
	db	    '** Note: Called CMD58: R3: ', 0
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
	db	'Error: SD card capacity is not SDHC or SDXC.\r\n\0'
	ret


.boot_hcxc_ok:
    call	iputs
	db	    CR, LF, 'Entering hcxc_ok (CMD17)', CR, LF, LF, 0

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
	db		'Error: SD card CMD17 failed to read block zero.', CR, LF, 0
	ret

.boot_cmd17_ok:

	.ifdef debug
	call	iputs
	db		'The block has been read!', CR, LF, 0

	ld		hl, LOAD_BASE					; Dump the block we read from the SD card
	ld		bc, 0x200						; 512 bytes to dump
	ld		e, 1							; and make it all all purdy like
	call	hexdump
	.endif

	jp		LOAD_BASE						; Go execute what ever came from the SD card


    ret

;###########
; Delay for a hardcoded time period.
; Affects: AF, HL
;###########

delay:  ld hl, $4000
dloop:
        dec     hl
        ld      a, h
        or      l
        jp      nz, dloop
        ret


;###########
; Blink the SD card light.
; Affects: Nothing
;###########

blink:  push    af
        push    hl
        xor     a                       ; Turn LED on (active low)
        out0    (status_led_addr), a
        call delay
        ld      a, status_enable_bit    ; Tuirn LED off
        out0    (status_led_addr), a
        call delay
        pop     hl
        pop     af
        ret

;###########
; Flips the SD card light.
; Affects: Nothing
;###########

half_blink:  push    af
        ld      a, (light_toggle)
        xor     a, status_enable_bit
        ld      (light_toggle), a
        out0    (status_led_addr), a
        pop     af
        ret



boot_msg:
	defb    CR, LF, CR, LF
	defb	'##############################################################################',CR, LF
	defb	'Z180 SBC SD test',CR, LF
    defb    '       git: @@GIT_VERSION@@', CR, LF
    defb    '     build: @@DATE@@', CR, LF
	defb	'##############################################################################',CR, LF
	defb	0

light_toggle:
        defb    0
; the prog_end label must be defined at the bottom of every program!
prog_end:   
        .end
