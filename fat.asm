BUFFERPAGE = 4
BUFFERBASE = BUFFERPAGE * 256

BYTESPERSECTOR = $0300
SECTORSPERCLUSTER = BYTESPERSECTOR + 4
RESERVEDSECTORS = SECTORSPERCLUSTER + 4
FATCOPIES = RESERVEDSECTORS + 4
ROOTENTRIES = FATCOPIES + 4
SECTORSPERFAT = ROOTENTRIES + 4
ROOTSTART = SECTORSPERFAT + 4
ROOTSIZE = ROOTSTART + 4
DATASTART = ROOTSIZE + 4
POSITION = DATASTART + 4
CURRENTCLUSTER = POSITION + 4
OFFSET = CURRENTCLUSTER + 4
CURRENTPAGE = OFFSET + 4
BUFFEREDSECTOR = CURRENTPAGE + 4
BUFFERMODIFIED = BUFFEREDSECTOR + 4
FILENAME = BUFFERMODIFIED + 1		; 8+3 + zero termination
FILENAME2 = FILENAME + 12			; 8+3 + zero termination
FILESTART = FILENAME2 + 12

;;
;; read basic information from FAT boot block
;; and do some basic computations regarding the fs layout
;;
.proc fat_init
	push_axy

	lda #0
	sta BUFFERMODIFIED		; ensure buffer is marked unmodified

	jsr util_clear_arg1
	jsr fat_buffer_sector

	;; determine bytes per sector
	put_address S_BPS, ARG1
	jsr io_write_string
	jsr util_clear_arg1
	lda BUFFERBASE + 11
	sta ARG1
	lda BUFFERBASE + 12
	sta ARG1+1
	mov32_immptrs ARG1, BYTESPERSECTOR
	jsr io_write_int32
	jsr io_write_newline


	;; sectors per cluster
	put_address S_SPC, ARG1
	jsr io_write_string
	jsr util_clear_arg1
	lda BUFFERBASE + 13
	sta ARG1
	mov32_immptrs ARG1, SECTORSPERCLUSTER
	jsr io_write_int32
	jsr io_write_newline	

	;; reserved sectors
	put_address S_RES, ARG1
	jsr io_write_string
	jsr util_clear_arg1
	lda BUFFERBASE + 14
	sta ARG1
	mov32_immptrs ARG1, RESERVEDSECTORS
	jsr io_write_int32
	jsr io_write_newline

	;; number of FAT copies
	put_address S_NFC, ARG1
	jsr io_write_string
	jsr util_clear_arg1
	lda BUFFERBASE + 16
	sta ARG1
	mov32_immptrs ARG1, FATCOPIES
	jsr io_write_int32
	jsr io_write_newline

	;; number of root directory entries
	put_address S_NRE, ARG1
	jsr io_write_string
	jsr util_clear_arg1
	lda BUFFERBASE + 17
	sta ARG1
	lda BUFFERBASE + 18
	sta ARG1+1
	mov32_immptrs ARG1, ROOTENTRIES
	jsr io_write_int32
	jsr io_write_newline


	;; sectors per FAT
	put_address S_SPF, ARG1
	jsr io_write_string
	jsr util_clear_arg1
	lda BUFFERBASE + 22
	sta ARG1
	lda BUFFERBASE + 23
	sta ARG1+1
	mov32_immptrs ARG1, SECTORSPERFAT
	jsr io_write_int32
	jsr io_write_newline

	;; compute position of root directory
	mul32 SECTORSPERFAT, FATCOPIES, ROOTSTART
	add32 ROOTSTART, RESERVEDSECTORS, ROOTSTART
	put_address S_ROT, ARG1
	jsr io_write_string
	mov32_immptrs ROOTSTART, ARG1
	jsr io_write_int32
	jsr io_write_newline

	;; compute size of root directory
	mul32 ROOTENTRIES, CONST32_32, ROOTSIZE
	div32 ROOTSIZE, BYTESPERSECTOR, ROOTSIZE, TMP

	;; compute position of data region
	add32 ROOTSTART, ROOTSIZE, DATASTART
	;; the two first entries in the FAT are special and don't point to data
	;; offset the start of the data region accordingly
	mul32 SECTORSPERCLUSTER, CONST32_2, TMP4
	sub32 DATASTART, TMP4, DATASTART
	put_address S_DAT, ARG1
	jsr io_write_string
	mov32_immptrs DATASTART, ARG1
	jsr io_write_int32
	jsr io_write_newline


	pull_axy
	rts

	S_BPS: .asciiz "bytes per sector: "
	S_SPC: .asciiz "sectors per cluster: "
    S_RES: .asciiz "reserved sectors: "
	S_NFC: .asciiz "FAT copies: "
    S_NRE: .asciiz "root dir entries: "
    S_SPF: .asciiz "sectors per FAT: "
    S_ROT: .asciiz "start sector of root dir: "
	S_DAT: .asciiz "start sector of data region: "
.endproc

;;
;; loads sector denoted by (ARG1,ARG1+1,ARG1+2) into buffer
;;
.proc fat_buffer_sector
	pha

	;; ensure the buffer gets written back if modified
	jsr fat_buffer_flush

	;; memorize sector that is buffered
	mov32 ARG1, BUFFEREDSECTOR

	lda #BUFFERPAGE
	sta ARG2
	jsr io_sd_read_block


	pla
	rts
.endproc


;;
;; write buffer back to storage if modified
;;
.proc fat_buffer_flush
	pha
	lda BUFFERMODIFIED
	beq skip_flush				; only flush if modified

	mov32 BUFFEREDSECTOR, ARG1
	lda #BUFFERPAGE
	sta ARG2
	jsr io_sd_write_block

	lda #0
	sta BUFFERMODIFIED

skip_flush:
	pla
	rts
.endproc


;;
;; list the contents of the root directory
;;
.proc fat_list_rootdir
	push_ax

	;; loop over every sector of root dir
	ldx #0
loop_sectors:

	jsr util_clear_arg1
	stx ARG1
	add32 ARG1, ROOTSTART, ARG1
	jsr fat_buffer_sector
	jsr fat_list_buffer

return:
	inx
	cpx ROOTSIZE
	bne loop_sectors

end:
	pull_ax
	rts
.endproc

;;
;; List directory entries already loaded into buffer.
;;
.proc fat_list_buffer
	push_axy
	push_vregs

	;; initialize position
	mov32_immptrs CONST32_0, POSITION
	lda #BUFFERPAGE
	sta POSITION+1
	
loop_entries:

	mov16 POSITION, VREG1
	ldy #0
	lda (VREG1),y
	beq end									; entry free, no subsequent entry

	ldy #11
	lda (VREG1),y
	and #$02
	bne next_entry							; entry hidden	

	ldy #0
loop_filename:
	lda (VREG1),y
	jsr io_write_char
	iny
	cpy #11
	bne loop_filename

	put_address S_SIZE, ARG1
	jsr io_write_string

	ldy #28
	lda (VREG1),y
	sta ARG1
	iny
	lda (VREG1),y
	sta ARG1+1
	iny
	lda (VREG1),y
	sta ARG1+2
	iny
	lda (VREG1),y
	sta ARG1+3
	jsr io_write_int32

	put_address S_CLUSTER, ARG1
	jsr io_write_string

	jsr util_clear_arg1
	ldy #26
	lda (VREG1),y
	sta ARG1
	iny
	lda (VREG1),y
	sta ARG1+1
	jsr io_write_int32

	jsr io_write_newline

next_entry:
	add32 POSITION, CONST32_32, POSITION	; advance position by 32 bytes
	inx
	cpx #16									; iterate over 16 entries
	beq end
	jmp loop_entries

end:

	pull_vregs
	pull_axy
	rts
	S_SIZE: .asciiz "       bytes: "
	S_CLUSTER: .asciiz "   cluster: "
.endproc


;;
;; Determines next cluster in chain.
;; Reads CURRENTCLUSTER and writes there as well.
;;
.proc fat_next_cluster
	push_ay

	;; compute sector for cluster entry
	mul32 CURRENTCLUSTER, CONST32_2, POSITION			; each cluster entry is two bytes in FAT16
	div32 POSITION, BYTESPERSECTOR, POSITION, OFFSET	; compute sector position and byte offset
	add32 POSITION, RESERVEDSECTORS, POSITION			; add starting position of the FAT

	mov32_immptrs POSITION, ARG1
	jsr fat_buffer_sector				; load sector with the relevant piece of the cluster chain

	jsr util_clear_arg1
	lda #BUFFERPAGE
	sta ARG1+1					; use ARG1 as pointer for a change
	add32 ARG1, OFFSET, ARG1	; add byte offset
	ldy #0
	lda (ARG1),y
	sta CURRENTCLUSTER
	iny
	lda (ARG1),y
	sta CURRENTCLUSTER+1


	pull_ay
	rts
.endproc

;;
;; Load complete cluster (as denoted by CURRENTCLUSTER) into pages starting with CURRENTPAGE.
;; Increments CURRENTPAGE accordingly.
;;
.proc fat_load_cluster
	push_ax


	mul32 CURRENTCLUSTER, SECTORSPERCLUSTER, POSITION
	add32 POSITION, DATASTART, POSITION

	ldx #0
loop_sectors:

	mov32 POSITION, ARG1
	jsr io_write_int32
	lda #C_SP
	jsr io_write_char

	mov32 POSITION, ARG1
	lda CURRENTPAGE
	sta ARG2

	jsr io_sd_read_block

	add32 POSITION, CONST32_1, POSITION		; advance sector position
	inc CURRENTPAGE							; advance page...
	inc CURRENTPAGE							; ... two times (a sector is 512 bytes)
	inx
	cpx SECTORSPERCLUSTER
	bne loop_sectors


	pull_ax
	rts
.endproc

;;
;; Loads a complete file into memory. FILESTART denotes first cluster of file.
;;
.proc fat_load_file
	push_axy

	lda #8				; load starting with page 8
	sta CURRENTPAGE

	mov32_immptrs FILESTART, CURRENTCLUSTER


loop_cluster:
	jsr fat_load_cluster

	jsr fat_next_cluster
	lda CURRENTCLUSTER
	cmp #$FF
	bne next
	lda CURRENTCLUSTER+1
	cmp #$F8
	bpl end
next:
	jmp loop_cluster

end:

	pull_axy
	rts
.endproc

;;
;; (ARG1, ARG+1) shall contain a pointer to a zero-terminated ASCII string.
;; This routine will try to determine the first cluster of the corresponding file
;; and put the result into FILESTART. A value of 0xFFFF denotes "not found".
;;
.proc fat_find_file
	push_axy

	;; ------------------------------------------------------------
	;; put down code for "file not found"
	;; ------------------------------------------------------------
	lda #$FF
	sta FILESTART
	sta FILESTART+1	


	;; ------------------------------------------------------------
	;; fill FILENAME with 11 space characters, terminate with zero
	;; ------------------------------------------------------------
	lda #C_SP
	ldy #0
loop_clear:
	sta FILENAME,y
	iny
	cpy #11
	bne loop_clear
	lda #0
	sta FILENAME,y

	;; ------------------------------------------------------------
	;; copy over chars from requested filename to FILENAME
	;; ------------------------------------------------------------
	ldx #0	; position into FILENAME
	ldy #0	; position into input data
loop_copy:
	lda (ARG1),y
	beq end_loop_copy
	cmp #C_PT		; did we encouter a point, designating start of suffix?
	bne copy		; no? copy char to current position
	ldx #7			; otherwise fast-forward to position for suffix
	bne skip_copy	; and omit the suffix delimiter
copy:
	and #$DF		; to upper-case, FIXME: Will break numerals
	sta FILENAME,x
skip_copy:
	iny
	inx
	cpx #11
	bne loop_copy
end_loop_copy:

	;; ------------------------------------------------------------
	;; loop over every sector of root dir
	;; ------------------------------------------------------------
	ldx #0
loop_sectors:

	jsr util_clear_arg1
	stx ARG1
	add32 ARG1, ROOTSTART, ARG1
	jsr fat_buffer_sector
	jsr fat_find_file_in_buffer

	inx
	cpx ROOTSIZE
	bne loop_sectors


	mov16 FILESTART, RET

	pull_axy
	rts
.endproc

;;
;; Searches through a directory in the buffer.
;;
.proc fat_find_file_in_buffer
	push_axy
	push_vregs

	;; initialize position
	mov32_immptrs CONST32_0, POSITION
	lda #BUFFERPAGE
	sta POSITION+1
	
loop_entries:

	mov16 POSITION, VREG1
	ldy #0
	lda (VREG1),y
	beq end									; entry free, no subsequent entry

	ldy #11
	lda (VREG1),y
	and #$02
	bne next_entry							; entry hidden	
	
	;; ------------------------------------------------------------
	;; copy file name of current entry to FILENAME2 and terminate
	;; ------------------------------------------------------------
	ldy #0
loop_filename:
	lda (VREG1),y
	sta FILENAME2,y
	iny
	cpy #11
	bne loop_filename
	lda #0
	sta FILENAME2,y


	;; ------------------------------------------------------------
	;; compare FILENAME and FILENAME2
	;; ------------------------------------------------------------
	put_address FILENAME, ARG1
	put_address FILENAME2, ARG2
	jsr string_compare
	lda RET
	bne next_entry			; no match? Consider next dir entry!

	;; ------------------------------------------------------------
	;; file name matches!
	;; ------------------------------------------------------------
	ldy #26
	lda (VREG1),y
	sta FILESTART
	iny
	lda (VREG1),y
	sta FILESTART+1
	jmp end

next_entry:
	add32 POSITION, CONST32_32, POSITION	; advance position by 32 bytes
	inx
	cpx #16									; iterate over 16 entries
	beq end
	jmp loop_entries

end:
	pull_vregs
	pull_axy
	rts
.endproc
