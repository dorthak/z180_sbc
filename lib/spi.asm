; Large portions of this code are copied from, or inspired by: 
;   John Winans' z80-retro-cpm project.  
;   Wayne Warthen's RomWBW project
; All of their Copyright is retained by original authors

    ;.include "io.asm"

spi_init:       ld          a, 6                ; div by 1280 - 14KHz @18MHz clock?
;spi_init:       ld          a, 3                ; div by 160 - 112KHz @18MHz clock?
;spi_init:       ld          a, 2                ; div by 80 - 224KHz @18MHz clock? or 400kHz @ phi = 4MHz?
;spi_init:       ld          a, 0                ; div by 20 - 896KHz @18MHz clock? or 1600kHz @ phi = 4MHz?
                out0        (CNTR), a

                ld          a, sd_enable_bit    ; SD Enable is active low, so set high at init
                ld          (spi_ssel_cache), a ; Set cache
                out0        (sd_enable_addr), a ; and write out to harware
                ret


; Increase SPI speed after SD card initialization.
; Clobbers AF
spi_gofast:    
                ld          a, 0                ; div by 20 - 896KHz @18MHz clock? or 1600kHz @ phi = 4MHz?
                out0        (CNTR), a
 

; Send byte in C
; Clobbers AF
spi_put:        push        bc
                call        spi_waittx          ; check if done sending
                ld          a, c                ; 
                call        mirror              ; MSB<->LSB, result in C.

                out0        (TRDR), c
                in0         a, (CNTR)
                set         4, a                ; Set transmit enable
                out0        (CNTR), a
                pop         bc
                ret


; get one byte, return in A 
; clobbers AF
spi_get:        push        bc
                call        spi_waittx          ; make sure we aren't sending
                ;call        spi_waitrx          ; make sure we aren't recieving

                in0         a, (CNTR)           
                set         5, a                ; Start receiver
                out0        (CNTR), a

                call        spi_waitrx
                in0         a, (TRDR)           ; Get the byte
                call        mirror              ; MSB<->LSB, result in A.
                pop         bc                  ; because mirror clobbers BC
                ret

; Check if SPI TX is ready
; Clobbers AF
spi_waittx:     in0         a, (CNTR)
                bit         4, a                ; TX empty?
                jr          nz, spi_waittx      
                ret


; Check if SPI RX is ready
; Clobbers AF
spi_waitrx:     in0         a, (CNTR)
                bit         5, a                ; RX empty?
                jr          nz, spi_waitrx      
                ret


; Write multi-byte string
; hl had buffer pointer
; bc has count

spi_write_str:  push        af
                push        de
                push        bc
                push        hl                  ; end protection of registers

spi_wr_str_lp:  
                push        bc                  ; preserve count for loop
                ld          c, (hl)             ; fetch byte from write buffer
                inc         hl                  ; advance buffer pointer
                call        spi_put             ; send byte in c to spi
                pop         bc                  ; restore loop counter
                dec         bc
                ld          a, b
                or          c                   ; or's two halves of BC, only zero if BC zero
                jr          nz, spi_wr_str_lp


                pop         hl
                pop         bc
                pop         de
                pop         af
                
                ret

; Read multi-byte string
; hl had buffer pointer
; bc has count

spi_read_str:   push        af
                push        de
                push        bc
                push        hl                  ; end protection of registers

spi_r_str_lp:  
                push        bc                  ; preserve count for loop
                call        spi_get             ; fetch byte from spi
                ld          (hl), a             ; fetch byte from write buffer
                inc         hl                  ; advance buffer pointer
                pop         bc                  ; restore loop counter
                dec         bc
                ld          a, b
                or          c                   ; or's two halves of BC, only zero if BC zero
                jr          nz, spi_r_str_lp


                pop         hl
                pop         bc
                pop         de
                pop         af
                
                ret

; Enable SD card select line
; Clobbers AF
spi_ssel_true:
                call        spi_get             ; Send 8 clk pulses, to clear

                ld          a, (spi_ssel_cache) ; retrieve cached value
                and         !(sd_enable_bit)    ; set enable bit low (active low!)
                ld          (spi_ssel_cache), a ; save back to cache
                out0        (sd_enable_addr), a ; output to hardware

                ; make sure card is not busy doing things
spi_ssel_true_busy:
                 call        spi_get
                 cp          $FF                 ; pullup on MISO line
                 jr          nz, spi_ssel_true_busy

                 ret

; Disable SD card select line
; Clobbers AF
spi_ssel_false:
                call        spi_get             ; Send 8 clk pulses, to clear

                ld          a, (spi_ssel_cache) ; retrieve cached value
                or          sd_enable_bit       ; set enable bit high (active low!)
                ld          (spi_ssel_cache), a ; save back to cache
                out0        (sd_enable_addr), a ; output to hardware

                call        spi_get             ; generate 16 more clk pulses
                call        spi_get

                ret

; Swap MSB <-> LSB bits in A, result in A and C
; Clobbers AF, BC
mirror:
                ld          bc, MIRTAB          ; 256 Byte mirror table
                add         a, c                ; offset into table
                ld          c, a                ; move result to C
                jr          nc, mirror2         ; if carry out, 
                inc         b                   ; then increment B
mirror2:
                ld          a, (bc)             ; get result from table
                ld          c, a                ; copy result to C 
                ret


; Mirror table
MIRTAB	.DB 00H, 80H, 40H, 0C0H, 20H, 0A0H, 60H, 0E0H, 10H, 90H, 50H, 0D0H, 30H, 0B0H, 70H, 0F0H
	.DB 08H, 88H, 48H, 0C8H, 28H, 0A8H, 68H, 0E8H, 18H, 98H, 58H, 0D8H, 38H, 0B8H, 78H, 0F8H
	.DB 04H, 84H, 44H, 0C4H, 24H, 0A4H, 64H, 0E4H, 14H, 94H, 54H, 0D4H, 34H, 0B4H, 74H, 0F4H
	.DB 0CH, 8CH, 4CH, 0CCH, 2CH, 0ACH, 6CH, 0ECH, 1CH, 9CH, 5CH, 0DCH, 3CH, 0BCH, 7CH, 0FCH
	.DB 02H, 82H, 42H, 0C2H, 22H, 0A2H, 62H, 0E2H, 12H, 92H, 52H, 0D2H, 32H, 0B2H, 72H, 0F2H
	.DB 0AH, 8AH, 4AH, 0CAH, 2AH, 0AAH, 6AH, 0EAH, 1AH, 9AH, 5AH, 0DAH, 3AH, 0BAH, 7AH, 0FAH
	.DB 06H, 86H, 46H, 0C6H, 26H, 0A6H, 66H, 0E6H, 16H, 96H, 56H, 0D6H, 36H, 0B6H, 76H, 0F6H
	.DB 0EH, 8EH, 4EH, 0CEH, 2EH, 0AEH, 6EH, 0EEH, 1EH, 9EH, 5EH, 0DEH, 3EH, 0BEH, 7EH, 0FEH
	.DB 01H, 81H, 41H, 0C1H, 21H, 0A1H, 61H, 0E1H, 11H, 91H, 51H, 0D1H, 31H, 0B1H, 71H, 0F1H
	.DB 09H, 89H, 49H, 0C9H, 29H, 0A9H, 69H, 0E9H, 19H, 99H, 59H, 0D9H, 39H, 0B9H, 79H, 0F9H
	.DB 05H, 85H, 45H, 0C5H, 25H, 0A5H, 65H, 0E5H, 15H, 95H, 55H, 0D5H, 35H, 0B5H, 75H, 0F5H
	.DB 0DH, 8DH, 4DH, 0CDH, 2DH, 0ADH, 6DH, 0EDH, 1DH, 9DH, 5DH, 0DDH, 3DH, 0BDH, 7DH, 0FDH
	.DB 03H, 83H, 43H, 0C3H, 23H, 0A3H, 63H, 0E3H, 13H, 93H, 53H, 0D3H, 33H, 0B3H, 73H, 0F3H
	.DB 0BH, 8BH, 4BH, 0CBH, 2BH, 0ABH, 6BH, 0EBH, 1BH, 9BH, 5BH, 0DBH, 3BH, 0BBH, 7BH, 0FBH
	.DB 07H, 87H, 47H, 0C7H, 27H, 0A7H, 67H, 0E7H, 17H, 97H, 57H, 0D7H, 37H, 0B7H, 77H, 0F7H
	.DB 0FH, 8FH, 4FH, 0CFH, 2FH, 0AFH, 6FH, 0EFH, 1FH, 9FH, 5FH, 0DFH, 3FH, 0BFH, 7FH, 0FFH

spi_ssel_cache: db         0                   ; reserve byte for spi device select cache         