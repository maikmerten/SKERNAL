CONSOLE_CMDS:
.asciiz "help"
.asciiz "load"
.asciiz "ls"
.asciiz "memdump"
.asciiz "peek"
.asciiz "poke"
.asciiz "reboot"
.asciiz "run"
.asciiz "test"


CONSOLE_CMDS_VECTORS:
.addr console_help
.addr console_load
.addr console_ls
.addr console_memdump
.addr console_peek
.addr console_poke
.addr console_reboot
.addr console_run
.addr console_test

CONSOLE_CMD_NUM = 9
CONSOLE_CMD_NOT_FOUND = $FF


.proc console_help
	push_ax
	jsr io_write_newline
	put_address S_HELP, ARG1
	jsr io_write_string
	jsr io_write_newline

	ldx #0
loop_cmds:
	put_address CONSOLE_CMDS, ARG1
	stx ARG2
	jsr string_find
	mov16 RET, ARG1
	jsr io_write_string
	jsr io_write_newline
	inx
	txa
	cmp #CONSOLE_CMD_NUM
	bne loop_cmds

	pull_ax
	rts
	S_HELP: .asciiz "Available commands:"
.endproc



.proc console_load
	pha

	;; first argument is file name
	lda #1
	sta ARG2
	put_address CONBASE, ARG1
	jsr string_find
	mov16 RET, ARG1
	jsr fat_find_file

	lda RET
	bne not_found

load:
	jsr fat_load_file

	pla
	rts

not_found:
	put_address S_NOTFOUND,ARG1
	jsr io_write_string
	pla
	rts
	S_NOTFOUND: .asciiz "file not found."
.endproc


.proc console_ls
	jsr fat_list_rootdir
	rts
.endproc


.proc console_peek
	push_ay

	; parse first argument
	lda #1
	jsr console_parse_argument
	mov16 RET, TMP
	ldy #0
	lda (TMP),y
	sta ARG1
	sty ARG1+1
	sty ARG1+2
	sty ARG1+3
	jsr io_write_int32

	pull_ay
	rts
.endproc


.proc console_memdump
	pha
	push_vregs

	; parse first argument
	lda #1
	jsr console_parse_argument

	lda RET		; contains page to be dumped
	sta VREG2
	lda #0
	sta VREG1

next_row:
	jsr console_memdump_row
	lda VREG1
	clc
	adc #8
	sta VREG1

	cmp #128
	beq wait_for_key
	lda VREG1
	bne next_row

	pull_vregs
	pla
	rts

wait_for_key:
	put_address S_KEY, ARG1
	jsr io_write_string
	jsr io_write_newline
	jsr io_read_char
	jmp next_row
	S_KEY: .asciiz "<press key>"
.endproc

;;
;; internal subroutine, expects address of row in (VREG1,VREG2)
;;
.proc console_memdump_row	
	push_ay

	;; first pass: hexdump
	ldy #0
next_hex:
	lda (VREG1),y
	jsr byte2hex
	lda RET
	jsr io_write_char
	lda RET+1
	jsr io_write_char
	lda #C_SP
	jsr io_write_char

	iny
	cpy #8
	bne next_hex

	jsr io_write_char
	jsr io_write_char	

	;; second pass: ASCII dump
	ldy #0
next_ascii:
	lda (VREG1),y

	cmp #32
	bmi special
	cmp #127
	bpl special
	bne printable
special:
	lda #$2E	; ASCII code for .
printable:
	jsr io_write_char

	iny
	cpy #8
	bne next_ascii

	jsr io_write_newline

	pull_ay
	rts
.endproc



.proc console_poke
	push_ay
	push_vregs

	; parse first argument (address)
	lda #1
	jsr console_parse_argument
	mov16 RET, VREG1	

	; parse second argument (value)
	lda #2
	jsr console_parse_argument
	lda RET

	ldy #0
	sta (VREG1),y

	pull_vregs
	pull_ay
	rts
.endproc

.proc console_reboot
	jmp START
.endproc


.proc console_run
	jsr $0800	; programs are loaded at 0x800
	rts
.endproc

.proc console_test
	push_axy

	; parse first argument (address)
	lda #1
	jsr console_parse_argument
	mov32 RET, ARG1
	jsr io_write_int32


	pull_axy
	rts
.endproc


;;
;; handles interpretation of console commands
;;
.proc console_exec
	push_axy

	jsr io_write_newline

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
	put_address S_CMDNOTFOUND, ARG1
	jsr io_write_string
end:

	jsr io_write_newline

	pull_axy
	rts
	S_CMDNOTFOUND: .asciiz "Command not recognized. Try 'help'."
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
;; parse n-th argument (passed in accumulator) as int32 (returned in RET)
;;
.proc console_parse_argument
	sta ARG2
	put_address CONBASE, ARG1
	jsr string_find
	mov16 RET, ARG1
	jsr string_to_int32
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


