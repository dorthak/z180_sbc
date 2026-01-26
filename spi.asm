#include "io.asm"

spi_init:       ld          a, 6                ; div by 1280 - 14KHz @18MHz clock?
                out0        (CNTR), a

                ld          a, sd_enable_bit    ; SD Enable is active low, so set high at init
                ld          (spi_ssel_cache), a ; Set cache
                out0        (sd_enable_addr), a ; and write out to harware
                ret


; Send byte in C
; Clobbers AF
spi_put:        call spi_waittx                 ; check if done sending

                out0        (TRDR), c
                in0         a, (CNTR)
                set         4, a                ; Set transmit enable
                out0        (CNTR), a
                ret


; get one byte, return in A
; clobbers AF
spi_get:        call        spi_waittx          ; make sure we aren't sending
                ;call        spi_waitrx          ; make sure we aren't recieving

                in0         a, (CNTR)           
                set         5, a                ; Start receiver
                out0        (CNTR), a

                call        spi_waitrx
                in0         a, (TRDR)           ; Get the byte
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
                djnz        spi_wr_str_lp


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
; spi_ssel_true_busy:
;                 call        spi_get
;                 cp          $FF                 ; pullup on MISO line
;                 jr          nz, spi_ssel_true_busy

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




spi_ssel_cache: db         0                   ; reserve byte for spi device select cache         