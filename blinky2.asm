#include "init.asm"
#include "io.asm"

; Copy ROM into RAM

        ld      hl, ramcode             ; start copying from the ramcode label
        ld      de, ram_start           ; copy to bottom of ram
        ld      bc, finish-ram_start      ; number of bytes to copy is equal to 
                                        ; the endof file less ram_start label
                                        ; since .org was used rather than .phase
        ldir
        jp      ram_start               ; switch execution to ram

        ; Starting here, running from RAM
ramcode:
        .phase  ram_start



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


finish:   
        .end
