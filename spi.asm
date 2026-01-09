#include "io.asm"

spi_init:       ld          a, 6                ; div by 1280 - 14KHz @18MHz clock?
                out0        (CNTR), a
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

                in0         a, (CNTR)           
                set         5, a                ; Start receiver
                out0        (CNTR), a

                call        spi_waitrx
                in0         a, (TRDR)           ; Get the bit
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
                jr          nz, spi_waittx      
                ret