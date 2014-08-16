SDPAGE = 4
SDBASE = SDPAGE * 256


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
	jsr io_write_int32
	jsr io_write_newline


	;; sectors per cluster
	put_address S_SPC, ARG1
	jsr io_write_string
	jsr util_clear_arg1
	lda SDBASE + 13
	sta ARG1
	jsr io_write_int32
	jsr io_write_newline	

	;; reserved sectors
	put_address S_RES, ARG1
	jsr io_write_string
	jsr util_clear_arg1
	lda SDBASE + 14
	sta ARG1
	jsr io_write_int32
	jsr io_write_newline

	;; number of FAT copies
	put_address S_NFC, ARG1
	jsr io_write_string
	jsr util_clear_arg1
	lda SDBASE + 16
	sta ARG1
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
	jsr io_write_int32
	jsr io_write_newline

	pull_axy
	rts

	S_BPS: .asciiz "bytes per sector: "
	S_SPC: .asciiz "sectors per cluster: "
    S_RES: .asciiz "reserved sectors: "
	S_NFC: .asciiz "FAT copies: "
    S_NRE: .asciiz "root dir entries: "
.endproc
