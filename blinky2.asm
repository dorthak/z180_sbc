#include "init.asm"
#include "io.asm"

loop:
        xor     a                       ; Turn LED on (active low)
        out0    (status_led_addr), a
        
        call delay

        ld      a, status_enable_bit    ; Tuirn LED off
        out0    (status_led_addr), a

        call delay

        jp loop

; DELAY function
delay:
        ld hl, $8000
dloop:
        dec     hl
        ld      a, h
        or      l
        jp      nz, dloop
        ret



; the finish label must be defined at the bottom of every program!
finish:   
        .end
