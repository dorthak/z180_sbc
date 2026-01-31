; Large portions of this code are copied from, or inspired by: 
;   John Winans' z80-retro-cpm project.  
;   Wayne Warthen's RomWBW project
; All of their Copyright is retained by original authors

#include "init.asm"
#include "sio.asm"
#include "puts.asm"
#include "spi.asm"
#include "hexdump.asm"

prog_start:
    di                                      ; just in case
    call    con_init

    ld      hl, boot_msg
    call    puts
    call    puts_crlf

    call    spi_init

    ;call    test_80clks
    ;call    test_read
    ;call    test_write_byt
    ;call    test_ssel
    ;call    test_write_str

    call    test_80clks ; needed befroe running cmd0
    call    test_cmd0

    call    iputs
    defb    CR, LF, 'Tests Done', CR, LF, 0

    call    iputs
    defb    CR, LF, 'Halting', CR, LF, 0


halt_loop:
    halt
    jp      halt_loop


test_80clks:    call    iputs
                defb    'test_80clks', CR, LF, 0      
                
                ld      b, 10               ; 10 1-byte clock bursts
test_80clks_loop:
                call    spi_get
                ;call    blink
                djnz    test_80clks_loop
                ;call    blink
                ret

        
test_read:      call    iputs
                defb    'test_read', CR, LF, 0      
                call    iputs
                defb    'A=0x', 0

                call    spi_get              ; get one byte from SPI

                call    hexdump_a
                call    puts_crlf

                ret

test_write_byt: call    iputs
                defb    'test_write_byt', CR, LF, 0    
                call    iputs
                defb    'Byte=0x', 0
                
                ld      d, $F5
                ld      a, d
                call    hexdump_a
                call    puts_crlf

                call    spi_ssel_true

                ld      c, d

                call    spi_put
                call    spi_ssel_false
                ret  

test_ssel:      call    iputs
                defb    'test_ssel', CR, LF, 0    

                call    spi_ssel_true
                call    blink
                call    spi_ssel_false

                ret


test_write_str: call    iputs
                defb    'test_write_str', CR, LF, 0      

                ld      hl, write_test1                 ; buffer address
                ld      bc, 4                           ; buffer size
                ld      e, 0                            ; no fancy formatting

                call    hexdump

                call   spi_ssel_true

                ld      hl, write_test1
                ld      bc, 4
                call    spi_write_str

                call   spi_ssel_false
                ret

test_cmd0:      call    iputs
                defb    'test_cmd0', CR, LF, 0    
                
                call   spi_ssel_true  

                call    iputs
                defb    'CMD0=', 0

                ld      hl, test_cmd0_msg       ; buffer address
                ld      bc, 6                   ; buffer size
                ld      e, 0                    ; no fancy formatting

                call    hexdump

                ; send CMD0 mesage
                ld      hl, test_cmd0_msg
                ld      c, 0
                ld      b, 6
                call    spi_write_str

                ld      b, 0xf0                 ; may need to read multiple bytes befre SD resonds
test_cmd0_loop:
                push    bc                      ; save retry counter

                call    iputs
                defb    'R1=', 0

                call    spi_get
                push    af                      ; save response byte
                call    hexdump_a
                call    puts_crlf

                pop     af
                pop     bc

                and     $80                     ; is MSB 1? 

                ;cp      $01                     ; Is the R1 response $01?
                jr      z, test_cmd0_success    ; yes -> success

                djnz    test_cmd0_loop          ; R1 response is bad, but keep reading until B is zero

                call    iputs
                defb    'CMD0 failed after max retries', CR, LF, 0
                jp      test_cmd0_done


test_cmd0_success:
                call    iputs
                defb    'CMD0 success!', CR, LF, 0

test_cmd0_done:

                call    spi_ssel_false

                ret


test_cmd0_msg:
	        db	$40, $0, $0, $0, $0, $95



write_test1:    db      $01, $02, $80, $40


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
	defb	'Z180 SBC SPI test',CR, LF
        defb    '       git: @@GIT_VERSION@@', CR, LF
        defb    '     build: @@DATE@@', CR, LF
	defb	'##############################################################################',CR, LF
	defb	0

light_toggle:
        defb    0
; the prog_end label must be defined at the bottom of every program!
prog_end:   
        .end
