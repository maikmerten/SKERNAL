CONSOLE_CMDS:
.asciiz "help"
.asciiz "load"
.asciiz "memdump"
.asciiz "peek"
.asciiz "poke"
.asciiz "run"
.asciiz "test"


CONSOLE_CMDS_VECTORS:
.addr console_help
.addr console_notimplemented
.addr console_memdump
.addr console_peek
.addr console_poke
.addr console_notimplemented
.addr console_test

CONSOLE_CMD_NUM = 7
CONSOLE_CMD_NOT_FOUND = $FF

.proc console_help
	push_ax
	jsr write_newline
	put_address S_HELP, ARG1
	jsr write_string
	jsr write_newline

	ldx #0
loop_cmds:
	put_address CONSOLE_CMDS, ARG1
	stx ARG2
	jsr string_find
	mov16 RET, ARG1
	jsr write_string
	jsr write_newline
	inx
	txa
	cmp #CONSOLE_CMD_NUM
	bne loop_cmds

	pull_ax
	rts
	S_HELP: .asciiz "Available commands:"
.endproc


.proc console_memdump
	push_axy
	push_vregs

	; parse first argument
	lda #1
	sta ARG1
	jsr console_parse_argument

	lda RET		; contains page to be dumped
	sta VREG2
	lda #0
	sta VREG1

	ldx #0
	ldy #0
nextbyte:
	stx VREG1
	lda (VREG1),y
	jsr byte2hex
	lda RET
	jsr write_char
	lda RET+1
	jsr write_char
	lda #C_SP
	jsr write_char

	txa
	and #$0F	; line break every 16 octets
	cmp #$0F
	bne skip_newline
	put_address S_NEWLINE, ARG1
	jsr write_string
skip_newline:
	inx

	bne nextbyte	; abort when overflowing to zero

	pull_vregs
	pull_axy
	rts	
.endproc


.proc console_peek
	push_ay

	; parse first argument
	lda #1
	sta ARG1
	jsr console_parse_argument
	mov16 RET, TMP
	ldy #0
	lda (TMP),y
	sta ARG1
	sty ARG1+1
	sty ARG1+2
	sty ARG1+3
	jsr write_int32

	pull_ay
	rts
.endproc


.proc console_poke
	push_ay
	push_vregs

	; parse first argument (address)
	lda #1
	sta ARG1
	jsr console_parse_argument
	mov16 RET, VREG1	

	; parse second argument (value)
	lda #2
	sta ARG1
	jsr console_parse_argument
	lda RET

	ldy #0
	sta (VREG1),y

	pull_vregs
	pull_ay
	rts
.endproc

.proc console_test
	push_axy

	;mov #$cd, ARG1, #$ab, ARG1+1, #$00, ARG1+2, #0, ARG1+3
	;mov #$99, ARG2, #$99, ARG2+1, #$00, ARG2+2, #0, ARG2+3
	;jsr math_mul32
	;jsr util_ret_to_arg1
	;jsr write_int32

	lda #1
	sta ARG1
	jsr console_parse_argument
	jsr util_ret_to_arg1
	jsr write_int32

	pull_axy
	rts
.endproc

.proc console_notimplemented
	pha
	put_address S_NOTIMPLEMENTED, ARG1
	jsr write_string

	pla
	rts
	S_NOTIMPLEMENTED: .asciiz "Not yet implemented."
.endproc

.proc console_cmdnotfound
	pha
	put_address S_CMDNOTFOUND, ARG1
	jsr write_string

	pla
	rts
	S_CMDNOTFOUND: .asciiz "Command not recognized. Type 'help' to get a list of commands."
.endproc


;;
;; handles interpretation of console commands
;;

.proc console_exec
	push_axy

	jsr write_newline

	jsr console_split_buffer

	jsr console_identify_cmd
	lda RET
	cmp #CONSOLE_CMD_NOT_FOUND
	beq cmd_not_found
	asl							; multiply by two
	tax
	
	lda CONSOLE_CMDS_VECTORS,x
	sta TMP
	lda CONSOLE_CMDS_VECTORS+1,x
	sta TMP+1

	prepare_rts end
	jmp (TMP)

cmd_not_found:
	jsr console_cmdnotfound
end:

	jsr write_newline

	pull_axy
	rts
.endproc

;;
;; splits parameters in buffer into zero-terminated strings. Returns index for last parameter.
;;
.proc console_split_buffer
	push_ax

	ldx #0
	stx RET
next:
	lda CONBASE,x
	beq end		; end on end of string
	cmp #C_SP	; space is arguments delimiter
	bne skip

	lda #0
	sta CONBASE,x	; zero-terminate parameter
	lda CONBASE+1,x	; look at next character
	cmp #C_SP
	beq skip	; don't count if next character is space
	inc RET	; count delimiters

skip:
	inx
	jmp next

end:
	pull_ax
	rts
.endproc


;;
;; identify the command to be executed. Returns index of console function
;;
.proc console_identify_cmd
	push_axy
	
	ldx #0		; start at first cmd
next:
	put_address CONSOLE_CMDS, ARG1
	stx ARG2
	jsr string_find

	mov16 RET, ARG1
	put_address CONBASE, ARG2
	jsr string_compare

	lda RET
	beq end		; found a match!

	inx
	txa
	cmp #CONSOLE_CMD_NUM
	bne next

	ldx #CONSOLE_CMD_NOT_FOUND	; couldn't find the fitting cmd
	
end:
	stx RET
	pull_axy
	rts
.endproc


;;
;; parse n-argument as int32
;;
.proc console_parse_argument
	pha
	
	lda ARG1
	sta ARG2
	put_address CONBASE, ARG1
	jsr string_find
	mov16 RET, ARG1
	jsr string_to_int32

	pla
	rts
.endproc



;;
;; clears console buffer
;;
.proc console_clear_buffer
	pha
	lda #0
	sta CONPTR
	sta CONBASE
	pla
	rts
.endproc


