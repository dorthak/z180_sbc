; Define the memory size to be used for the CP/M configuration
MEM:        .equ 60

; The CPM origin will be at: (MEM-7)*1024
; This screwy convention is due to the way that that the CP/M origin is defined.
CPM_BASE:	.equ	(MEM-7)*1024

LOAD_BASE:	.equ	0xc000		; where the boot loader reads the image from the SD card