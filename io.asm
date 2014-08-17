IOBASE   = $FFD1	; register to read/write data from ACIA
IOSTATUS = $FFD0	; location of status register
IOCMD    = $FFD0	; location of command register
IOCMD_INIT = $15;	; init value for ACIA
IOSTATUS_RXFULL = $01;
IOSTATUS_TXEMPTY = $02;

SDDATA = $FFD8
SDSTATUS = $FFD9
SDCONTROL = $FFD9
SDLBA0 = $FFDA
SDLBA1 = $FFDB
SDLBA2 = $FFDC



;;
;; initialize input/output
;;
.proc io_init
	pha

	;; initialize ACIA
	lda #IOCMD_INIT
	sta IOCMD

	pla
	rts
.endproc


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

	;; setup pointers for division	
	jsr math_ptrcfg_arg1_arg2_arg1_ret	; place result of division back into ARG1, remainder to RET
	put_address CONST32_10, MPTR2		; second argument is the constant '10'

	ldy #0
loop:
	jsr math_div32
	lda RET
	pha			; push to stack to reverse order of output
	iny

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

;;
;; read a 512-byte block from the SD card.
;; (ARG1,ARG1+1,ARG1+2): block index on SD card
;; (ARG2) and (ARG2)+1: pages to write data into
;;
.proc io_sd_read_block
	push_axy

wait:
	lda SDSTATUS
	cmp #128
	bne wait	

	lda ARG1
	sta SDLBA0
	lda ARG1+1
	sta SDLBA1
	lda ARG1+2
	sta SDLBA2

	lda #0
	sta ARG1
	sta SDCONTROL	; issue read command

	ldx ARG2	; dump into page (ARG2) and following page
	ldy #2		; read two chunks of 256 bytes
read_to_page:
	stx ARG1+1
	inx
	jsr io_sd_read_to_page
	dey
	bne read_to_page

	pull_axy
	rts
.endproc

;;
;; read 256 bytes and put it into page designated by (ARG1,ARG1+1)
;;
.proc io_sd_read_to_page
	push_ay

	ldy #0

loop:
	lda SDSTATUS
	cmp #224
	bne loop

	lda SDDATA
	sta (ARG1),y

	iny
	bne loop	; we're done once we wrap around to zero again

	pull_ay
	rts
.endproc



;;
;; write a 512-byte block to the SD card.
;; (ARG1,ARG1+1,ARG1+2): block index on SD card
;; (ARG2) and (ARG2)+1: pages to read data from
;;
.proc io_sd_write_block
	push_axy

wait:
	lda SDSTATUS
	cmp #128
	bne wait	

	lda ARG1
	sta SDLBA0
	lda ARG1+1
	sta SDLBA1
	lda ARG1+2
	sta SDLBA2

	lda #1
	sta ARG1
	sta SDCONTROL	; issue write command

	ldx ARG2	; write page (ARG2) and following page
	ldy #2		; read two chunks of 256 bytes
write_page:
	stx ARG1+1
	inx
	jsr io_sd_write_page
	dey
	bne write_page

	pull_axy
	rts
.endproc

;;
;; write 256 bytes of page designated by (ARG1,ARG1+1)
;;
.proc io_sd_write_page
	push_ay

	ldy #0

loop:
	lda SDSTATUS
	cmp #160
	bne loop

	lda (ARG1),y
	sta SDDATA

	iny
	bne loop	; we're done once we wrap around to zero again

	pull_ay
	rts
.endproc



.proc io_write_byte_hex
	pha
	jsr byte2hex
	lda RET
	jsr io_write_char
	lda RET+1
	jsr io_write_char
	lda #C_SP
	jsr io_write_char
	pla
	rts
.endproc





