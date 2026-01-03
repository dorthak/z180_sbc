#include "init.asm"
#include "io.asm"

loop:
        xor     a                       ; Turn LED on (active low)
        out0    (status_led_addr), a
        ld      hl, $0000

dly1:
        dec     hl
        ld      a, h
        or      l
        jp      nz, dly1

        ld      a, status_enable_bit    ; Tuirn LED off
        out0    (status_led_addr), a
        ld      hl, $0000

dly2:
        dec     hl
        ld      a, h
        or      l
        jp      nz, dly2

        jp loop

        .end
