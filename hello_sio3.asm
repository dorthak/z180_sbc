; Test SIO1

#include "init.asm"
#include "sio.asm"
#include "puts.asm"

prog_start:

        call    sio0_init
        call    sio1_init

        call    helloa

        call    blink
        call    blink
        call    blink

        jp      echo_loop


; Echo character back to SIO, adding one

echo_loop:
        call    sio0_rx_char   ; get char from serial
        ld      c, a
        inc     c               ; add 1
        call    blink
        call    sio0_tx_char   ; print it
        jp      echo_loop


; HELLO A function
helloa:
        ld      hl, message
        call    puts
        call    puts_crlf
        ret
        
;###########
; Delay for a hardcoded time period.
; Affects: AF, HL
;###########

delay:
        ld hl, $4000
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

blink:
        push    af
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

message:
        .asciz "Hello, World"

; the prog_end label must be defined at the bottom of every program!
prog_end:   
        .end
