#include "init.asm"
#include "sio.asm"
#include "puts.asm"
#include "spi.asm"

prog_start:
    di                                      ; just in case
    call    con_init

    ld      hl, boot_msg
    call    puts
    call    puts_crlf

    call    spi_init

    call    test_80clks


    call    iputs
    defb    CR, LF, 'Tests Done', CR, LF, 0

    call    iputs
    defb    CR, LF, 'Halting', CR, LF, 0


halt_loop:
    halt
    jp      halt_loop


test_80clks:    ld      b, 10               ; 10 1-byte clock bursts
test_80clks_loop:
                call    spi_get
                ;call    blink
                djnz    test_80clks_loop
                call    blink
                call    blink
                call    blink
                call    blink
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
	defb    CR, LF, LF
	defb	'##############################################################################',CR, LF
	defb	'Z180 SBC SPI test',CR, LF
	defb	'##############################################################################',CR, LF
	defb	0

light_toggle:
        defb    0
; the prog_end label must be defined at the bottom of every program!
prog_end:   
        .end
