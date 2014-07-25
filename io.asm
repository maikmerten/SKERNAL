;;
;; Transmit single character to ACIA output device
;; a-register contains argument
;;
.proc io_write_char
	pha

readstatus:
	lda IOSTATUS	; load status register
	and #IOSTATUS_TXEMPTY        ; Is the tx register empty?
	beq readstatus	; busy waiting till ready

	pla		; get character
	sta IOBASE	; write to output

	rts		; end subroutine	
.endproc


;;
;; Writes a 32-bit integer to output device
;;
.proc io_write_int32
	push_axy
	
	; divisor: 10
	mov #$a, ARG2, #0, ARG2+1, #0, ARG2+2, #0, ARG2+3

loop:
	jsr math_div32
	lda TMP			; TMP happens to contain remainder
	pha			; push to stack to reverse order of output
	iny
	jsr util_ret_to_arg1

	lda ARG1
	ora ARG1+1
	ora ARG1+2
	ora ARG1+3
	bne loop

loop_output:
	pla
	tax
	lda S_HEX,x
	jsr io_write_char
	dey
	bne loop_output

	pull_axy
	rts
.endproc


;;
;; Transmit a 0-terminated string to output device
;;
.proc io_write_string
	push_ay
	mov16 ARG1, TMP

	ldy #$0
fetchnext:
	lda (TMP),y
	beq exit
	jsr io_write_char
	iny
	jmp fetchnext
exit:
	pull_ay
	rts
.endproc

;;
;; prints carriage return and newline
;;
.proc io_write_newline
	pha

	put_address S_NEWLINE, ARG1
	jsr io_write_string

	pla
	rts
.endproc


;;
;; read a single character from input device
;;
.proc io_read_char
	pha

read_char:
	lda IOSTATUS
	and #IOSTATUS_RXFULL	; check if data register is full
	beq read_char			; if not full, repeat

	lda IOBASE			   	; Get the character in the ACIA.
	sta RET

	pla
	rts
.endproc



;;
;; read a complete line from input device
;;
.proc io_read_line
	push_ax

read_line:

	jsr io_read_char
	lda RET

	cmp #32			; the first 31 ASCII codes are control chars
	bmi control		; special treatment for control codes

	; This is a printable character, so write to buffer and write to output device
	jsr io_write_char
	ldx CONPTR
	sta CONBASE,x
	lda #0
	sta CONBASE+1,x		; terminate the string with zero
	inc CONPTR

	jmp read_line
control:
	cmp #C_CR		; check for carriage return
	beq end
	cmp #C_BS		; check for backspace
	beq backspace
	jmp read_line		; not a supported code

backspace:

	ldx CONPTR
	beq skip_decrement
	dex			; decrement pointer into console buffer
   skip_decrement:
	stx CONPTR
	lda #0
	sta CONBASE,x		; terminate string with zero
	lda #C_BS
	jsr io_write_char	; write backspace to output

	jmp read_line

end:
	pull_ax
	rts

.endproc


