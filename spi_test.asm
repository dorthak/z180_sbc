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
    call    test_write_str


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

                ld      c, $55
                call    spi_put

                ret  



test_write_str: call    iputs
                defb    'test_write_str', CR, LF, 0      

                ld      hl, write_test1                 ; buffer address
                ld      bc, 4                           ; buffer size
                ld      e, 0                            ; no fancy formatting

                call    hexdump

                ; call   spi_ssel_true

                ld      hl, write_test1
                ld      bc, 4
                call    spi_write_str

                ; call   spi_ssel_false
                ret



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
