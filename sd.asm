; Large portions of this code are copied from, or inspired by: 
;   John Winans' z80-retro-cpm project.  
;   Wayne Warthen's RomWBW project
; All of their Copyright is retained by original authors

#include "spi.asm"

; To initialize an SDHC/SDXC card:
; - send at least 74 CLKs
; - send CMD0 & expect reply message = 0x01 (enter SPI mode)
; - send CMD8 (establish that the host uses Version 2.0 SD SPI protocol)
; - send ACMD41 (finish bringing the SD card on line)
; - send CMD58 to verify the card is SDHC/SDXC mode (512-byte block size)

;.sd_debug: equ 0
.sd_debug: equ 1

;############################################################################
; SSEL = HI (deassert)
; wait at least 1 msec after power up
; send at least 74 (80) SCLK rising edges
; Clobbers A, E
;############################################################################

sd_boot:
    ld      b, 10
.sd_boot_loop:
    call    spi_get
    djnz    .sd_boot_loop

    ret

;############################################################################
; Send a CMD0 (GO_IDLE) message and read an R1 response.
;
; CMD0 will
; 1) Establish the card protocol as SPI (if has just powered up.)
; 2) Tell the card the voltage at which we are running it.
; 3) Enter the IDLE state.
;
; Return the response byte in A.
; Clobbers A, E
;############################################################################
sd_cmd0:

    ld      hl, .sd_cmd0_buf    ; HL = command buffer
    ld      b, .sd_cmd0_len     ; B = command buffer length
    call    .sd_cmd_r1          ; send CMD0, A has result

#if .sd_debug
    push    af
    call    iputs
    db      'CMD0: ', 0
    ld      hl, .sd_cmd0_buf
    ld      bc, .sd_cmd0_len
    ld      e, 0
    call    hexdump
    call    iputs
    db      '  R1: ', 0
    pop     af
    push    af
    call    hexdump_a           ; dump the reply message
    call    puts_crlf
    pop     af
#endif

   ret

.sd_cmd0_buf:   db  0|0x40,0,0,0,0,0x94|0x01
.sd_cmd0_len:   equ $-.sd_cmd0_buf

;############################################################################
; Send a CMD8 (SEND_IF_COND) message and read an R7 response.
;
; Establish that we are squawking V2.0 of spec & tell the SD
; card the operating voltage is 3.3V.  The reply to CMD8 should
; be to confirm that 3.3V is OK and must echo the 0xAA back as
; an extra confirm that the command has been processed properly.
; The 0x01 in the byte before the 0xAA in the command buffer
; below is the flag for 2.7-3.6V operation.
;
; Establishing V2.0 of the SD spec enables the HCS bit in
; ACMD41 and CCS bit in CMD58.
;
; Clobbers A, E
; Return the 5-byte response in the buffer pointed to by DE.
; The response should be: 0x01 0x00 0x00 0x01 0xAA.
;############################################################################

sd_cmd8:
#if .sd_debug
    push    de                  ; PUSH response buffer address
#endif

    ; call	iputs
	; db	    CR, LF, 'Entering sd_cmd8', CR, LF, LF, 0

    ld      hl, .sd_cmd8_buf
    ld      b, .sd_cmd8_len
    call    .sd_cmd_r7


#if .sd_debug
    call    iputs
    db      'CMD8: ', 0
    ld      hl, .sd_cmd8_buf
    ld      bc, .sd_cmd8_len
    ld      e,0
    call    hexdump
    call    iputs
    db      '  R7: ', 0
    pop     hl                  ; POP buffer address
    ld      bc, 5
    ld      e, 0
    call    hexdump             ; dump the reply message
#endif
    
    ret
.sd_cmd8_buf:   db  8|0x40,0,0,0x01,0xaa,0x86|0x01
.sd_cmd8_len:   equ $-.sd_cmd8_buf 

;############################################################################
; Send a CMD58 message and read an R3 response.
; CMD58 is used to ask the card what voltages it supports and
; if it is an SDHC/SDXC card or not.
; Clobbers A, E
; Return the 5-byte response in the buffer pointed to by DE.
;############################################################################
sd_cmd58:
#if .sd_debug
    push    de                  ; PUSH buffer address
#endif

    ld      hl, .sd_cmd58_buf
    ld      b, .sd_cmd58_len
    call    .sd_cmd_r3

#if .sd_debug
    call    iputs
    db      'CMD58: ', 0
    ld      hl, .sd_cmd58_buf
    ld      bc, .sd_cmd58_len
    ld      e, 0
    call    hexdump
    call    iputs
    db      '  R3: ', 0
    pop     hl                  ; POP buffer address
    ld      bc,5
    ld      e,0
    call    hexdump             ; dump the reply message
#endif

    ret

.sd_cmd58_buf:  db  58|0x40,0,0,0,0,0x00|0x01
.sd_cmd58_len:  equ $-.sd_cmd58_buf


;############################################################################
; Send a CMD55 (APP_CMD) message and read an R1 response.
; CMD55 is used to notify the card that the following message is an ACMD
; (as opposed to a regular CMD.)
; Clobbers A, E
; Return the 1-byte response in A
;############################################################################
sd_cmd55:

    ld      hl, .sd_cmd55_buf   ; HL = buffer to write
    ld      b, .sd_cmd55_len   ; B = buffer byte count
    call    .sd_cmd_r1          ; write buffer, A = R1 response byte

#if .sd_debug
    push    af
    call    iputs
    db      'CMD55: ', 0
    ld      hl, .sd_cmd55_buf
    ld      bc, .sd_cmd55_len
    ld      e, 0
    call    hexdump
    call    iputs
    db      '  R1: ', 0
    pop     af
    push    af
    call    hexdump_a           ; dump the response byte
    call    puts_crlf
    pop     af
#endif

    ret

.sd_cmd55_buf:  db  55|0x40,0,0,0,0,0x00|0x01
.sd_cmd55_len:  equ $-.sd_cmd55_buf

;############################################################################
; Send a ACMD41 (SD_SEND_OP_COND) message and return an R1 response byte in A.
;
; The main purpose of ACMD41 to set the SD card state to READY so
; that data blocks may be read and written.  It can fail if the card
; is not happy with the operating voltage.
;
; Clobbers A, E
; Note that A-commands are prefixed with a CMD55.
;############################################################################
sd_acmd41:
    call    sd_cmd55            ; send the A-command prefix

    ld      hl, .sd_acmd41_buf  ; HL = command buffer
    ld      b, .sd_acmd41_len  ; BC = buffer byte count
    call    .sd_cmd_r1

#if .sd_debug
    push    af
    call    iputs
    db      'ACMD41: ', 0
    ld      hl, .sd_acmd41_buf
    ld      bc, .sd_acmd41_len
    ld      e, 0
    call    hexdump
    call    iputs
    db      '   R1: ', 0
    pop     af
    push    af
    call    hexdump_a           ; dump the status byte
    call    puts_crlf
    pop     af
#endif

    ret
  
; SD spec p263 Fig 7.1 footnote 1 says we want to set the HCS bit here for HC/XC cards.
; Notes on Internet about setting the supply voltage in ACMD41. But not in SPI mode?
; The folowing works on my MicroCenter SDHC cards:

.sd_acmd41_buf: db  41|0x40,0x40,0,0,0,0x00|0x01    ; Note the HCS flag is set here
.sd_acmd41_len: equ $-.sd_acmd41_buf

;############################################################################
; Send a command and read an R1 response message.
; HL = command buffer address
; B = command byte length
; Clobbers A, E
; Returns A = reply message byte
;
; Modus operandi
; SSEL = LO (assert)
; send CMD
; send arg 0
; send arg 1
; send arg 2
; send arg 3
; send CRC
; wait for reply (MSB=0)
; read reply
; SSEL = HI
;############################################################################

.sd_cmd_r1:
    ; assert the SSEL line
    call    spi_ssel_true       ; Does not clobber hl or bc

    ; write a sequence of bytes represending the CMD message
    call    spi_write_str       ; write B bytes from HL buffer @

    ; read the R1 response message
    call    .sd_read_r1         ; A = E = message response byte

    push af                     ; Save response byte

    ; de-assert the SSEL line
    call    spi_ssel_false      ; This blows up a

    pop af                      ; Restore response byte

    ret

;############################################################################
; Send a command and read an R7 response message.
; Note that an R3 response is the same size, so can use the same code.
; HL = command buffer address
; B = command byte length
; DE = 5-byte response buffer address
; Clobbers A, E
;############################################################################

.sd_cmd_r3:
.sd_cmd_r7:
    call    spi_ssel_true       ; Doesn't clobber hl or bc

    push    de                  ; save the response buffer @
    call    spi_write_str       ; write cmd buffer from HL, length=BC

    ; read the response message into buffer @ in HL
    pop     hl                  ; pop the response buffer @ HL
    call    .sd_read_r7

    ; de-assert the SSEL line
    call    spi_ssel_false

    ret



;############################################################################
; NOTE: Response message formats in SPI mode are different than in SD mode.
;
; Read bytes until we find one with MSB = 0 or bail out retrying.
; Return last read byte in A (and a copy also in E)
; Calls spi_read8 (see for clobbers)
; Clobbers A, B
;############################################################################

.sd_read_r1:



    push    hl
    ld      b, $f0          ; B = number of retries

.sd_r1_loop:
    call    spi_get         ; read a byte into A 
    ld      e, a            ; save a copy in E
; COMMENT or 0x80 and test for minus sign, then no need to ld a from e later?

    and     0x80            ; Is the MSB set to 1?
    jr      z, .sd_r1_done  ; If MSB=0 then we are done

    djnz    .sd_r1_loop     ; else try again until the retry count runs out

.sd_r1_done:
    
    ; call    iputs
    ; defb    ".sd_read_r1 response = ", 0

    ; ld      a, e            ; copy the final value into A
    ; call    hexdump_a
    ; call    puts_crlf
    ld      a, e
    
    pop     hl

    ret




;############################################################################
; NOTE: Response message formats in SPI mode are different than in SD mode.
;
; Read an R7 message into the 5-byte buffer pointed to by HL.
; Clobbers HL, A, and E
;############################################################################

.sd_read_r7:
    call    .sd_read_r1     ; A = byte #1
    ld      (hl), a         ; save it
    inc     hl              ; advance receive buffer pointer

    ld      b, 4
    call    spi_read_str

    ret
