;; Macros ###########################################################

.macro push_axy
	pha		; push accumulator to stack
	txa		; x -> a
	pha		; push x to stack
	tya		; y -> a
	pha		; push y to stack
.endmacro

.macro pull_axy
	pla		; pull y from stack
	tay		; a -> y
	pla		; pull x from stack
	tax		; a -> x
	pla		; pull a from stack
.endmacro


.macro push_ax
	pha
	txa
	pha
.endmacro


.macro pull_ax
	pla
	tax
	pla
.endmacro

.macro push_ay
	pha
	tya
	pha
.endmacro


.macro pull_ay
	pla
	tay
	pla
.endmacro


.macro push_vregs
	lda VREG1
	pha
	lda VREG2
	pha
.endmacro


.macro pull_vregs
	pla
	sta VREG2
	pla
	sta VREG1
.endmacro


.macro put_address ADDR, L1, L2
	lda #<ADDR
	sta L1
	lda #>ADDR
 .ifnblank L2
	sta L2
 .else
	sta L1+1
 .endif
.endmacro

.macro mov SRC1, DEST1, SRC2, DEST2, SRC3, DEST3, SRC4, DEST4
	lda SRC1
	sta DEST1
 .ifnblank SRC2
  .ifnblank DEST2
	lda SRC2
	sta DEST2
  .endif
 .endif
 .ifnblank SRC3
  .ifnblank DEST3
	lda SRC3
	sta DEST3
  .endif
 .endif
 .ifnblank SRC4
  .ifnblank DEST4
	lda SRC4
	sta DEST4
  .endif
 .endif
.endmacro


.macro mov16 SRC, DEST
	lda SRC
	sta DEST
	lda SRC+1
	sta DEST+1
.endmacro

.macro mov32 SRC, DEST
	lda SRC
	sta DEST
	lda SRC+1
	sta DEST+1
	lda SRC+2
	sta DEST+2
	lda SRC+3
	sta DEST+3
.endmacro


.macro prepare_rts ADDR
	lda #>(ADDR - 1)
	pha
	lda #<(ADDR - 1)
	pha
.endmacro


