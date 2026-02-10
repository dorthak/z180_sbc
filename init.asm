; Large portions of this code are copied from, or inspired by: 
;   John Winans' z80-retro-cpm project.  
;   Wayne Warthen's RomWBW project
; All of their Copyright is retained by original authors

;###########
; z180 initialization at start
;###########

#include "z180.asm"

        .org     $0000                  ;Cold reset entry point
        
        ; reposition z180 control registers
        ld      a, Z180_BASE
        out0    ($3F), a         
        
        ;turn off DRAM Referesh and set zero states
        xor     a
        out0    (rcr_addr), a           ; set RCR to zero to disable DRAM refresh
        out0    (dcntl_addr), a        ; set DCNTL to zero to disable all wait states 
        ;ld      a, %11110000            ; set DCNTRL to 3 memory wait states and 3 IO wait states, 
                                        ; more conservative
        ;out0    (dcntl_addr), a        

        ; set clock speed and other basic initializations
        xor     a
        out0    (cmr_addr), a           ; set CMR to x1 mode
        out0    (ccr_addr), a           ; set CCR to default - normal drive, no standby 

        ; set up MMU - bottom 512k of physical memory is ROM, top 512k is RAM 
        ; top 32k of logical memory is top 32k of physical RAM
        ; bottom 32k of logical memory is banked, left as bottom of ROM at start

        ld      a, $80                  ; first 4 bits set logical bottom of common
                                        ; area 1 (and top of banked area) to 32k 
                                        ; bottom 4 bits set bottom of banked area
                                        ; to 0.  No common area 0.
        out0    (cbar_addr), a

        ld      a, +(1024-64) >> 2      ; set physical address of common area 1.
                                        ; The register is in 4Kb chunks.  ">> 2"
                                        ; converts 1Kb value to 4Kb chunks.
                                        ; Total physical memory size is 1Mb - 1024Kb
                                        ; Since the entire logical memory needs to be 
                                        ; mapped onto the physical memory, we need to
                                        ; offset by 64k, not just the 32k that is 
                                        ; actually Common Area 1
        out0    (cbr_addr), A

        ; Set up stack
        ld      sp, stack_top 
          

; Copy ROM into RAM

        ld      hl, ramcode             ; start copying from the ramcode label
        ld      de, ram_start           ; copy to bottom of ram
        ld      bc, prog_end-ram_start  ; number of bytes to copy is equal to 
                                        ; the endof file less ram_start label
                                        ; since .org was used rather than .phase
        ldir
        jp      prog_start              ; switch execution to ram

        ; Starting here, running from RAM
ramcode:
        .org  ram_start

; the prog_start and prog_end label must be defined at the bottom of every program!
