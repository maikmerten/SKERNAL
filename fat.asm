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
