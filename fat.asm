SDPAGE = 4
SDBASE = SDPAGE * 256

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

;;
;; read basic information from FAT boot block
;; and do some basic computations regarding the fs layout
;;
.proc fat_init
	push_axy

	jsr util_clear_arg1

	lda #SDPAGE
	sta ARG2

	jsr io_sd_read_block

	;; determine bytes per sector
	put_address S_BPS, ARG1
	jsr io_write_string
	jsr util_clear_arg1
	lda SDBASE + 11
	sta ARG1
	lda SDBASE + 12
	sta ARG1+1
	mov32_immptrs ARG1, BYTESPERSECTOR
	jsr io_write_int32
	jsr io_write_newline


	;; sectors per cluster
	put_address S_SPC, ARG1
	jsr io_write_string
	jsr util_clear_arg1
	lda SDBASE + 13
	sta ARG1
	mov32_immptrs ARG1, SECTORSPERCLUSTER
	jsr io_write_int32
	jsr io_write_newline	

	;; reserved sectors
	put_address S_RES, ARG1
	jsr io_write_string
	jsr util_clear_arg1
	lda SDBASE + 14
	sta ARG1
	mov32_immptrs ARG1, RESERVEDSECTORS
	jsr io_write_int32
	jsr io_write_newline

	;; number of FAT copies
	put_address S_NFC, ARG1
	jsr io_write_string
	jsr util_clear_arg1
	lda SDBASE + 16
	sta ARG1
	mov32_immptrs ARG1, FATCOPIES
	jsr io_write_int32
	jsr io_write_newline

	;; number of root directory entries
	put_address S_NRE, ARG1
	jsr io_write_string
	jsr util_clear_arg1
	lda SDBASE + 17
	sta ARG1
	lda SDBASE + 18
	sta ARG1+1
	mov32_immptrs ARG1, ROOTENTRIES
	jsr io_write_int32
	jsr io_write_newline


	;; sectors per FAT
	put_address S_SPF, ARG1
	jsr io_write_string
	jsr util_clear_arg1
	lda SDBASE + 22
	sta ARG1
	lda SDBASE + 23
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

	put_address fat_list_sector, ARG1
	jsr fat_iterate_rootdir

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
;; load all sectors of the root dir and for each calls
;; the routine pointed to in (ARG1, ARG1+1)
;;
.proc fat_iterate_rootdir
	push_ax
	push_vregs

	mov16 ARG1, VREG1

	;; loop over every sector of root dir
	ldx #0
loop_sectors:

	jsr util_clear_arg1
	stx ARG1
	add32 ARG1, ROOTSTART, ARG1
	jsr util_clear_arg2
	lda #SDPAGE
	sta ARG2
	jsr io_sd_read_block

	prepare_rts return
	jmp (VREG1)

return:
	inx
	cpx ROOTSIZE
	bne loop_sectors

end:
	pull_vregs
	pull_ax
	rts

.endproc

;;
;; list directory entries contained in an in-memory sector
;;
.proc fat_list_sector
	push_axy
	push_vregs

	;; initialize position
	mov32_immptrs CONST32_0, POSITION
	lda #SDPAGE
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
