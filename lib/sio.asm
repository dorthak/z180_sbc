; Large portions of this code are copied from, or inspired by: 
;   John Winans' z80-retro-cpm project.  
;   Wayne Warthen's RomWBW project
; All of their Copyright is retained by original authors

;###########
; Drivers for the Serial IO port
;###########

        ;.include "z180.asm"
        .include "io.asm"

;###########
; Return NZ if sio a(0) is ready to transmit
; Affects: AF
;###########

con_tx_ready:
sio0_tx_ready:
        in0      a,(STAT0)      ; read sio control status byte
        and     $02             ; Bit 1 needs to be 1 if ready to transmit
        ret


;###########
; Return NZ if sio b(1) is ready to transmit
; Affects: AF
;###########

sio1_tx_ready:
        in0      a,(STAT1)      ; read sio control status byte
        and     $02             ; Bit 1 needs to be 1 if ready to transmit
        ret


;###########
; Return NZ  (A=1) if sio 0 is ready to recieve
; Affects: AF
;###########

con_rx_ready:
sio0_rx_ready:
        ; hack to clear overrun errors
        in0     a, (CNTLA0)     ; get current sio control A value
        res     3, a            ; reset bit 3 (EFT) to 0
        out0    (CNTLA0), A

        in0     a, (STAT0)      ; read sio status register
        and     $80             ; check if top bit is zero, this sets the nz flag
        ret
        



;###########
; Return NZ  (A=1) if sio b(1) is ready to recieve
; Affects: AF
;###########

sio1_rx_ready:
        ; hack to clear overrun errors
        in0     a, (CNTLA1)     ; get current sio control A value
        res     3, a            ; reset bit 3 (EFT) to 0
        out0    (CNTLA1), A

        in0     a, (STAT1)      ; read sio status register
        and     $80             ; check if top bit is zero, this sets the nz flag
        ret
        
;###########
; Affects: AF
;###########

con_init:
sio0_init:
        ld      a, 01100100B    ; rcv enable, xmit enable, no parity, 7/N/1
        out0    (CNTLA0), a

        ld      a, 00000000B    ; div 10, div 16, div2 18432000/1/1/10/16/2 = 57600 
        out0    (CNTLB0), a
        
        ld      a, 01100110B    ; no cts, no dcd, no break detect
        out0    (ASEXT0), a

        xor     a               ; reset status register
        out0    (STAT0), a      
        
        ret

sio1_init:
        ld      a, 01100100B    ; rcv enable, xmit enable, no parity
        out0    (CNTLA1), a

        ld      a, 00000000B    ; div 10, div 16, div2 18432000/1/1/10/16/2 = 57600 
        out0    (CNTLB1), a
        
        ld      a, 01100110B    ; no cts, no dcd, no break detect
        out0    (ASEXT1), a

        xor     a               ; reset status register
        out0    (STAT1), a      
        
        ret


        
;###########
; Ptint the char in C register
; Affects: AF
;###########

con_tx_char:
sio0_tx_char:
        call    sio0_tx_ready   ; check if transmitter is ready
        jr      z, sio0_tx_char ; a zero indicates not ready, so loop until it is

        ld      a, c
        out0    (TDR0), a       ; send character

        ret


sio1_tx_char:
        call    sio1_tx_ready   ; check if transmitter is ready
        jr      z, sio1_tx_char ; a zero indicates not ready, so loop until it is

        ld      a, c
        out0    (TDR1), a       ; send character

        ret


;###########
; Wait for data to be available and then return it in the A register
; Affects: AF
;###########

con_rx_char:
sio0_rx_char:
        call    sio0_rx_ready   ; check if a byte is available
        jr      z, sio0_rx_char ; a zero indicates nothing available, so loop until it is

        in0     a, (RDR0)       ; get byte of data

        ret

sio1_rx_char:
        call    sio1_rx_ready   ; check if a byte is available
        jr      z, sio1_rx_char ; a zero indicates nothing available, so loop until it is

        in0     a, (RDR1)       ; get byte of data

        ret


