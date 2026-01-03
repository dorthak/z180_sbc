; base address for re-located on-board control registers
Z180_BASE:              .equ    $C0


; Other control registers
rcr_addr:               .equ    Z180_BASE + $36
dcntl_addr:             .equ    Z180_BASE + $32
cmr_addr:               .equ    Z180_BASE + $1E
ccr_addr:               .equ    Z180_BASE + $1F

; MMU registers
cbr_addr:               .equ    Z180_BASE + $38
bbr_addr:               .equ    Z180_BASE + $39
cbar_addr:              .equ    Z180_BASE + $3A

;dcntl_addr:             .equ    Z180_BASE + $32
