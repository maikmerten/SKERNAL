;;
;; A very Stupid KERNAL wannabe.
;;


;; Basic definitions ################################################


;; arguments, return values, temporary zp storage
;; those are not guaranteed to be preserved by normal subroutines
;; interrupt handlers, however, *are* mandated to restore those!
ARG1 = $c0
ARG2 = ARG1 + 4
RET = ARG2 + 4
TMP = RET + 4
TMP1 = TMP
TMP2 = TMP1 + 4
TMP3 = TMP2 + 4
TMP4 = TMP3 + 4

;; some space to save registers if we cannot use the stack
SAVEA = TMP4 + 4
SAVEX = SAVEA + 1
SAVEY = SAVEX + 1

;; some storage for pointers
PTR1 = SAVEY + 1
PTR2 = PTR1 + 2
PTR3 = PTR2 + 2

;; pointers for math (arguments and result)

MPTR1 = PTR3 + 2	; first argument
MPTR2 = MPTR1 + 2	; second argument
MPTR3 = MPTR2 + 2	; primary result
MPTR4 = MPTR3 + 2	; secondary result (where relevant, like remainder of division)

;; those *are* saved by subroutines and interrupts!
VREG1 = MPTR4 + 2
VREG2 = VREG1 + 1

;; IRQ vector for applications
IRQ_VEC = VREG2 + 1

;; pointer into console buffer in page 2
CONPTR = IRQ_VEC + 2
CONBASE = $0200

;; A few special characters
C_LF = $0A	; line feed
C_CR = $0D	; carriage return
C_BS = $08	; backspace
C_SP = $20	; space

; ######## Macros #########
.include "macros.asm"
; #########################

;; Predefined Data ##################################################

.segment "DATA"

S_HEX: .asciiz "0123456789abcdef";
S_GREETING: .asciiz "*** SKERNAL obeys ***";
S_NEWLINE:
.byte C_CR
.byte C_LF
.byte $00	; string termination


;; Code #############################################################

.segment "CODE"

; ######### Includes ##########
.include "util.asm"
.include "math.asm"
.include "io.asm"
.include "fat.asm"
.include "console.asm"
; #################################


.proc START
	cli
	cld
	
	jsr io_init
	
	;; clear console buffer
	lda #$0
	sta CONPTR

	;; set up interrupts
	jsr clearirq

	put_address S_GREETING, ARG1
	jsr io_write_string
	jsr io_write_newline

	;; console loop #############################################
console:
	jsr io_read_line
	jsr console_exec
	jsr console_clear_buffer 	; buffer is executed now, so clear it
	jmp console
.endproc



;;
;; Clear all IRQ vectors
;;
.proc clearirq
	pha
	lda #$0
	sta IRQ_VEC
	sta IRQ_VEC+1
	pla
	rts
.endproc

;;
;; compares two strings
;; returns: 0 (strings match), 1 (no match, first string has bigger diverging character) or 2 (no match, second string has bigger diverging character)
;;
.proc string_compare
	push_ay
	ldy #$FF

next:
	iny
	lda (ARG1),y
	cmp (ARG2),y
	bcs gtEq		; first string is greater or equal
	lda #2			; first string is smaller
	jmp end

gtEq:
	beq equal		; characters match
	lda #1			; first string is greater
	jmp end

equal:
	cmp #0
	bne next		; strings not yet terminated
	lda #0

end:
	sta RET
	pull_ay
	rts
.endproc

;;
;; returns address of n-th parameter in buffer
;; (ARG1,ARG1+1) contains address to start search, ARG2 contains n
;;
.proc string_find
	push_axy

	ldy #0
	ldx ARG2	; contains n
	beq end		; parameter 0 is always at start of buffer

loop:
	lda (ARG1),y
	beq delimiter_found
loop_cont:
	iny
	bne loop
	jmp end

delimiter_found:

	iny
	lda (ARG1),y	; if next character is also delimiter, ignore
	dey

	beq skip_decrement
	dex
skip_decrement:
	txa
	beq finish
	jmp loop_cont

finish:
	iny		; make sure we move off the zero byte
end:
	sty RET

	clc			; add offset to base address
	lda ARG1
	adc RET
	sta RET
	lda ARG1+1
	adc #0		; make sure carry makes it into hi byte of address
	sta RET+1

	pull_axy
	rts
.endproc

;;
;; (ARG1,ARG1+1): pointer to string, returns 32-bit int in RET
;;
.proc string_to_int32
	push_axy
	push_vregs

	mov16 ARG1, VREG1

	jsr util_imm32_to_arg1
	.byte $00, $00, $00, $00

	;; set up math pointers so result is written back to ARG1
	jsr math_ptrcfg_arg1_arg2_arg1_ret

next_char:
	lda (VREG1),y
	beq end
	pha					; save current character of input string

	;; multiply contents of ARG1 by 10
	put_address CONST32_10, MPTR2
	jsr math_mul32

	;; find decimal value for char at current position
	ldx #10
	pla					; pull character from stack
	sta TMP
loop_decimal:
	lda S_HEX,x
	cmp TMP				; compare with character of string
	beq end_decimal		; match found, x contains decimal value

	dex
	bmi end_decimal		; branch on minus: x wrapped to $ff
	jmp loop_decimal

end_decimal:
	
	stx ARG2			; x contains decimal value for character
	lda #0
	sta ARG2+1
	sta ARG2+2
	sta ARG2+3

	put_address ARG2, MPTR2
	jsr math_add32

	iny
	jmp next_char
	
end:

	mov32 ARG1, RET

	pull_vregs
	pull_axy
	rts
.endproc


;;
;; returns a hexadezimal representaiton of a byte
;; a-register has parameter
;;
.proc byte2hex
	sta SAVEA
	push_ax

	lda SAVEA
	and #$F0
	lsr
	lsr
	lsr
	lsr
	tax
	lda S_HEX,x
	sta RET

	lda SAVEA
	and #$0F
	tax
	lda S_HEX,x
	sta RET+1

	pull_ax
	rts
.endproc


;;
;; IRQ handler
;;
.proc IRQ
	pha		; save affected register

	lda IRQ_VEC	; check if IRQ vector is zero
	ora IRQ_VEC+1
	beq end		; if so, skip

	; there is no indirect jsr so push return address to stack
	; so the actual IRQ handler code can rts later on
	prepare_rts end
	jmp (IRQ_VEC)

end:	pla		; restore register
	rti		; return from interrupt
.endproc



; system vectors ####################################################

.segment "VECTORS"
.org    $FFFA

.addr	IRQ		; NMI vector
.addr	START		; RESET vector
.addr	IRQ		; IRQ vector
