;;
;; A very Stupid KERNAL wannabe.
;;


;; Basic definitions ################################################


;; arguments, return values, temporary zp storage
;; those are not guaranteed to be preserved by normal subroutines
;; interrupt handlers, however, *are* mandated to restore those!
ARG1 = $0008
ARG2 = ARG1 + 4
RET = ARG2 + 4
TMP = RET + 4

;; those *are* saved by subroutines and interrupts!
VREG1 = TMP + 4
VREG2 = VREG1 + 1

;; IRQ vectors for two I/O-devices and applications

IRQ_IO1 = VREG2 + 1
IRQ_IO2 = IRQ_IO1 + 2
IRQ_APP = IRQ_IO2 + 2

;; single-byte IO buffers
IO1 = IRQ_APP + 2
IO2 = IO1 + 1

;; pointer into console buffer in page 2
CONPTR = IO2 + 1
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
	jsr clearirqs

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
.proc clearirqs
	pha
	lda #$0
	sta IRQ_IO1
	sta IRQ_IO1+1
	sta IRQ_IO2
	sta IRQ_IO2+1
	sta IRQ_APP
	sta IRQ_APP+1
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

	ldy #0
	sty ARG1
	sty ARG1+1
	sty ARG1+2
	sty ARG1+3

next_char:
	lda (VREG1),y
	beq end
	sta TMP		; save character in TMP

	;; multiply contents of ARG1 by 10
	lda #10
	sta ARG2
	lda #0
	sta ARG2+1
	sta ARG2+2
	sta ARG2+3

	jsr math_mul32
	jsr util_ret_to_arg1

	;; find decimal value for char at current position
	ldx #10
loop_decimal:
	lda S_HEX,x
	cmp TMP				; compare with character of string
	beq end_decimal		; match found, x contains decimal value

	dex
	bmi end_decimal		; branch on minus: x wrapped to $ff
	jmp loop_decimal

end_decimal:

	; x contains decimal value for character
	txa
	sta ARG2
	lda #0
	sta ARG2+1
	sta ARG2+2
	sta ARG2+3

	jsr math_add32
	jsr util_ret_to_arg1

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
	sta TMP
	txa		; save x register
	pha

	lda TMP
	lsr		; shift four bits right
	lsr
	lsr
	lsr
	tax
	lda S_HEX,x
	sta RET

	lda TMP
	and #$0F
	tax
	lda S_HEX,x
	sta RET+1

	pla
	tax
	lda TMP
	rts
.endproc


;;
;; IRQ handler
;;
.proc IRQ
	pha		; save affected register

	lda IRQ_IO1	; check if IRQ vector is zero
	ora IRQ_IO1+1
	beq io2		; if so, skip

	; there is no indirect jsr so push return address to stack
	; so the actual IRQ handler code can rts later on
	prepare_rts io2
	jmp (IRQ_IO1)

io2:	lda IRQ_IO2
	ora IRQ_IO2+1
	beq app

	prepare_rts app
	jmp (IRQ_IO2)

app:	lda IRQ_APP
	ora IRQ_APP+1
	beq end

	prepare_rts end
	jmp (IRQ_APP)

end:	pla		; restore register
	rti		; return from interrupt
.endproc



; system vectors ####################################################

.segment "VECTORS"
.org    $FFFA

.addr	IRQ		; NMI vector
.addr	START		; RESET vector
.addr	IRQ		; IRQ vector
