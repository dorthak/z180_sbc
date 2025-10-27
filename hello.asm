bdos:   equ     0x0005          ; BDOS Sys Request
print:  equ     0x09            ; BDOS Print String function

        org     0x0100

        ld      c,print
        ld      de, message
        call    bdos
        ret
message:
        db      0x0d,0x0a,'Hello, World!',0x0a,0x0d,'$'
