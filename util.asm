.proc util_ret_to_arg1
	pha
	mov32 RET, ARG1
	pla
	rts
.endproc


.proc util_ret_to_arg2
	pha
	mov32 RET, ARG2
	pla
	rts
.endproc


.proc util_ret_to_tmp
	pha
	mov32 RET, TMP
	pla
	rts
.endproc


;;
;; loads the four bytes to ARG1 that follow the caller's position
;;
.proc util_load32_to_arg1
	sta TMP+2	; save registers without touching the stack
	sty TMP+3

	pla		; lo part of return address
	sta TMP
	pla		; hi part of return addrss
	sta TMP+1

	ldy #1
	lda (TMP),y
	sta ARG1
	iny
	lda (TMP),y
	sta ARG1+1
	iny
	lda (TMP),y
	sta ARG1+2
	iny
	lda (TMP),y
	sta ARG1+3

	jmp _load32_footer	; actual rts is there
.endproc

;;
;; loads the four bytes to ARG2 that follow the caller's position
;;
.proc util_load32_to_arg2
	sta TMP+2	; save registers without touching the stack
	sty TMP+3

	pla		; lo part of return address
	sta TMP
	pla		; hi part of return addrss
	sta TMP+1

	ldy #1
	lda (TMP),y
	sta ARG2
	iny
	lda (TMP),y
	sta ARG2+1
	iny
	lda (TMP),y
	sta ARG2+2
	iny
	lda (TMP),y
	sta ARG2+3
.endproc
.proc _load32_footer
	clc		; increment return address by 4
	lda TMP
	adc #4
	sta TMP
	lda TMP+1
	adc #0
	pha		; push hi part of return address
	lda TMP
	pha		; push lo part of return address

	lda TMP+2	; restore registers
	ldy TMP+3

	rts
.endproc



