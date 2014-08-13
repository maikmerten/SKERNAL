
.proc math_add32
	pha

	clc
	lda ARG1
	adc ARG2
	sta RET
	
	lda ARG1+1
	adc ARG2+1
	sta RET+1

	lda ARG1+2
	adc ARG2+2
	sta RET+2

	lda ARG1+3
	adc ARG2+2
	sta RET+3

	pla
	rts
.endproc


.proc math_add32_ptrs
	push_ay

	clc
	php
	ldy #0
loop:
	plp
	lda (MPTR1),y
	adc (MPTR2),y
	sta (MPTR3),y
	php
	iny
	cpy #4
	bne loop

	plp

	pull_ay
	rts
.endproc



.proc math_div32
	push_ax

	;; some mapping of labels
	dividend = ARG1
	divisor = ARG2
	remainder = TMP
	result = dividend
	temp = RET
	temp_to_remainder = util_ret_to_tmp

	lda #0				; preset remainder to 0
	sta remainder
	sta remainder+1
	sta remainder+2
	sta remainder+3
	ldx #32				; repeat for each bit: ...

divloop:
	asl dividend		; dividend*2, msb -> Carry
	rol dividend+1
	rol dividend+2
	rol dividend+3	
	rol remainder		; remainder*2 + msb from carry
	rol remainder+1
	rol remainder+2
	rol remainder+3

	sec					; substract divisor to see if it fits in
	lda remainder
	sbc divisor
	sta temp			; keep result, for we may need it later
	lda remainder+1
	sbc divisor+1
	sta temp+1
	lda remainder+2
	sbc divisor+2
	sta temp+2
	lda remainder+3
	sbc divisor+3
	sta temp+3

	bcc skip				; if carry=0 then divisor didn't fit in yet
	jsr temp_to_remainder	; else substraction result is new remainder
	inc result				; and INCrement result cause divisor fit in 1 times

skip:
	dex
	bne divloop	

	mov32 result, RET
	pull_ax
	rts
.endproc



.proc math_mod32
	pha
	jsr math_div32
	mov32 TMP, RET
	pla
	rts
.endproc


.proc math_mul32
	pha
	lda #0
	sta RET
	sta RET+1
	sta RET+2
	sta RET+3

loop:
	lsr ARG2+3
	ror ARG2+2
	ror ARG2+1
	ror ARG2
	bcc skip_add	; if least-significant bit wasn't set, skip addition

	clc
	lda RET
	adc ARG1
	sta RET
	lda RET+1
	adc ARG1+1
	sta RET+1
	lda RET+2
	adc ARG1+2
	sta RET+2
	lda RET+3
	adc ARG1+3
	sta RET+3

skip_add:	
	asl ARG1	; shift left...
	rol ARG1+1	; ... and rotate carry bit in from low to high
	rol ARG1+2
	rol ARG1+3

	lda ARG2	; check if factor is zero already
	ora ARG2+1
	ora ARG2+2
	ora ARG2+3
	bne loop

	pla
	rts
.endproc


.proc math_sub32
	pha
	
	sec
	lda ARG1
	sbc ARG2
	sta RET
	lda ARG1+1
	sbc ARG2+1
	sta RET+1
	lda ARG1+2
	sbc ARG2+2
	sta RET+2
	lda ARG1+3
	sbc ARG2+3
	sta RET+3

	pla
	rts
.endproc


.proc math_sub32_ptrs
	push_ay

	sec
	php
	ldy #0
loop:
	plp			; get carry back from stack
	lda (MPTR1),y
	sbc (MPTR2),y
	sta (MPTR3),y
	php
	iny
	cpy #4			; this ruins the carry flags, 
	bne loop

	plp

	pull_ay
	rts
.endproc

