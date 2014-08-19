.proc util_clear_arg1
	mov32_immptrs CONST32_0, ARG1
	rts
.endproc


.proc util_clear_arg2
	mov32_immptrs CONST32_0, ARG2
	rts
.endproc


.proc util_ret_to_arg1
	mov32_immptrs RET, ARG1
	rts
.endproc


.proc util_ret_to_arg2
	mov32_immptrs RET, ARG2
	rts
.endproc


.proc util_ret_to_tmp
	mov32_immptrs RET, TMP
	rts
.endproc

;;
;; loads two pointers given in immediate form from return address and copies 4 bytes across
;;
.proc util_mov32_immptrs
	sta SAVEA
	sty SAVEY

	pla		; lo part of return address
	sta PTR1
	pla		; hi part of return address
	sta PTR1+1

	; retrieve the two pointers
	ldy #1
	lda (PTR1),y
	sta PTR2
	iny
	lda (PTR1),y
	sta PTR2+1
	iny
	lda (PTR1),y
	sta PTR3
	iny
	lda (PTR1),y
	sta PTR3+1

	; copy 4 bytes
	ldy #0
	lda (PTR2),y
	sta (PTR3),y
	iny
	lda (PTR2),y
	sta (PTR3),y
	iny
	lda (PTR2),y
	sta (PTR3),y
	iny
	lda (PTR2),y
	sta (PTR3),y

	jmp _imm32_footer	; rts is there
.endproc


;;
;; loads the four bytes to ARG1 that follow the caller's position
;;
.proc util_imm32_to_arg1
	sta SAVEA	; save registers without touching the stack
	sty SAVEY

	pla		; lo part of return address
	sta PTR1
	pla		; hi part of return address
	sta PTR1+1

	ldy #1
	lda (PTR1),y
	sta ARG1
	iny
	lda (PTR1),y
	sta ARG1+1
	iny
	lda (PTR1),y
	sta ARG1+2
	iny
	lda (PTR1),y
	sta ARG1+3

	jmp _imm32_footer	; actual rts is there
.endproc

;;
;; loads the four bytes to ARG2 that follow the caller's position
;;
.proc util_imm32_to_arg2
	sta SAVEA	; save registers without touching the stack
	sty SAVEY

	pla		; lo part of return address
	sta PTR1
	pla		; hi part of return address
	sta PTR1+1

	ldy #1
	lda (PTR1),y
	sta ARG2
	iny
	lda (PTR1),y
	sta ARG2+1
	iny
	lda (PTR1),y
	sta ARG2+2
	iny
	lda (PTR1),y
	sta ARG2+3
.endproc
.proc _imm32_footer
	clc		; increment return address by 4
	lda PTR1
	adc #4
	sta PTR1
	lda PTR1+1
	adc #0
	pha		; push hi part of return address
	lda PTR1
	pha		; push lo part of return address

	lda SAVEA	; restore registers
	ldy SAVEY

	rts
.endproc


;;
;; converts a char in register a to upper-case
;;
.proc util_to_uppercase
	cmp #97
	bmi end
	cmp #123
	bpl end
	and #$DF
end:
	rts
.endproc

;;
;; converts a char in register a to upper-case
;;
.proc util_to_lowercase
	cmp #65
	bmi end
	cmp #91
	bpl end
	ora #$20
end:
	rts
.endproc

