; Large portions of this code are copied from, or inspired by: 
;   John Winans' z80-retro-cpm project.  
;   Wayne Warthen's RomWBW project
; All of their Copyright is retained by original authors

; Write null-terminated string found at HL to the console



puts:
    push    af
    push    bc
    push    hl

    call    puts_loop

    pop     hl
    pop     bc
    pop     af

    ret

puts_loop:
    ld      a, (hl)             ; Get next byte to send
    or      a 
    jr      z, .puts_done       ; If A is zero, this is the terminating null
    ld      c, a                ; Put into C for the tx routine
    call    con_tx_char
    inc     hl
    jp      puts_loop

.puts_done
    ret

; Write a null-terminated string found right after the call to this to console
; Clobbers af, c

iputs:
    ex      (sp), hl            ; sp contains the pc from before the call, so put in hl
                                ; to point at the string to be printed
    call    puts_loop          
    inc     hl
    ex      (sp), hl            ; put the byte after the string back into the sp
                                ; so that it can be fed back to the PC on return
    ret


; Print a CRLF
; Clobbers AF, C
puts_crlf:

    call    iputs
    asciiz  '\r\n'
    ret
