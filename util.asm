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






