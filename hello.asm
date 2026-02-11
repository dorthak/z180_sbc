; Large portions of this code are copied from, or inspired by: 
;   John Winans' z80-retro-cpm project.  
;   Wayne Warthen's RomWBW project
; All of their Copyright is retained by original authors

        .include "z180.asm"

        .org    LOAD_BASE               ; second stage load address
        ld      sp, LOAD_BASE           ; boot loader should have initialized SIO, SPI, etc.
        ld      de, 0

loop:   
        inc     de
        ld      a, d
        call    hexdump_a
        ld      a, e
        call    hexdump_a
        call    iputs
        defb    ': Hello from the SD Card!', CR, LF, 0      
        ld      hl, 0
delay:  
        dec     hl
        ld      a, h
        or      l
        jp      z, loop                 ;if done, go back and print again
        jp      delay



        .include 'hexdump.asm'
        .include 'sio.asm'
        .include 'puts.asm'