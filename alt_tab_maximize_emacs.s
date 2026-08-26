	.file	"alt_tab_maximize_emacs-buffer_only.c"
	.text
	.p2align 4,,15
	.globl	handle_error
	.type	handle_error, @function
handle_error:
.LFB36:
	.cfi_startproc
	xorl	%eax, %eax
	ret
	.cfi_endproc
.LFE36:
	.size	handle_error, .-handle_error
	.p2align 4,,15
	.globl	get_color
	.type	get_color, @function
get_color:
.LFB23:
	.cfi_startproc
	pushq	%rbx
	.cfi_def_cfa_offset 16
	.cfi_offset 3, -16
	movq	%rdi, %rdx
	subq	$16, %rsp
	.cfi_def_cfa_offset 32
	movq	dpy(%rip), %rdi
	movslq	screen(%rip), %rax
	movq	%rsp, %rcx
	salq	$7, %rax
	addq	232(%rdi), %rax
	movq	80(%rax), %rbx
	movq	%rbx, %rsi
	call	XParseColor
	testl	%eax, %eax
	jne	.L13
.L4:
	movslq	screen(%rip), %rax
	movq	dpy(%rip), %rdx
	salq	$7, %rax
	addq	232(%rdx), %rax
	movq	96(%rax), %rax
	addq	$16, %rsp
	.cfi_remember_state
	.cfi_def_cfa_offset 16
	popq	%rbx
	.cfi_def_cfa_offset 8
	ret
	.p2align 4,,10
	.p2align 3
.L13:
	.cfi_restore_state
	movq	dpy(%rip), %rdi
	movq	%rsp, %rdx
	movq	%rbx, %rsi
	call	XAllocColor
	testl	%eax, %eax
	je	.L4
	movq	(%rsp), %rax
	addq	$16, %rsp
	.cfi_def_cfa_offset 16
	popq	%rbx
	.cfi_def_cfa_offset 8
	ret
	.cfi_endproc
.LFE23:
	.size	get_color, .-get_color
	.section	.rodata.str1.1,"aMS",@progbits,1
.LC0:
	.string	"#ecefe4"
.LC1:
	.string	"#16161a"
.LC2:
	.string	"#7209b7"
.LC3:
	.string	"#ffffff"
.LC4:
	.string	"#3f37c9"
.LC5:
	.string	"#4cc9f0"
.LC6:
	.string	"#f72585"
	.text
	.p2align 4,,15
	.globl	init_colors
	.type	init_colors, @function
init_colors:
.LFB24:
	.cfi_startproc
	subq	$8, %rsp
	.cfi_def_cfa_offset 16
	movl	$.LC0, %edi
	call	get_color
	movl	$.LC1, %edi
	movq	%rax, color_bg(%rip)
	call	get_color
	movl	$.LC2, %edi
	movq	%rax, color_fg(%rip)
	call	get_color
	movl	$.LC3, %edi
	movq	%rax, color_sel_bg(%rip)
	call	get_color
	movl	$.LC4, %edi
	movq	%rax, color_sel_fg(%rip)
	call	get_color
	movl	$.LC5, %edi
	movq	%rax, color_border(%rip)
	call	get_color
	movl	$.LC6, %edi
	movq	%rax, color_cyan(%rip)
	call	get_color
	movq	%rax, color_magenta(%rip)
	addq	$8, %rsp
	.cfi_def_cfa_offset 8
	ret
	.cfi_endproc
.LFE24:
	.size	init_colors, .-init_colors
	.section	.rodata.str1.1
.LC7:
	.string	"%s"
.LC8:
	.string	"Untitled Window"
	.text
	.p2align 4,,15
	.globl	get_window_title
	.type	get_window_title, @function
get_window_title:
.LFB25:
	.cfi_startproc
	pushq	%r12
	.cfi_def_cfa_offset 16
	.cfi_offset 12, -16
	movq	%rsi, %r12
	movq	%rdi, %rsi
	pushq	%rbp
	.cfi_def_cfa_offset 24
	.cfi_offset 6, -24
	movq	%rdi, %rbp
	pushq	%rbx
	.cfi_def_cfa_offset 32
	.cfi_offset 3, -32
	movslq	%edx, %rbx
	subq	$48, %rsp
	.cfi_def_cfa_offset 80
	movq	dpy(%rip), %rdi
	movq	$0, 8(%rsp)
	leaq	8(%rsp), %rdx
	call	XFetchName
	movq	8(%rsp), %rdi
	testl	%eax, %eax
	je	.L17
	testq	%rdi, %rdi
	je	.L18
	cmpb	$0, (%rdi)
	jne	.L33
.L19:
	call	XFree
.L18:
	leaq	40(%rsp), %rax
	xorl	%r9d, %r9d
	movl	$1024, %r8d
	xorl	%ecx, %ecx
	movq	$0, 40(%rsp)
	movq	atom_net_wm_name(%rip), %rdx
	movq	%rbp, %rsi
	pushq	%rax
	.cfi_def_cfa_offset 88
	movq	dpy(%rip), %rdi
	leaq	40(%rsp), %rax
	pushq	%rax
	.cfi_def_cfa_offset 96
	leaq	40(%rsp), %rax
	pushq	%rax
	.cfi_def_cfa_offset 104
	leaq	28(%rsp), %rax
	pushq	%rax
	.cfi_def_cfa_offset 112
	leaq	48(%rsp), %rax
	pushq	%rax
	.cfi_def_cfa_offset 120
	pushq	atom_utf8_string(%rip)
	.cfi_def_cfa_offset 128
	call	XGetWindowProperty
	addq	$48, %rsp
	.cfi_def_cfa_offset 80
	testl	%eax, %eax
	jne	.L21
	movq	40(%rsp), %rcx
	testq	%rcx, %rcx
	jne	.L34
.L21:
	movl	$.LC8, %edx
	movq	%rbx, %rsi
	movq	%r12, %rdi
	xorl	%eax, %eax
	call	snprintf
.L16:
	addq	$48, %rsp
	.cfi_remember_state
	.cfi_def_cfa_offset 32
	popq	%rbx
	.cfi_def_cfa_offset 24
	popq	%rbp
	.cfi_def_cfa_offset 16
	popq	%r12
	.cfi_def_cfa_offset 8
	ret
	.p2align 4,,10
	.p2align 3
.L17:
	.cfi_restore_state
	testq	%rdi, %rdi
	je	.L18
	jmp	.L19
	.p2align 4,,10
	.p2align 3
.L34:
	movq	%rbx, %rsi
	movq	%r12, %rdi
	movl	$.LC7, %edx
	call	snprintf
	movq	40(%rsp), %rdi
	call	XFree
	addq	$48, %rsp
	.cfi_remember_state
	.cfi_def_cfa_offset 32
	popq	%rbx
	.cfi_def_cfa_offset 24
	popq	%rbp
	.cfi_def_cfa_offset 16
	popq	%r12
	.cfi_def_cfa_offset 8
	ret
	.p2align 4,,10
	.p2align 3
.L33:
	.cfi_restore_state
	movq	%rdi, %rcx
	movl	$.LC7, %edx
	movq	%r12, %rdi
	movq	%rbx, %rsi
	xorl	%eax, %eax
	call	snprintf
	movq	8(%rsp), %rdi
	call	XFree
	jmp	.L16
	.cfi_endproc
.LFE25:
	.size	get_window_title, .-get_window_title
	.section	.rodata.str1.1
.LC9:
	.string	"emacs"
	.text
	.p2align 4,,15
	.globl	is_emacs
	.type	is_emacs, @function
is_emacs:
.LFB26:
	.cfi_startproc
	pushq	%rbp
	.cfi_def_cfa_offset 16
	.cfi_offset 6, -16
	movq	%rdi, %rsi
	pushq	%rbx
	.cfi_def_cfa_offset 24
	.cfi_offset 3, -24
	subq	$24, %rsp
	.cfi_def_cfa_offset 48
	movq	dpy(%rip), %rdi
	movq	%rsp, %rdx
	call	XGetClassHint
	movl	%eax, %ebx
	testl	%eax, %eax
	je	.L35
	movq	(%rsp), %rbp
	testq	%rbp, %rbp
	je	.L37
	movl	$.LC9, %esi
	movq	%rbp, %rdi
	call	strcasecmp
	testl	%eax, %eax
	jne	.L38
	movl	$1, %ebx
.L40:
	movq	%rbp, %rdi
	call	XFree
	movq	8(%rsp), %rbp
	testq	%rbp, %rbp
	je	.L35
.L41:
	movq	%rbp, %rdi
	call	XFree
.L35:
	addq	$24, %rsp
	.cfi_remember_state
	.cfi_def_cfa_offset 24
	movl	%ebx, %eax
	popq	%rbx
	.cfi_def_cfa_offset 16
	popq	%rbp
	.cfi_def_cfa_offset 8
	ret
	.p2align 4,,10
	.p2align 3
.L38:
	.cfi_restore_state
	movq	8(%rsp), %rdi
	xorl	%ebx, %ebx
	testq	%rdi, %rdi
	je	.L40
	movl	$.LC9, %esi
	xorl	%ebx, %ebx
	call	strcasecmp
	testl	%eax, %eax
	sete	%bl
	jmp	.L40
	.p2align 4,,10
	.p2align 3
.L37:
	movq	8(%rsp), %rbp
	xorl	%ebx, %ebx
	testq	%rbp, %rbp
	je	.L35
	movl	$.LC9, %esi
	movq	%rbp, %rdi
	xorl	%ebx, %ebx
	call	strcasecmp
	testl	%eax, %eax
	sete	%bl
	jmp	.L41
	.cfi_endproc
.LFE26:
	.size	is_emacs, .-is_emacs
	.section	.rodata.str1.1
.LC10:
	.string	"w"
.LC11:
	.string	"/tmp/emacs_non_emacs_windows"
.LC12:
	.string	"%lu\t%s\n"
	.text
	.p2align 4,,15
	.globl	update_window_list_file
	.type	update_window_list_file, @function
update_window_list_file:
.LFB27:
	.cfi_startproc
	pushq	%r12
	.cfi_def_cfa_offset 16
	.cfi_offset 12, -16
	movl	$.LC10, %esi
	movl	$.LC11, %edi
	pushq	%rbp
	.cfi_def_cfa_offset 24
	.cfi_offset 6, -24
	pushq	%rbx
	.cfi_def_cfa_offset 32
	.cfi_offset 3, -32
	subq	$256, %rsp
	.cfi_def_cfa_offset 288
	call	fopen
	testq	%rax, %rax
	je	.L51
	movq	%rax, %r12
	movl	num_managed(%rip), %eax
	testl	%eax, %eax
	jle	.L53
	xorl	%ebx, %ebx
	jmp	.L55
	.p2align 4,,10
	.p2align 3
.L54:
	addq	$1, %rbx
	cmpl	%ebx, num_managed(%rip)
	jle	.L53
.L55:
	movq	managed_windows(,%rbx,8), %rbp
	movq	%rbp, %rdi
	call	is_emacs
	testl	%eax, %eax
	jne	.L54
	movl	$256, %edx
	movq	%rsp, %rsi
	movq	%rbp, %rdi
	addq	$1, %rbx
	call	get_window_title
	xorl	%eax, %eax
	movq	%rsp, %rcx
	movq	%rbp, %rdx
	movl	$.LC12, %esi
	movq	%r12, %rdi
	call	fprintf
	cmpl	%ebx, num_managed(%rip)
	jg	.L55
.L53:
	movq	%r12, %rdi
	call	fclose
.L51:
	addq	$256, %rsp
	.cfi_def_cfa_offset 32
	popq	%rbx
	.cfi_def_cfa_offset 24
	popq	%rbp
	.cfi_def_cfa_offset 16
	popq	%r12
	.cfi_def_cfa_offset 8
	ret
	.cfi_endproc
.LFE27:
	.size	update_window_list_file, .-update_window_list_file
	.p2align 4,,15
	.globl	remove_window
	.type	remove_window, @function
remove_window:
.LFB28:
	.cfi_startproc
	movl	num_managed(%rip), %esi
	testl	%esi, %esi
	jle	.L71
	cmpq	managed_windows(%rip), %rdi
	pushq	%rbx
	.cfi_def_cfa_offset 16
	.cfi_offset 3, -16
	je	.L74
	leal	-1(%rsi), %ecx
	movl	$1, %eax
	movq	%rcx, %rbx
	addq	$1, %rcx
	jmp	.L65
	.p2align 4,,10
	.p2align 3
.L66:
	addq	$1, %rax
	cmpq	%rdi, managed_windows-8(,%rax,8)
	je	.L75
.L65:
	movslq	%eax, %rdx
	cmpq	%rax, %rcx
	jne	.L66
	popq	%rbx
	.cfi_remember_state
	.cfi_def_cfa_offset 8
	ret
	.p2align 4,,10
	.p2align 3
.L75:
	.cfi_restore_state
	movl	%esi, %eax
	subl	%edx, %eax
	salq	$3, %rdx
	leaq	managed_windows(%rdx), %rdi
	leaq	8(%rdx), %rsi
.L63:
	leal	-1(%rax), %edx
	addq	$managed_windows, %rsi
	movslq	%edx, %rdx
	salq	$3, %rdx
	call	memmove
	movl	%ebx, num_managed(%rip)
	xorl	%eax, %eax
	popq	%rbx
	.cfi_remember_state
	.cfi_restore 3
	.cfi_def_cfa_offset 8
	jmp	update_window_list_file
.L74:
	.cfi_restore_state
	movl	%esi, %eax
	movl	$managed_windows, %edi
	movl	$8, %esi
	leal	-1(%rax), %ebx
	jmp	.L63
.L71:
	.cfi_def_cfa_offset 8
	.cfi_restore 3
	ret
	.cfi_endproc
.LFE28:
	.size	remove_window, .-remove_window
	.p2align 4,,15
	.globl	add_window
	.type	add_window, @function
add_window:
.LFB29:
	.cfi_startproc
	pushq	%r12
	.cfi_def_cfa_offset 16
	.cfi_offset 12, -16
	pushq	%rbp
	.cfi_def_cfa_offset 24
	.cfi_offset 6, -24
	movq	%rdi, %rbp
	pushq	%rbx
	.cfi_def_cfa_offset 32
	.cfi_offset 3, -32
	movl	num_managed(%rip), %ebx
	testl	%ebx, %ebx
	jle	.L77
	cmpq	managed_windows(%rip), %rdi
	je	.L88
	leal	-1(%rbx), %ecx
	movl	$1, %eax
	movq	%rcx, %r12
	addq	$1, %rcx
	jmp	.L80
	.p2align 4,,10
	.p2align 3
.L82:
	addq	$1, %rax
	cmpq	%rbp, managed_windows-8(,%rax,8)
	je	.L89
.L80:
	movslq	%eax, %rdx
	cmpq	%rax, %rcx
	jne	.L82
	cmpl	$999, %ebx
	jle	.L77
.L76:
	popq	%rbx
	.cfi_remember_state
	.cfi_def_cfa_offset 24
	popq	%rbp
	.cfi_def_cfa_offset 16
	popq	%r12
	.cfi_def_cfa_offset 8
	ret
	.p2align 4,,10
	.p2align 3
.L89:
	.cfi_restore_state
	subl	%edx, %ebx
	salq	$3, %rdx
	leaq	managed_windows(%rdx), %rdi
	leaq	8(%rdx), %rsi
.L78:
	subl	$1, %ebx
	addq	$managed_windows, %rsi
	movslq	%ebx, %rdx
	movl	%r12d, %ebx
	salq	$3, %rdx
	call	memmove
	movl	%r12d, num_managed(%rip)
	cmpl	$999, %ebx
	jg	.L76
.L77:
	movslq	%ebx, %rdx
	movl	$managed_windows, %esi
	movl	$managed_windows+8, %edi
	addl	$1, %ebx
	salq	$3, %rdx
	call	memmove
	movq	dpy(%rip), %rdi
	movq	%rbp, %rsi
	movl	$4194304, %edx
	movq	%rbp, managed_windows(%rip)
	movl	%ebx, num_managed(%rip)
	call	XSelectInput
	popq	%rbx
	.cfi_remember_state
	.cfi_def_cfa_offset 24
	xorl	%eax, %eax
	popq	%rbp
	.cfi_def_cfa_offset 16
	popq	%r12
	.cfi_def_cfa_offset 8
	jmp	update_window_list_file
.L88:
	.cfi_restore_state
	movl	$8, %esi
	movl	$managed_windows, %edi
	leal	-1(%rbx), %r12d
	jmp	.L78
	.cfi_endproc
.LFE29:
	.size	add_window, .-add_window
	.section	.rodata.str1.1
.LC13:
	.string	"ALT_TAB_SYNC_LOG"
.LC14:
	.string	"a"
.LC15:
	.string	"/tmp/alt_tab_wm.log"
	.text
	.p2align 4,,15
	.globl	log_wm
	.type	log_wm, @function
log_wm:
.LFB30:
	.cfi_startproc
	pushq	%rbx
	.cfi_def_cfa_offset 16
	.cfi_offset 3, -16
	movq	%rdi, %rbx
	subq	$208, %rsp
	.cfi_def_cfa_offset 224
	movq	%rsi, 40(%rsp)
	movq	%rdx, 48(%rsp)
	movq	%rcx, 56(%rsp)
	movq	%r8, 64(%rsp)
	movq	%r9, 72(%rsp)
	testb	%al, %al
	je	.L97
	movaps	%xmm0, 80(%rsp)
	movaps	%xmm1, 96(%rsp)
	movaps	%xmm2, 112(%rsp)
	movaps	%xmm3, 128(%rsp)
	movaps	%xmm4, 144(%rsp)
	movaps	%xmm5, 160(%rsp)
	movaps	%xmm6, 176(%rsp)
	movaps	%xmm7, 192(%rsp)
.L97:
	cmpq	$0, log_file(%rip)
	je	.L92
.L95:
	leaq	224(%rsp), %rax
	movq	log_file(%rip), %rdi
	leaq	8(%rsp), %rdx
	movq	%rbx, %rsi
	movq	%rax, 16(%rsp)
	leaq	32(%rsp), %rax
	movl	$8, 8(%rsp)
	movl	$48, 12(%rsp)
	movq	%rax, 24(%rsp)
	call	vfprintf
	movq	log_file(%rip), %rsi
	movl	$10, %edi
	call	fputc
	movl	$.LC13, %edi
	call	getenv
	testq	%rax, %rax
	je	.L90
	movq	log_file(%rip), %rdi
	call	fflush
.L90:
	addq	$208, %rsp
	.cfi_remember_state
	.cfi_def_cfa_offset 16
	popq	%rbx
	.cfi_def_cfa_offset 8
	ret
	.p2align 4,,10
	.p2align 3
.L92:
	.cfi_restore_state
	movl	$.LC14, %esi
	movl	$.LC15, %edi
	call	fopen
	movq	%rax, log_file(%rip)
	testq	%rax, %rax
	jne	.L95
	addq	$208, %rsp
	.cfi_def_cfa_offset 16
	popq	%rbx
	.cfi_def_cfa_offset 8
	ret
	.cfi_endproc
.LFE30:
	.size	log_wm, .-log_wm
	.section	.rodata.str1.8,"aMS",@progbits,1
	.align 8
.LC16:
	.string	"[is_manageable] Window 0x%lx: Failed to get attributes -> NO"
	.align 8
.LC17:
	.string	"[is_manageable] Window 0x%lx: override_redirect=True -> NO"
	.align 8
.LC18:
	.string	"[is_manageable] Window 0x%lx: transient_for=0x%lx -> NO"
	.align 8
.LC19:
	.string	"[is_manageable] Window 0x%lx: fixed size (%dx%d) -> NO"
	.align 8
.LC20:
	.string	"[is_manageable] Window 0x%lx: max_size too small (%dx%d) -> NO"
	.align 8
.LC22:
	.string	"[is_manageable] Window 0x%lx ('%s'): MWM undecorated + dimensions (%dx%d) -> NO"
	.align 8
.LC23:
	.string	"[is_manageable] Window 0x%lx ('%s'): default -> YES"
	.align 8
.LC24:
	.string	"[is_manageable] Window 0x%lx: Explicit _NET_WM_WINDOW_TYPE_NORMAL -> YES"
	.align 8
.LC25:
	.string	"[is_manageable] Window 0x%lx: Matched non-normal _NET_WM_WINDOW_TYPE -> NO"
	.text
	.p2align 4,,15
	.globl	is_manageable
	.type	is_manageable, @function
is_manageable:
.LFB31:
	.cfi_startproc
	pushq	%r15
	.cfi_def_cfa_offset 16
	.cfi_offset 15, -16
	movq	%rdi, %rsi
	pushq	%r14
	.cfi_def_cfa_offset 24
	.cfi_offset 14, -24
	pushq	%r13
	.cfi_def_cfa_offset 32
	.cfi_offset 13, -32
	pushq	%r12
	.cfi_def_cfa_offset 40
	.cfi_offset 12, -40
	pushq	%rbp
	.cfi_def_cfa_offset 48
	.cfi_offset 6, -48
	movq	%rdi, %rbp
	pushq	%rbx
	.cfi_def_cfa_offset 56
	.cfi_offset 3, -56
	subq	$616, %rsp
	.cfi_def_cfa_offset 672
	movq	dpy(%rip), %rdi
	leaq	208(%rsp), %rdx
	call	XGetWindowAttributes
	testl	%eax, %eax
	je	.L170
	movl	328(%rsp), %ebx
	testl	%ebx, %ebx
	jne	.L171
	movq	dpy(%rip), %rdi
	leaq	80(%rsp), %rdx
	movq	%rbp, %rsi
	movq	$0, 80(%rsp)
	call	XGetTransientForHint
	testl	%eax, %eax
	je	.L104
	movq	80(%rsp), %rdx
	testq	%rdx, %rdx
	jne	.L172
.L104:
	movq	dpy(%rip), %rdi
	leaq	88(%rsp), %rcx
	leaq	128(%rsp), %rdx
	movq	%rbp, %rsi
	call	XGetWMNormalHints
	testl	%eax, %eax
	je	.L105
	movq	128(%rsp), %rax
	movq	%rax, %rdx
	andl	$48, %edx
	cmpq	$48, %rdx
	je	.L173
.L106:
	testb	$32, %al
	je	.L105
	movl	screen_width(%rip), %esi
	movl	160(%rsp), %edx
	movl	164(%rsp), %ecx
	movl	%esi, %eax
	shrl	$31, %eax
	addl	%esi, %eax
	sarl	%eax
	cmpl	%eax, %edx
	jl	.L107
	movl	screen_height(%rip), %esi
	movl	%esi, %eax
	shrl	$31, %eax
	addl	%esi, %eax
	sarl	%eax
	cmpl	%ecx, %eax
	jg	.L107
.L105:
	leaq	120(%rsp), %r15
	xorl	%r9d, %r9d
	movl	$32, %r8d
	xorl	%ecx, %ecx
	movq	$0, 120(%rsp)
	movq	atom_net_wm_type(%rip), %rdx
	movq	%rbp, %rsi
	pushq	%r15
	.cfi_def_cfa_offset 680
	movq	dpy(%rip), %rdi
	leaq	120(%rsp), %r14
	pushq	%r14
	.cfi_def_cfa_offset 688
	leaq	120(%rsp), %r13
	pushq	%r13
	.cfi_def_cfa_offset 696
	leaq	100(%rsp), %rax
	pushq	%rax
	.cfi_def_cfa_offset 704
	leaq	128(%rsp), %r12
	pushq	%r12
	.cfi_def_cfa_offset 712
	pushq	$4
	.cfi_def_cfa_offset 720
	call	XGetWindowProperty
	addq	$48, %rsp
	.cfi_def_cfa_offset 672
	movl	%eax, %ebx
	testl	%eax, %eax
	jne	.L108
	movq	120(%rsp), %rdi
	testq	%rdi, %rdi
	je	.L108
	movq	104(%rsp), %rcx
	testq	%rcx, %rcx
	je	.L109
	movq	(%rdi), %r9
	movq	atom_type_dropdown(%rip), %rsi
	cmpq	%r9, %rsi
	je	.L110
	movq	atom_type_popup(%rip), %r8
	cmpq	%r9, %r8
	je	.L110
	movq	atom_type_menu(%rip), %r11
	cmpq	%r9, %r11
	je	.L110
	movq	atom_type_tooltip(%rip), %r10
	cmpq	%r9, %r10
	je	.L110
	movq	atom_type_combo(%rip), %rdx
	movq	atom_type_notification(%rip), %rax
	movq	%r9, 56(%rsp)
	movl	%ebx, 52(%rsp)
	movq	%rdx, 32(%rsp)
	movq	atom_type_dialog(%rip), %rdx
	movq	%rax, 24(%rsp)
	movq	atom_type_utility(%rip), %rax
	movq	%rdx, (%rsp)
	movq	atom_type_dock(%rip), %rdx
	movq	%rax, 40(%rsp)
	movq	32(%rsp), %rbx
	movq	%r9, %rax
	movq	%rdx, 8(%rsp)
	movq	atom_type_splash(%rip), %rdx
	movq	24(%rsp), %r9
	movq	%rbp, 24(%rsp)
	movq	%rdx, 16(%rsp)
	movq	40(%rsp), %rbp
	xorl	%edx, %edx
	jmp	.L111
	.p2align 4,,10
	.p2align 3
.L175:
	cmpq	%rax, %rbx
	je	.L165
	cmpq	%rax, %rbp
	je	.L165
	cmpq	%rax, (%rsp)
	je	.L165
	cmpq	%rax, 8(%rsp)
	je	.L165
	cmpq	%rax, 16(%rsp)
	je	.L165
	addq	$1, %rdx
	cmpq	%rdx, %rcx
	je	.L174
	movq	(%rdi,%rdx,8), %rax
	cmpq	%rsi, %rax
	je	.L165
	cmpq	%r8, %rax
	je	.L165
	cmpq	%r11, %rax
	je	.L165
	cmpq	%r10, %rax
	je	.L165
.L111:
	cmpq	%rax, %r9
	jne	.L175
	.p2align 4,,10
	.p2align 3
.L165:
	movl	52(%rsp), %ebx
	movq	24(%rsp), %rbp
.L110:
	movq	%rbp, %rsi
	movl	$.LC25, %edi
	xorl	%eax, %eax
	call	log_wm
	movq	120(%rsp), %rdi
	call	XFree
	jmp	.L100
	.p2align 4,,10
	.p2align 3
.L174:
	movq	56(%rsp), %r9
	movq	atom_type_normal(%rip), %rdx
	movq	24(%rsp), %rbp
	cmpq	%r9, %rdx
	je	.L114
	xorl	%eax, %eax
	jmp	.L121
	.p2align 4,,10
	.p2align 3
.L115:
	cmpq	%rdx, (%rdi,%rax,8)
	je	.L114
.L121:
	addq	$1, %rax
	cmpq	%rax, %rcx
	ja	.L115
.L109:
	call	XFree
.L108:
	pushq	%r15
	.cfi_def_cfa_offset 680
	movq	atom_motif_wm_hints(%rip), %rdx
	xorl	%r9d, %r9d
	xorl	%ecx, %ecx
	pushq	%r14
	.cfi_def_cfa_offset 688
	movq	dpy(%rip), %rdi
	movl	$20, %r8d
	movq	%rbp, %rsi
	pushq	%r13
	.cfi_def_cfa_offset 696
	leaq	100(%rsp), %rax
	pushq	%rax
	.cfi_def_cfa_offset 704
	pushq	%r12
	.cfi_def_cfa_offset 712
	pushq	%rdx
	.cfi_def_cfa_offset 720
	call	XGetWindowProperty
	addq	$48, %rsp
	.cfi_def_cfa_offset 672
	movl	%eax, %ebx
	testl	%eax, %eax
	jne	.L169
	movq	120(%rsp), %rdi
	testq	%rdi, %rdi
	je	.L169
	cmpq	$4, 104(%rsp)
	leaq	352(%rsp), %r12
	jbe	.L117
	testb	$2, (%rdi)
	je	.L117
	cmpq	$0, 16(%rdi)
	je	.L176
.L117:
	call	XFree
	jmp	.L116
	.p2align 4,,10
	.p2align 3
.L171:
	movq	%rbp, %rsi
	movl	$.LC17, %edi
	xorl	%eax, %eax
	xorl	%ebx, %ebx
	call	log_wm
.L100:
	addq	$616, %rsp
	.cfi_remember_state
	.cfi_def_cfa_offset 56
	movl	%ebx, %eax
	popq	%rbx
	.cfi_def_cfa_offset 48
	popq	%rbp
	.cfi_def_cfa_offset 40
	popq	%r12
	.cfi_def_cfa_offset 32
	popq	%r13
	.cfi_def_cfa_offset 24
	popq	%r14
	.cfi_def_cfa_offset 16
	popq	%r15
	.cfi_def_cfa_offset 8
	ret
	.p2align 4,,10
	.p2align 3
.L170:
	.cfi_restore_state
	movl	%eax, %ebx
	movq	%rbp, %rsi
	movl	$.LC16, %edi
	xorl	%eax, %eax
	call	log_wm
	jmp	.L100
	.p2align 4,,10
	.p2align 3
.L172:
	cmpq	root(%rip), %rdx
	je	.L104
	movq	%rbp, %rsi
	movl	$.LC18, %edi
	xorl	%eax, %eax
	call	log_wm
	jmp	.L100
	.p2align 4,,10
	.p2align 3
.L169:
	leaq	352(%rsp), %r12
.L116:
	movl	$256, %edx
	movq	%r12, %rsi
	movq	%rbp, %rdi
	movl	$1, %ebx
	call	get_window_title
	movq	%r12, %rdx
	movq	%rbp, %rsi
	movl	$.LC23, %edi
	xorl	%eax, %eax
	call	log_wm
	jmp	.L100
	.p2align 4,,10
	.p2align 3
.L107:
	movq	%rbp, %rsi
	movl	$.LC20, %edi
	xorl	%eax, %eax
	call	log_wm
	jmp	.L100
	.p2align 4,,10
	.p2align 3
.L173:
	movl	152(%rsp), %edx
	testl	%edx, %edx
	jle	.L106
	movl	156(%rsp), %ecx
	testl	%ecx, %ecx
	jle	.L106
	movq	160(%rsp), %rsi
	cmpq	%rsi, 152(%rsp)
	jne	.L106
	movq	%rbp, %rsi
	movl	$.LC19, %edi
	xorl	%eax, %eax
	call	log_wm
	jmp	.L100
	.p2align 4,,10
	.p2align 3
.L176:
	movl	$256, %edx
	movq	%r12, %rsi
	movq	%rbp, %rdi
	call	get_window_title
	pxor	%xmm0, %xmm0
	movl	216(%rsp), %ecx
	movsd	.LC21(%rip), %xmm1
	cvtsi2sd	screen_width(%rip), %xmm0
	pxor	%xmm2, %xmm2
	cvtsi2sd	%ecx, %xmm2
	mulsd	%xmm1, %xmm0
	comisd	%xmm2, %xmm0
	jbe	.L118
	pxor	%xmm0, %xmm0
	movl	220(%rsp), %r8d
	pxor	%xmm2, %xmm2
	cvtsi2sd	screen_height(%rip), %xmm0
	cvtsi2sd	%r8d, %xmm2
	mulsd	%xmm0, %xmm1
	comisd	%xmm2, %xmm1
	ja	.L177
.L118:
	movq	120(%rsp), %rdi
	jmp	.L117
	.p2align 4,,10
	.p2align 3
.L114:
	call	XFree
	movq	%rbp, %rsi
	movl	$.LC24, %edi
	xorl	%eax, %eax
	call	log_wm
	movl	$1, %ebx
	jmp	.L100
.L177:
	movq	%r12, %rdx
	movq	%rbp, %rsi
	movl	$.LC22, %edi
	xorl	%eax, %eax
	call	log_wm
	movq	120(%rsp), %rdi
	call	XFree
	jmp	.L100
	.cfi_endproc
.LFE31:
	.size	is_manageable, .-is_manageable
	.section	.rodata.str1.8
	.align 8
.LC26:
	.string	"[maximize_window] Maximizing Window 0x%lx to (%d x %d)"
	.text
	.p2align 4,,15
	.globl	maximize_window
	.type	maximize_window, @function
maximize_window:
.LFB32:
	.cfi_startproc
	pushq	%rbx
	.cfi_def_cfa_offset 16
	.cfi_offset 3, -16
	movq	%rdi, %rbx
	call	is_manageable
	testl	%eax, %eax
	jne	.L181
	popq	%rbx
	.cfi_remember_state
	.cfi_def_cfa_offset 8
	ret
	.p2align 4,,10
	.p2align 3
.L181:
	.cfi_restore_state
	movl	screen_height(%rip), %ecx
	movq	%rbx, %rsi
	movl	$.LC26, %edi
	xorl	%eax, %eax
	movl	screen_width(%rip), %edx
	call	log_wm
	movq	dpy(%rip), %rdi
	xorl	%edx, %edx
	xorl	%ecx, %ecx
	movl	screen_height(%rip), %r9d
	movl	screen_width(%rip), %r8d
	movq	%rbx, %rsi
	call	XMoveResizeWindow
	movq	dpy(%rip), %rdi
	movq	%rbx, %rsi
	xorl	%edx, %edx
	popq	%rbx
	.cfi_def_cfa_offset 8
	jmp	XSetWindowBorderWidth
	.cfi_endproc
.LFE32:
	.size	maximize_window, .-maximize_window
	.section	.rodata.str1.1
.LC27:
	.string	"ALT_TAB_GLITCH"
.LC28:
	.string	"0"
	.text
	.p2align 4,,15
	.globl	glitch_window
	.type	glitch_window, @function
glitch_window:
.LFB33:
	.cfi_startproc
	pushq	%r15
	.cfi_def_cfa_offset 16
	.cfi_offset 15, -16
	pushq	%r14
	.cfi_def_cfa_offset 24
	.cfi_offset 14, -24
	pushq	%r13
	.cfi_def_cfa_offset 32
	.cfi_offset 13, -32
	pushq	%r12
	.cfi_def_cfa_offset 40
	.cfi_offset 12, -40
	pushq	%rbp
	.cfi_def_cfa_offset 48
	.cfi_offset 6, -48
	pushq	%rbx
	.cfi_def_cfa_offset 56
	.cfi_offset 3, -56
	movq	%rdi, %rbx
	movl	$.LC27, %edi
	subq	$280, %rsp
	.cfi_def_cfa_offset 336
	call	getenv
	testq	%rax, %rax
	je	.L183
	movq	%rax, %rsi
	movl	$.LC28, %edi
	movl	$2, %ecx
	repz cmpsb
	seta	%al
	sbbb	$0, %al
	testb	%al, %al
	je	.L182
.L183:
	movq	dpy(%rip), %rdi
	leaq	128(%rsp), %rdx
	movq	%rbx, %rsi
	call	XGetWindowAttributes
	testl	%eax, %eax
	je	.L182
	cmpl	$2, 220(%rsp)
	je	.L207
.L182:
	addq	$280, %rsp
	.cfi_remember_state
	.cfi_def_cfa_offset 56
	popq	%rbx
	.cfi_def_cfa_offset 48
	popq	%rbp
	.cfi_def_cfa_offset 40
	popq	%r12
	.cfi_def_cfa_offset 32
	popq	%r13
	.cfi_def_cfa_offset 24
	popq	%r14
	.cfi_def_cfa_offset 16
	popq	%r15
	.cfi_def_cfa_offset 8
	ret
	.p2align 4,,10
	.p2align 3
.L207:
	.cfi_restore_state
	movq	color_bg(%rip), %rax
	movl	$1, 104(%rsp)
	movq	$131072, 88(%rsp)
	movq	root(%rip), %rsi
	movq	%rax, 24(%rsp)
	movq	color_border(%rip), %rax
	movq	dpy(%rip), %rdi
	movq	%rax, 40(%rsp)
	leaq	16(%rsp), %rax
	pushq	%rax
	.cfi_def_cfa_offset 344
	pushq	$2570
	.cfi_def_cfa_offset 352
	pushq	$0
	.cfi_def_cfa_offset 360
	pushq	$1
	.cfi_def_cfa_offset 368
	pushq	$0
	.cfi_def_cfa_offset 376
	pushq	$0
	.cfi_def_cfa_offset 384
	movl	188(%rsp), %r9d
	movl	184(%rsp), %r8d
	movl	180(%rsp), %ecx
	movl	176(%rsp), %edx
	call	XCreateWindow
	movq	dpy(%rip), %rdi
	addq	$48, %rsp
	.cfi_def_cfa_offset 336
	movq	%rax, %rsi
	movq	%rax, %rbp
	call	XMapRaised
	movq	dpy(%rip), %rdi
	xorl	%esi, %esi
	call	XSync
	movl	$5, 12(%rsp)
.L192:
	call	rand
	movl	%eax, %ecx
	movl	$1431655766, %eax
	imull	%ecx
	movl	%ecx, %eax
	sarl	$31, %eax
	subl	%eax, %edx
	leal	(%rdx,%rdx,2), %eax
	movq	color_magenta(%rip), %rdx
	cmpl	%eax, %ecx
	jne	.L208
.L187:
	movq	gc(%rip), %rsi
	movq	dpy(%rip), %rdi
	call	XSetForeground
	subq	$8, %rsp
	.cfi_def_cfa_offset 344
	xorl	%ecx, %ecx
	movq	%rbp, %rsi
	movl	148(%rsp), %eax
	movq	gc(%rip), %rdx
	xorl	%r8d, %r8d
	movq	dpy(%rip), %rdi
	pushq	%rax
	.cfi_def_cfa_offset 352
	movl	152(%rsp), %r9d
	call	XFillRectangle
	call	rand
	movl	$1717986919, %edx
	movl	%eax, %ecx
	imull	%edx
	movl	%ecx, %eax
	sarl	$31, %eax
	movl	%edx, %ebx
	sarl	$2, %ebx
	subl	%eax, %ebx
	leal	(%rbx,%rbx,4), %eax
	addl	%eax, %eax
	subl	%eax, %ecx
	movl	%ecx, %ebx
	popq	%rcx
	.cfi_def_cfa_offset 344
	popq	%rsi
	.cfi_def_cfa_offset 336
	cmpl	$-4, %ebx
	jl	.L188
	leal	5(%rbx), %eax
	xorl	%r14d, %r14d
	movl	$458129845, %r12d
	movl	%eax, 8(%rsp)
	.p2align 4,,10
	.p2align 3
.L191:
	call	rand
	movq	gc(%rip), %rsi
	movq	dpy(%rip), %rdi
	testb	$1, %al
	movq	color_cyan(%rip), %rdx
	cmove	color_magenta(%rip), %rdx
	addl	$1, %r14d
	call	XSetForeground
	call	rand
	movl	%eax, %r13d
	call	rand
	movl	%eax, %ebx
	call	rand
	cltd
	idivl	140(%rsp)
	movl	%edx, %r15d
	call	rand
	movl	%r13d, %esi
	movq	dpy(%rip), %rdi
	movl	%r15d, %r8d
	movl	%eax, %ecx
	movl	%ebx, %eax
	imull	%r12d
	movl	%ebx, %eax
	sarl	$31, %eax
	sarl	$4, %edx
	subl	%eax, %edx
	movl	%ecx, %eax
	imull	$150, %edx, %edx
	subl	%edx, %ebx
	cltd
	idivl	136(%rsp)
	movl	%r13d, %eax
	subq	$8, %rsp
	.cfi_def_cfa_offset 344
	leal	50(%rbx), %r9d
	movl	%edx, %ecx
	movl	$1717986919, %edx
	imull	%edx
	movl	%r13d, %eax
	sarl	$31, %eax
	sarl	$3, %edx
	subl	%eax, %edx
	leal	(%rdx,%rdx,4), %eax
	movq	gc(%rip), %rdx
	sall	$2, %eax
	subl	%eax, %esi
	addl	$2, %esi
	pushq	%rsi
	.cfi_def_cfa_offset 352
	movq	%rbp, %rsi
	call	XFillRectangle
	popq	%rax
	.cfi_def_cfa_offset 344
	popq	%rdx
	.cfi_def_cfa_offset 336
	cmpl	8(%rsp), %r14d
	jne	.L191
.L188:
	movq	dpy(%rip), %rdi
	call	XFlush
	movl	$15000, %edi
	call	usleep
	subl	$1, 12(%rsp)
	jne	.L192
	movq	dpy(%rip), %rdi
	movq	%rbp, %rsi
	call	XDestroyWindow
	movq	dpy(%rip), %rdi
	call	XFlush
	jmp	.L182
	.p2align 4,,10
	.p2align 3
.L208:
	call	rand
	movq	color_cyan(%rip), %rdx
	testb	$1, %al
	cmovne	color_bg(%rip), %rdx
	jmp	.L187
	.cfi_endproc
.LFE33:
	.size	glitch_window, .-glitch_window
	.p2align 4,,15
	.globl	set_active_window_prop
	.type	set_active_window_prop, @function
set_active_window_prop:
.LFB34:
	.cfi_startproc
	subq	$24, %rsp
	.cfi_def_cfa_offset 32
	movq	atom_net_active(%rip), %rdx
	xorl	%r9d, %r9d
	movq	root(%rip), %rsi
	movq	%rdi, 8(%rsp)
	movl	$32, %r8d
	movl	$33, %ecx
	movq	dpy(%rip), %rdi
	pushq	$1
	.cfi_def_cfa_offset 40
	leaq	16(%rsp), %rax
	pushq	%rax
	.cfi_def_cfa_offset 48
	call	XChangeProperty
	addq	$40, %rsp
	.cfi_def_cfa_offset 8
	ret
	.cfi_endproc
.LFE34:
	.size	set_active_window_prop, .-set_active_window_prop
	.p2align 4,,15
	.globl	focus_emacs
	.type	focus_emacs, @function
focus_emacs:
.LFB35:
	.cfi_startproc
	pushq	%rbp
	.cfi_def_cfa_offset 16
	.cfi_offset 6, -16
	pushq	%rbx
	.cfi_def_cfa_offset 24
	.cfi_offset 3, -24
	xorl	%ebx, %ebx
	subq	$40, %rsp
	.cfi_def_cfa_offset 64
	movl	num_managed(%rip), %edx
	testl	%edx, %edx
	jg	.L212
	jmp	.L216
	.p2align 4,,10
	.p2align 3
.L215:
	addq	$1, %rbx
	cmpl	%ebx, num_managed(%rip)
	jle	.L216
.L212:
	movq	managed_windows(,%rbx,8), %rdi
	movslq	%ebx, %rbp
	call	is_emacs
	testl	%eax, %eax
	je	.L215
	movq	managed_windows(,%rbp,8), %rbx
	movq	dpy(%rip), %rdi
	movq	%rbx, %rsi
	call	XRaiseWindow
	xorl	%ecx, %ecx
	movl	$1, %edx
	movq	%rbx, %rsi
	movq	dpy(%rip), %rdi
	call	XSetInputFocus
	movq	%rbx, %rdi
	call	set_active_window_prop
	movq	%rbx, %rdi
	call	add_window
	movq	%rbx, %rdi
	call	glitch_window
.L211:
	addq	$40, %rsp
	.cfi_remember_state
	.cfi_def_cfa_offset 24
	popq	%rbx
	.cfi_def_cfa_offset 16
	popq	%rbp
	.cfi_def_cfa_offset 8
	ret
	.p2align 4,,10
	.p2align 3
.L216:
	.cfi_restore_state
	movq	root(%rip), %rsi
	leaq	4(%rsp), %r9
	leaq	24(%rsp), %r8
	movq	dpy(%rip), %rdi
	leaq	16(%rsp), %rcx
	leaq	8(%rsp), %rdx
	movq	$0, 24(%rsp)
	call	XQueryTree
	testl	%eax, %eax
	je	.L211
	movq	24(%rsp), %rdi
	testq	%rdi, %rdi
	je	.L211
	movl	4(%rsp), %eax
	testl	%eax, %eax
	je	.L217
	xorl	%ebx, %ebx
	jmp	.L219
	.p2align 4,,10
	.p2align 3
.L218:
	addl	$1, %ebx
	movq	24(%rsp), %rdi
	cmpl	%ebx, 4(%rsp)
	jbe	.L217
.L219:
	movl	%ebx, %eax
	movq	(%rdi,%rax,8), %rdi
	leaq	0(,%rax,8), %rbp
	call	is_emacs
	testl	%eax, %eax
	je	.L218
	movq	24(%rsp), %rax
	movq	dpy(%rip), %rdi
	movq	(%rax,%rbp), %rbx
	movq	%rbx, %rsi
	call	XRaiseWindow
	xorl	%ecx, %ecx
	movl	$1, %edx
	movq	%rbx, %rsi
	movq	dpy(%rip), %rdi
	call	XSetInputFocus
	movq	%rbx, %rdi
	call	set_active_window_prop
	movq	%rbx, %rdi
	call	add_window
	movq	%rbx, %rdi
	call	glitch_window
	movq	24(%rsp), %rdi
	call	XFree
	jmp	.L211
.L217:
	call	XFree
	jmp	.L211
	.cfi_endproc
.LFE35:
	.size	focus_emacs, .-focus_emacs
	.section	.rodata.str1.8
	.align 8
.LC29:
	.string	"================================================="
	.align 8
.LC30:
	.string	"[WM STARTED] Initializing window manager"
	.section	.rodata.str1.1
.LC31:
	.string	"_NET_SUPPORTED"
.LC32:
	.string	"_NET_ACTIVE_WINDOW"
.LC33:
	.string	"_NET_WM_NAME"
.LC34:
	.string	"_NET_WM_WINDOW_TYPE"
.LC35:
	.string	"UTF8_STRING"
.LC36:
	.string	"_NET_WM_WINDOW_TYPE_NORMAL"
	.section	.rodata.str1.8
	.align 8
.LC37:
	.string	"_NET_WM_WINDOW_TYPE_DROPDOWN_MENU"
	.align 8
.LC38:
	.string	"_NET_WM_WINDOW_TYPE_POPUP_MENU"
	.section	.rodata.str1.1
.LC39:
	.string	"_NET_WM_WINDOW_TYPE_MENU"
.LC40:
	.string	"_NET_WM_WINDOW_TYPE_TOOLTIP"
	.section	.rodata.str1.8
	.align 8
.LC41:
	.string	"_NET_WM_WINDOW_TYPE_NOTIFICATION"
	.section	.rodata.str1.1
.LC42:
	.string	"_NET_WM_WINDOW_TYPE_COMBO"
.LC43:
	.string	"_NET_WM_WINDOW_TYPE_UTILITY"
.LC44:
	.string	"_NET_WM_WINDOW_TYPE_DIALOG"
.LC45:
	.string	"_NET_WM_WINDOW_TYPE_DOCK"
.LC46:
	.string	"_NET_WM_WINDOW_TYPE_SPLASH"
.LC47:
	.string	"_MOTIF_WM_HINTS"
.LC48:
	.string	""
	.section	.rodata.str1.8
	.align 8
.LC49:
	.string	"-*-liberation sans-medium-r-normal--14-*-*-*-*-*-*-*,fixed,*"
	.section	.rodata.str1.1
.LC50:
	.string	"XInputExtension"
	.section	.rodata.str1.8
	.align 8
.LC51:
	.string	"[EVENT: MapRequest] Window 0x%lx ('%s')"
	.align 8
.LC52:
	.string	"[EVENT: ConfigureRequest] Manageable window 0x%lx -> forcing fullscreen"
	.align 8
.LC53:
	.string	"[EVENT: ConfigureRequest] Non-manageable window 0x%lx -> allowing requested geom (%d,%d %dx%d)"
	.align 8
.LC54:
	.string	"[EVENT: UnmapNotify] Window 0x%lx"
	.align 8
.LC55:
	.string	"[EVENT: DestroyNotify] Window 0x%lx"
	.align 8
.LC56:
	.string	"[EVENT: ClientMessage _NET_ACTIVE_WINDOW] Window 0x%lx"
	.section	.text.startup,"ax",@progbits
	.p2align 4,,15
	.globl	main
	.type	main, @function
main:
.LFB37:
	.cfi_startproc
	pushq	%r14
	.cfi_def_cfa_offset 16
	.cfi_offset 14, -16
	xorl	%edi, %edi
	pushq	%r13
	.cfi_def_cfa_offset 24
	.cfi_offset 13, -24
	pushq	%r12
	.cfi_def_cfa_offset 32
	.cfi_offset 12, -32
	pushq	%rbp
	.cfi_def_cfa_offset 40
	.cfi_offset 6, -40
	pushq	%rbx
	.cfi_def_cfa_offset 48
	.cfi_offset 3, -48
	subq	$640, %rsp
	.cfi_def_cfa_offset 688
	call	XOpenDisplay
	movq	%rax, dpy(%rip)
	testq	%rax, %rax
	je	.L230
	movl	$handle_error, %edi
	call	XSetErrorHandler
	xorl	%eax, %eax
	movl	$.LC29, %edi
	call	log_wm
	xorl	%eax, %eax
	movl	$.LC30, %edi
	call	log_wm
	movq	dpy(%rip), %rdi
	movl	$.LC31, %esi
	movslq	224(%rdi), %rax
	movl	%eax, screen(%rip)
	salq	$7, %rax
	addq	232(%rdi), %rax
	movq	16(%rax), %rdx
	movq	%rdx, root(%rip)
	movl	24(%rax), %edx
	movl	28(%rax), %eax
	movl	%edx, screen_width(%rip)
	xorl	%edx, %edx
	movl	%eax, screen_height(%rip)
	call	XInternAtom
	movq	dpy(%rip), %rdi
	xorl	%edx, %edx
	movl	$.LC32, %esi
	movq	%rax, %rbx
	call	XInternAtom
	movq	dpy(%rip), %rdi
	xorl	%edx, %edx
	movl	$.LC33, %esi
	movq	%rax, atom_net_active(%rip)
	call	XInternAtom
	movq	dpy(%rip), %rdi
	xorl	%edx, %edx
	movl	$.LC34, %esi
	movq	%rax, atom_net_wm_name(%rip)
	call	XInternAtom
	movq	dpy(%rip), %rdi
	xorl	%edx, %edx
	movl	$.LC35, %esi
	movq	%rax, atom_net_wm_type(%rip)
	call	XInternAtom
	movq	dpy(%rip), %rdi
	xorl	%edx, %edx
	movl	$.LC36, %esi
	movq	%rax, atom_utf8_string(%rip)
	call	XInternAtom
	movq	dpy(%rip), %rdi
	xorl	%edx, %edx
	movl	$.LC37, %esi
	movq	%rax, atom_type_normal(%rip)
	call	XInternAtom
	movq	dpy(%rip), %rdi
	xorl	%edx, %edx
	movl	$.LC38, %esi
	movq	%rax, atom_type_dropdown(%rip)
	call	XInternAtom
	movq	dpy(%rip), %rdi
	xorl	%edx, %edx
	movl	$.LC39, %esi
	movq	%rax, atom_type_popup(%rip)
	call	XInternAtom
	movq	dpy(%rip), %rdi
	xorl	%edx, %edx
	movl	$.LC40, %esi
	movq	%rax, atom_type_menu(%rip)
	call	XInternAtom
	movq	dpy(%rip), %rdi
	xorl	%edx, %edx
	movl	$.LC41, %esi
	movq	%rax, atom_type_tooltip(%rip)
	call	XInternAtom
	movq	dpy(%rip), %rdi
	xorl	%edx, %edx
	movl	$.LC42, %esi
	movq	%rax, atom_type_notification(%rip)
	call	XInternAtom
	movq	dpy(%rip), %rdi
	xorl	%edx, %edx
	movl	$.LC43, %esi
	movq	%rax, atom_type_combo(%rip)
	call	XInternAtom
	movq	dpy(%rip), %rdi
	xorl	%edx, %edx
	movl	$.LC44, %esi
	movq	%rax, atom_type_utility(%rip)
	call	XInternAtom
	movq	dpy(%rip), %rdi
	xorl	%edx, %edx
	movl	$.LC45, %esi
	movq	%rax, atom_type_dialog(%rip)
	call	XInternAtom
	movq	dpy(%rip), %rdi
	xorl	%edx, %edx
	movl	$.LC46, %esi
	movq	%rax, atom_type_dock(%rip)
	call	XInternAtom
	movq	dpy(%rip), %rdi
	xorl	%edx, %edx
	movl	$.LC47, %esi
	movq	%rax, atom_type_splash(%rip)
	call	XInternAtom
	xorl	%r9d, %r9d
	movl	$4, %ecx
	movq	%rbx, %rdx
	movq	%rax, atom_motif_wm_hints(%rip)
	movq	atom_net_active(%rip), %rax
	movl	$32, %r8d
	movq	root(%rip), %rsi
	movq	dpy(%rip), %rdi
	movq	%rax, 112(%rsp)
	movq	atom_net_wm_name(%rip), %rax
	movq	%rax, 120(%rsp)
	movq	atom_net_wm_type(%rip), %rax
	movq	%rax, 128(%rsp)
	movq	atom_type_normal(%rip), %rax
	movq	%rax, 136(%rsp)
	movq	atom_type_dropdown(%rip), %rax
	movq	%rax, 144(%rsp)
	movq	atom_type_popup(%rip), %rax
	movq	%rax, 152(%rsp)
	movq	atom_type_menu(%rip), %rax
	movq	%rax, 160(%rsp)
	movq	atom_type_tooltip(%rip), %rax
	movq	%rax, 168(%rsp)
	movq	atom_type_dialog(%rip), %rax
	movq	%rax, 176(%rsp)
	movq	atom_type_utility(%rip), %rax
	movq	%rax, 184(%rsp)
	pushq	$10
	.cfi_def_cfa_offset 696
	leaq	120(%rsp), %rax
	pushq	%rax
	.cfi_def_cfa_offset 704
	call	XChangeProperty
	movq	dpy(%rip), %rdi
	movslq	screen(%rip), %rax
	movq	root(%rip), %rsi
	salq	$7, %rax
	addq	232(%rdi), %rax
	movq	88(%rax), %rdx
	call	XSetWindowBackground
	movq	root(%rip), %rsi
	movq	dpy(%rip), %rdi
	call	XClearWindow
	movl	$.LC48, %esi
	movl	$6, %edi
	call	setlocale
	leaq	48(%rsp), %r8
	leaq	24(%rsp), %rcx
	movq	dpy(%rip), %rdi
	leaq	40(%rsp), %rdx
	movl	$.LC49, %esi
	call	XCreateFontSet
	popq	%rsi
	.cfi_def_cfa_offset 696
	popq	%rdi
	.cfi_def_cfa_offset 688
	movq	%rax, font_set(%rip)
	testq	%rax, %rax
	je	.L230
	movq	%rax, %rdi
	leaq	64(%rsp), %rbx
	call	XExtentsOfFontSet
	leaq	16(%rbx), %r13
	movswl	10(%rax), %edx
	movzwl	14(%rax), %eax
	movl	%edx, %ecx
	addl	%edx, %eax
	negl	%ecx
	movl	%eax, font_descent(%rip)
	xorl	%eax, %eax
	movl	%ecx, font_ascent(%rip)
	call	init_colors
	movq	root(%rip), %rsi
	xorl	%ecx, %ecx
	xorl	%edx, %edx
	movq	dpy(%rip), %rdi
	call	XCreateGC
	movq	root(%rip), %rsi
	movl	$1572867, %edx
	movq	dpy(%rip), %rdi
	movq	%rax, gc(%rip)
	call	XSelectInput
	movq	dpy(%rip), %rdi
	movl	$65289, %esi
	call	XKeysymToKeycode
	movq	dpy(%rip), %rdi
	movl	$65513, %esi
	movb	%al, tab_code(%rip)
	call	XKeysymToKeycode
	movq	dpy(%rip), %rdi
	movl	$65514, %esi
	movb	%al, alt_l_code(%rip)
	call	XKeysymToKeycode
	movq	dpy(%rip), %rdi
	movl	$65511, %esi
	movb	%al, alt_r_code(%rip)
	call	XKeysymToKeycode
	movq	dpy(%rip), %rdi
	movl	$65512, %esi
	movb	%al, meta_l_code(%rip)
	call	XKeysymToKeycode
	movq	dpy(%rip), %rdi
	movl	$65515, %esi
	movb	%al, meta_r_code(%rip)
	call	XKeysymToKeycode
	movq	dpy(%rip), %rdi
	movl	$65516, %esi
	movb	%al, super_l_code(%rip)
	call	XKeysymToKeycode
	movb	%al, super_r_code(%rip)
	movabsq	$38654705672, %rax
	movq	%rax, 64(%rsp)
	movabsq	$279172874304, %rax
	movq	%rax, 72(%rsp)
	movl	$1, %eax
	salq	$33, %rax
	movq	%rax, 80(%rsp)
	movabsq	$77309411344, %rax
	movq	%rax, 88(%rsp)
	movabsq	$558345748608, %rax
	movq	%rax, 96(%rsp)
	movabsq	$627065225360, %rax
	movq	%rax, 104(%rsp)
.L231:
	leaq	80(%rsp), %rax
	movl	(%rbx), %r12d
	leaq	84(%rsp), %r14
	xorl	%edx, %edx
	leaq	32(%rax), %rbp
	jmp	.L234
.L232:
	movl	(%r14), %edx
	addq	$4, %r14
.L234:
	subq	$8, %rsp
	.cfi_def_cfa_offset 696
	orl	%r12d, %edx
	movl	$1, %r9d
	xorl	%r8d, %r8d
	movq	root(%rip), %rcx
	movzbl	tab_code(%rip), %esi
	pushq	$1
	.cfi_def_cfa_offset 704
	movq	dpy(%rip), %rdi
	call	XGrabKey
	popq	%rdx
	.cfi_def_cfa_offset 696
	popq	%rcx
	.cfi_def_cfa_offset 688
	cmpq	%r14, %rbp
	jne	.L232
	addq	$4, %rbx
	cmpq	%rbx, %r13
	jne	.L231
	leaq	16(%rsp), %r8
	leaq	12(%rsp), %rcx
	movl	$xi_opcode, %edx
	movq	dpy(%rip), %rdi
	movl	$.LC50, %esi
	leaq	192(%rsp), %rbx
	call	XQueryExtension
	testl	%eax, %eax
	jne	.L318
	leaq	384(%rsp), %r12
.L235:
	movq	root(%rip), %rsi
	leaq	20(%rsp), %r9
	leaq	56(%rsp), %r8
	movq	dpy(%rip), %rdi
	leaq	48(%rsp), %rcx
	leaq	40(%rsp), %rdx
	movq	$0, 56(%rsp)
	call	XQueryTree
	testl	%eax, %eax
	je	.L242
	cmpq	$0, 56(%rsp)
	je	.L242
	xorl	%ebp, %ebp
	cmpl	$0, 20(%rsp)
	je	.L241
.L237:
	movq	56(%rsp), %rax
	movl	%ebp, %r13d
	movq	dpy(%rip), %rdi
	movq	%r12, %rdx
	movq	(%rax,%r13,8), %rsi
	call	XGetWindowAttributes
	testl	%eax, %eax
	je	.L239
	cmpl	$0, 504(%rsp)
	jne	.L239
	cmpl	$2, 476(%rsp)
	je	.L323
.L239:
	addl	$1, %ebp
	cmpl	%ebp, 20(%rsp)
	ja	.L237
.L241:
	movq	56(%rsp), %rdi
	call	XFree
	.p2align 4,,10
	.p2align 3
.L242:
	movq	dpy(%rip), %rdi
	movq	%rbx, %rsi
	call	XNextEvent
	movl	192(%rsp), %eax
	cmpl	$35, %eax
	je	.L324
.L244:
	cmpl	$33, %eax
	ja	.L242
	jmp	*.L255(,%rax,8)
	.section	.rodata
	.align 8
	.align 4
.L255:
	.quad	.L242
	.quad	.L242
	.quad	.L261
	.quad	.L242
	.quad	.L242
	.quad	.L242
	.quad	.L242
	.quad	.L242
	.quad	.L242
	.quad	.L242
	.quad	.L242
	.quad	.L242
	.quad	.L242
	.quad	.L242
	.quad	.L242
	.quad	.L242
	.quad	.L242
	.quad	.L260
	.quad	.L259
	.quad	.L242
	.quad	.L258
	.quad	.L242
	.quad	.L242
	.quad	.L257
	.quad	.L242
	.quad	.L242
	.quad	.L242
	.quad	.L242
	.quad	.L256
	.quad	.L242
	.quad	.L242
	.quad	.L242
	.quad	.L242
	.quad	.L254
	.section	.text.startup
.L230:
	addq	$640, %rsp
	.cfi_remember_state
	.cfi_def_cfa_offset 48
	movl	$1, %eax
	popq	%rbx
	.cfi_def_cfa_offset 40
	popq	%rbp
	.cfi_def_cfa_offset 32
	popq	%r12
	.cfi_def_cfa_offset 24
	popq	%r13
	.cfi_def_cfa_offset 16
	popq	%r14
	.cfi_def_cfa_offset 8
	ret
	.p2align 4,,10
	.p2align 3
.L254:
	.cfi_restore_state
	movq	atom_net_active(%rip), %rax
	cmpq	%rax, 232(%rsp)
	jne	.L242
	movq	224(%rsp), %rbp
	xorl	%eax, %eax
	movl	$.LC56, %edi
	movq	%rbp, %rsi
	call	log_wm
	testq	%rbp, %rbp
	je	.L242
	movq	%rbp, %rdi
	call	is_manageable
	testl	%eax, %eax
	je	.L242
	movq	dpy(%rip), %rdi
	movq	%rbp, %rsi
	call	XRaiseWindow
	xorl	%ecx, %ecx
	movl	$1, %edx
	movq	%rbp, %rsi
	movq	dpy(%rip), %rdi
	call	XSetInputFocus
	movq	%rbp, %rdi
	call	set_active_window_prop
	movq	%rbp, %rdi
	call	add_window
	movq	%rbp, %rdi
	call	glitch_window
	jmp	.L242
	.p2align 4,,10
	.p2align 3
.L256:
	movq	232(%rsp), %rax
	cmpq	%rax, atom_net_wm_name(%rip)
	je	.L271
	cmpq	$39, %rax
	jne	.L242
.L271:
	xorl	%eax, %eax
	call	update_window_list_file
	jmp	.L242
	.p2align 4,,10
	.p2align 3
.L257:
	movq	232(%rsp), %rdi
	call	is_manageable
	testl	%eax, %eax
	je	.L264
	movq	232(%rsp), %rsi
	xorl	%eax, %eax
	movl	$.LC52, %edi
	call	log_wm
	movl	screen_width(%rip), %eax
	movq	%r12, %rcx
	movl	280(%rsp), %edx
	movq	232(%rsp), %rsi
	movq	dpy(%rip), %rdi
	movq	$0, 384(%rsp)
	movl	%eax, 392(%rsp)
	orl	$31, %edx
	movl	screen_height(%rip), %eax
	movl	$0, 400(%rsp)
	movl	%eax, 396(%rsp)
	movq	264(%rsp), %rax
	movq	%rax, 408(%rsp)
	movl	272(%rsp), %eax
	movl	%eax, 416(%rsp)
	call	XConfigureWindow
	jmp	.L242
	.p2align 4,,10
	.p2align 3
.L258:
	movq	232(%rsp), %rbp
	movl	$256, %edx
	movq	%r12, %rsi
	movq	%rbp, %rdi
	call	get_window_title
	movl	$.LC51, %edi
	xorl	%eax, %eax
	movq	%r12, %rdx
	movq	%rbp, %rsi
	call	log_wm
	movq	%rbp, %rdi
	call	is_manageable
	testl	%eax, %eax
	je	.L262
	movq	%rbp, %rdi
	call	add_window
	movq	%rbp, %rdi
	call	maximize_window
	movq	dpy(%rip), %rdi
	movq	%rbp, %rsi
	call	XMapWindow
	xorl	%ecx, %ecx
	movl	$1, %edx
	movq	%rbp, %rsi
	movq	dpy(%rip), %rdi
	call	XSetInputFocus
	movq	%rbp, %rdi
	call	set_active_window_prop
	movq	%rbp, %rdi
	call	glitch_window
	jmp	.L242
	.p2align 4,,10
	.p2align 3
.L259:
	movq	232(%rsp), %rsi
	movl	$.LC54, %edi
	xorl	%eax, %eax
	call	log_wm
	movq	232(%rsp), %rdi
	cmpq	ignore_unmap_window(%rip), %rdi
	jne	.L322
	movq	$0, ignore_unmap_window(%rip)
	jmp	.L242
	.p2align 4,,10
	.p2align 3
.L261:
	movzbl	tab_code(%rip), %eax
	cmpl	%eax, 276(%rsp)
	jne	.L242
	xorl	%eax, %eax
	call	focus_emacs
	jmp	.L242
	.p2align 4,,10
	.p2align 3
.L260:
	movq	232(%rsp), %rsi
	movl	$.LC55, %edi
	xorl	%eax, %eax
	call	log_wm
	movq	232(%rsp), %rdi
.L322:
	call	remove_window
	movl	num_managed(%rip), %eax
	testl	%eax, %eax
	jne	.L242
	movq	root(%rip), %rsi
	movq	dpy(%rip), %rdi
	call	XClearWindow
	jmp	.L242
	.p2align 4,,10
	.p2align 3
.L324:
	movq	dpy(%rip), %rdi
	movq	%rbx, %rsi
	call	XGetEventData
	testl	%eax, %eax
	jne	.L245
	movl	192(%rsp), %eax
	jmp	.L244
	.p2align 4,,10
	.p2align 3
.L245:
	movq	dpy(%rip), %rdi
	movl	xi_opcode(%rip), %eax
	cmpl	%eax, 224(%rsp)
	je	.L325
.L246:
	movq	%rbx, %rsi
	call	XFreeEventData
	jmp	.L242
	.p2align 4,,10
	.p2align 3
.L325:
	cmpl	$13, 228(%rsp)
	jne	.L246
	movq	240(%rsp), %rdx
	movzbl	tab_code(%rip), %eax
	cmpl	%eax, 56(%rdx)
	jne	.L246
	movq	%r12, %rsi
	call	XQueryKeymap
	movzbl	alt_l_code(%rip), %eax
	testb	%al, %al
	je	.L247
	movl	%eax, %edx
	andl	$7, %eax
	shrb	$3, %dl
	andl	$31, %edx
	movsbl	384(%rsp,%rdx), %edx
	btl	%eax, %edx
	jc	.L248
.L247:
	movzbl	alt_r_code(%rip), %eax
	testb	%al, %al
	je	.L249
	movl	%eax, %edx
	andl	$7, %eax
	shrb	$3, %dl
	andl	$31, %edx
	movsbl	384(%rsp,%rdx), %edx
	btl	%eax, %edx
	jc	.L248
.L249:
	movzbl	meta_l_code(%rip), %eax
	testb	%al, %al
	je	.L250
	movl	%eax, %edx
	andl	$7, %eax
	shrb	$3, %dl
	andl	$31, %edx
	movsbl	384(%rsp,%rdx), %edx
	btl	%eax, %edx
	jc	.L248
.L250:
	movzbl	meta_r_code(%rip), %eax
	testb	%al, %al
	je	.L251
	movl	%eax, %edx
	andl	$7, %eax
	shrb	$3, %dl
	andl	$31, %edx
	movsbl	384(%rsp,%rdx), %edx
	btl	%eax, %edx
	jc	.L248
.L251:
	movzbl	super_l_code(%rip), %eax
	testb	%al, %al
	je	.L252
	movl	%eax, %edx
	andl	$7, %eax
	shrb	$3, %dl
	andl	$31, %edx
	movsbl	384(%rsp,%rdx), %edx
	btl	%eax, %edx
	jc	.L248
.L252:
	movzbl	super_r_code(%rip), %eax
	testb	%al, %al
	je	.L253
	movl	%eax, %edx
	andl	$7, %eax
	shrb	$3, %dl
	andl	$31, %edx
	movsbl	384(%rsp,%rdx), %edx
	btl	%eax, %edx
	jnc	.L253
.L248:
	xorl	%eax, %eax
	call	focus_emacs
.L253:
	movq	dpy(%rip), %rdi
	jmp	.L246
	.p2align 4,,10
	.p2align 3
.L264:
	movl	244(%rsp), %ecx
	movl	240(%rsp), %edx
	xorl	%eax, %eax
	movl	$.LC53, %edi
	movq	232(%rsp), %rsi
	movl	252(%rsp), %r9d
	movl	248(%rsp), %r8d
	call	log_wm
	movq	240(%rsp), %rax
	movq	%r12, %rcx
	movl	280(%rsp), %edx
	movq	232(%rsp), %rsi
	movq	dpy(%rip), %rdi
	movq	%rax, 384(%rsp)
	movq	248(%rsp), %rax
	movq	%rax, 392(%rsp)
	movl	256(%rsp), %eax
	movl	%eax, 400(%rsp)
	movq	264(%rsp), %rax
	movq	%rax, 408(%rsp)
	movl	272(%rsp), %eax
	movl	%eax, 416(%rsp)
	call	XConfigureWindow
	jmp	.L242
	.p2align 4,,10
	.p2align 3
.L262:
	movq	dpy(%rip), %rdi
	movq	%rbp, %rsi
	call	XMapRaised
	jmp	.L242
.L318:
	leaq	384(%rsp), %r12
	movl	$1, %ecx
	movq	root(%rip), %rsi
	movq	dpy(%rip), %rdi
	movabsq	$17179869185, %rax
	movq	%r12, %rdx
	movl	$0, 192(%rsp)
	movq	%rax, 384(%rsp)
	movb	$32, 193(%rsp)
	movq	%rbx, 392(%rsp)
	call	XISelectEvents
	jmp	.L235
.L323:
	movq	56(%rsp), %rax
	movq	(%rax,%r13,8), %rdi
	call	is_manageable
	testl	%eax, %eax
	je	.L239
	movq	56(%rsp), %rax
	movq	(%rax,%r13,8), %rdi
	call	add_window
	movq	56(%rsp), %rax
	movq	(%rax,%r13,8), %rdi
	call	maximize_window
	jmp	.L239
	.cfi_endproc
.LFE37:
	.size	main, .-main
	.globl	log_file
	.bss
	.align 8
	.type	log_file, @object
	.size	log_file, 8
log_file:
	.zero	8
	.comm	gc,8,8
	.globl	font_descent
	.align 4
	.type	font_descent, @object
	.size	font_descent, 4
font_descent:
	.zero	4
	.globl	font_ascent
	.align 4
	.type	font_ascent, @object
	.size	font_ascent, 4
font_ascent:
	.zero	4
	.comm	font_set,8,8
	.comm	color_magenta,8,8
	.comm	color_cyan,8,8
	.comm	color_border,8,8
	.comm	color_sel_fg,8,8
	.comm	color_sel_bg,8,8
	.comm	color_fg,8,8
	.comm	color_bg,8,8
	.globl	num_managed
	.align 4
	.type	num_managed, @object
	.size	num_managed, 4
num_managed:
	.zero	4
	.comm	managed_windows,8000,32
	.comm	atom_motif_wm_hints,8,8
	.comm	atom_type_normal,8,8
	.comm	atom_type_splash,8,8
	.comm	atom_type_dock,8,8
	.comm	atom_type_dialog,8,8
	.comm	atom_type_utility,8,8
	.comm	atom_type_combo,8,8
	.comm	atom_type_notification,8,8
	.comm	atom_type_tooltip,8,8
	.comm	atom_type_menu,8,8
	.comm	atom_type_popup,8,8
	.comm	atom_type_dropdown,8,8
	.comm	atom_utf8_string,8,8
	.comm	atom_net_wm_type,8,8
	.comm	atom_net_wm_name,8,8
	.comm	atom_net_active,8,8
	.globl	ignore_unmap_window
	.align 8
	.type	ignore_unmap_window, @object
	.size	ignore_unmap_window, 8
ignore_unmap_window:
	.zero	8
	.comm	super_r_code,1,1
	.comm	super_l_code,1,1
	.comm	meta_r_code,1,1
	.comm	meta_l_code,1,1
	.comm	alt_r_code,1,1
	.comm	alt_l_code,1,1
	.comm	tab_code,1,1
	.comm	xi_opcode,4,4
	.comm	screen_height,4,4
	.comm	screen_width,4,4
	.comm	screen,4,4
	.comm	root,8,8
	.comm	dpy,8,8
	.section	.rodata.cst8,"aM",@progbits,8
	.align 8
.LC21:
	.long	2576980378
	.long	1072273817
	.ident	"GCC: (GNU) 8.4.0"
	.section	.note.GNU-stack,"",@progbits
