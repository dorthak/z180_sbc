;###########

; Z181 SC131/S100 SBC IO Port definitions

; Serial port register addresses
CNTLA0:                 .equ    Z180_BASE               ; SIO Port 0 Control A
CNTLA1:                 .equ    Z180_BASE + $01         ; SIO Port 1 Control A

CNTLB0:                 .equ    Z180_BASE + $02         ; SIO Port 0 Control B
CNTLB1:                 .equ    Z180_BASE + $02         ; SIO Port 1 Control B

STAT0:                  .equ    Z180_BASE + $04         ; SIO Port 0 Status
STAT1:                  .equ    Z180_BASE + $05         ; SIO Port 1 Status

ASEXT0:                 .equ    Z180_BASE + $12         ; SIO Port 0 Extenson
ASEXT1:                 .equ    Z180_BASE + $13         ; SIO Port 1 Extension

TDR0:                   .equ    Z180_BASE + $06         ; SIO Port 0 Transmit 
TDR1:                   .equ    Z180_BASE + $07         ; SIO Port 1 Transmit 

RDR0:                   .equ    Z180_BASE + $08         ; SIO Port 0 Receive 
RDR1:                   .equ    Z180_BASE + $09         ; SIO Port 1 Receive 

; address and  bit-assignment for the SD card enable and satus light port
sd_enable_bit:          .equ    $2
status_enable_bit:      .equ    $2
sd_enable_addr:         .equ    $0C
status_led_addr:        .equ    $0E

