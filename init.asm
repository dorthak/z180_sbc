
;###########
; z180 initialization at start
;###########

        #include "z180.asm"

        .org     $0000                  ;Cold reset entry point
        
        ; reposition z180 control registers
        ld      a, Z180_BASE
        out0    ($3F), a         
        
        ;turn off DRAM Referesh and set zero states
        ld      a, 0
        out0    (rcr_addr), a           ; set RCR to zero to disable DRAM refresh
        out0    (dcntl_addr), a         ; set DCNTL to zero to disable all wait states 
