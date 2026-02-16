; Large portions of this code are copied from, or inspired by: 
;   John Winans' z80-retro-cpm project.  
;   Wayne Warthen's RomWBW project
; All of their Copyright is retained by original authors

        .include "z180.asm"
        .include "io.asm"

        .org     $0000                  ;Cold reset entry point
        
        ; reposition z180 control registers
        ld      a, Z180_BASE
        out0    ($3F), a         
        
        ;turn off DRAM Referesh and set zero states
        xor     a
        out0    (rcr_addr), a           ; set RCR to zero to disable DRAM refresh
        ;out0    (dcntl_addr), a        ; set DCNTL to zero to disable all wait states 
        ld      a, %11110000            ; set DCNTRL to 3 memory wait states and 3 IO wait states, 
                                        ; more conservative
        out0    (dcntl_addr), a        

        ; set clock speed and other basic initializations
        xor     a
        out0    (cmr_addr), a           ; set CMR to x1 mode
        out0    (ccr_addr), a           ; set CCR to default - normal drive, no standby 

        ld      sp, 0 

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
