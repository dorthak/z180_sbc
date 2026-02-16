; Large portions of this code are copied from, or inspired by: 
;   John Winans' z80-retro-cpm project.  
;   Wayne Warthen's RomWBW project
; All of their Copyright is retained by original authors

;###########

; Z181 SC131/S100 SBC IO Port definitions

; Serial port register addresses
CNTLA0:                 .equ    Z180_BASE               ; SIO Port 0 Control A
CNTLA1:                 .equ    Z180_BASE + $01         ; SIO Port 1 Control A

CNTLB0:                 .equ    Z180_BASE + $02         ; SIO Port 0 Control B
CNTLB1:                 .equ    Z180_BASE + $03         ; SIO Port 1 Control B

STAT0:                  .equ    Z180_BASE + $04         ; SIO Port 0 Status
STAT1:                  .equ    Z180_BASE + $05         ; SIO Port 1 Status

ASEXT0:                 .equ    Z180_BASE + $12         ; SIO Port 0 Extenson
ASEXT1:                 .equ    Z180_BASE + $13         ; SIO Port 1 Extension

TDR0:                   .equ    Z180_BASE + $06         ; SIO Port 0 Transmit 
TDR1:                   .equ    Z180_BASE + $07         ; SIO Port 1 Transmit 

RDR0:                   .equ    Z180_BASE + $08         ; SIO Port 0 Receive 
RDR1:                   .equ    Z180_BASE + $09         ; SIO Port 1 Receive 

CNTR:                   .equ    Z180_BASE + $0A         ; Clocked Serial Port (CSI/O) control register
TRDR:                   .equ    Z180_BASE + $0B         ; CSIO Tx/Rx Data register


; address and  bit-assignment for the SD card enable and satus light port
sd_enable_bit:          .equ    $4
status_enable_bit:      .equ    $4
sd_enable_addr:         .equ    $0C         ; RTCIO in RomWBW
status_led_addr:        .equ    $0E         ; LEDPORT in RomWBW


; constants for non-printable characters
;CR          .equ    $D
;LF          .equ    $A

