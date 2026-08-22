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
	.string	"UTF8_STRING"
.LC9:
	.string	"_NET_WM_NAME"
.LC10:
	.string	"Untitled Window"
	.text
	.p2align 4,,15
	.globl	get_window_title
	.type	get_window_title, @function
get_window_title:
.LFB25:
	.cfi_startproc
	pushq	%r13
	.cfi_def_cfa_offset 16
	.cfi_offset 13, -16
	pushq	%r12
	.cfi_def_cfa_offset 24
	.cfi_offset 12, -24
	movq	%rsi, %r12
	movq	%rdi, %rsi
	pushq	%rbp
	.cfi_def_cfa_offset 32
	.cfi_offset 6, -32
	movq	%rdi, %rbp
	pushq	%rbx
	.cfi_def_cfa_offset 40
	.cfi_offset 3, -40
	movslq	%edx, %rbx
	subq	$56, %rsp
	.cfi_def_cfa_offset 96
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
	movq	dpy(%rip), %rdi
	xorl	%edx, %edx
	movl	$.LC8, %esi
	movq	$0, 40(%rsp)
	call	XInternAtom
	movq	dpy(%rip), %rdi
	xorl	%edx, %edx
	movl	$.LC9, %esi
	movq	%rax, %r13
	call	XInternAtom
	leaq	40(%rsp), %rdx
	xorl	%r9d, %r9d
	xorl	%ecx, %ecx
	pushq	%rdx
	.cfi_def_cfa_offset 104
	movq	dpy(%rip), %rdi
	movl	$1024, %r8d
	movq	%rbp, %rsi
	leaq	40(%rsp), %rdx
	pushq	%rdx
	.cfi_def_cfa_offset 112
	leaq	40(%rsp), %rdx
	pushq	%rdx
	.cfi_def_cfa_offset 120
	leaq	28(%rsp), %rdx
	pushq	%rdx
	.cfi_def_cfa_offset 128
	leaq	48(%rsp), %rdx
	pushq	%rdx
	.cfi_def_cfa_offset 136
	movq	%rax, %rdx
	pushq	%r13
	.cfi_def_cfa_offset 144
	call	XGetWindowProperty
	addq	$48, %rsp
	.cfi_def_cfa_offset 96
	testl	%eax, %eax
	jne	.L21
	movq	40(%rsp), %rcx
	testq	%rcx, %rcx
	jne	.L34
.L21:
	movl	$.LC10, %edx
	movq	%rbx, %rsi
	movq	%r12, %rdi
	xorl	%eax, %eax
	call	snprintf
.L16:
	addq	$56, %rsp
	.cfi_remember_state
	.cfi_def_cfa_offset 40
	popq	%rbx
	.cfi_def_cfa_offset 32
	popq	%rbp
	.cfi_def_cfa_offset 24
	popq	%r12
	.cfi_def_cfa_offset 16
	popq	%r13
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
	addq	$56, %rsp
	.cfi_remember_state
	.cfi_def_cfa_offset 40
	popq	%rbx
	.cfi_def_cfa_offset 32
	popq	%rbp
	.cfi_def_cfa_offset 24
	popq	%r12
	.cfi_def_cfa_offset 16
	popq	%r13
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
.LC11:
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
	movl	$.LC11, %esi
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
	movl	$.LC11, %esi
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
	movl	$.LC11, %esi
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
.LC12:
	.string	"w"
.LC13:
	.string	"/tmp/emacs_non_emacs_windows"
.LC14:
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
	movl	$.LC12, %esi
	movl	$.LC13, %edi
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
	movl	$.LC14, %esi
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
	pushq	%rbp
	.cfi_def_cfa_offset 16
	.cfi_offset 6, -16
	movq	%rdi, %rbp
	pushq	%rbx
	.cfi_def_cfa_offset 24
	.cfi_offset 3, -24
	subq	$8, %rsp
	.cfi_def_cfa_offset 32
	call	remove_window
	movl	num_managed(%rip), %ebx
	cmpl	$999, %ebx
	jle	.L79
	addq	$8, %rsp
	.cfi_remember_state
	.cfi_def_cfa_offset 24
	popq	%rbx
	.cfi_def_cfa_offset 16
	popq	%rbp
	.cfi_def_cfa_offset 8
	ret
	.p2align 4,,10
	.p2align 3
.L79:
	.cfi_restore_state
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
	addq	$8, %rsp
	.cfi_def_cfa_offset 24
	xorl	%eax, %eax
	popq	%rbx
	.cfi_def_cfa_offset 16
	popq	%rbp
	.cfi_def_cfa_offset 8
	jmp	update_window_list_file
	.cfi_endproc
.LFE29:
	.size	add_window, .-add_window
	.section	.rodata.str1.1
.LC15:
	.string	"a"
.LC16:
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
	je	.L85
	movaps	%xmm0, 80(%rsp)
	movaps	%xmm1, 96(%rsp)
	movaps	%xmm2, 112(%rsp)
	movaps	%xmm3, 128(%rsp)
	movaps	%xmm4, 144(%rsp)
	movaps	%xmm5, 160(%rsp)
	movaps	%xmm6, 176(%rsp)
	movaps	%xmm7, 192(%rsp)
.L85:
	cmpq	$0, log_file(%rip)
	je	.L82
.L84:
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
	movq	log_file(%rip), %rdi
	call	fflush
	addq	$208, %rsp
	.cfi_remember_state
	.cfi_def_cfa_offset 16
	popq	%rbx
	.cfi_def_cfa_offset 8
	ret
	.p2align 4,,10
	.p2align 3
.L82:
	.cfi_restore_state
	movl	$.LC15, %esi
	movl	$.LC16, %edi
	call	fopen
	movq	%rax, log_file(%rip)
	testq	%rax, %rax
	jne	.L84
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
.LC17:
	.string	"[is_manageable] Window 0x%lx: Failed to get attributes -> NO"
	.align 8
.LC18:
	.string	"[is_manageable] Window 0x%lx: override_redirect=True -> NO"
	.align 8
.LC19:
	.string	"[is_manageable] Window 0x%lx: transient_for=0x%lx -> NO"
	.align 8
.LC20:
	.string	"[is_manageable] Window 0x%lx: fixed size (%dx%d) -> NO"
	.align 8
.LC21:
	.string	"[is_manageable] Window 0x%lx: max_size too small (%dx%d) -> NO"
	.section	.rodata.str1.1
.LC22:
	.string	"_NET_WM_WINDOW_TYPE"
	.section	.rodata.str1.8
	.align 8
.LC23:
	.string	"_NET_WM_WINDOW_TYPE_DROPDOWN_MENU"
	.align 8
.LC24:
	.string	"_NET_WM_WINDOW_TYPE_POPUP_MENU"
	.section	.rodata.str1.1
.LC25:
	.string	"_NET_WM_WINDOW_TYPE_MENU"
.LC26:
	.string	"_NET_WM_WINDOW_TYPE_TOOLTIP"
	.section	.rodata.str1.8
	.align 8
.LC27:
	.string	"_NET_WM_WINDOW_TYPE_NOTIFICATION"
	.section	.rodata.str1.1
.LC28:
	.string	"_NET_WM_WINDOW_TYPE_COMBO"
.LC29:
	.string	"_NET_WM_WINDOW_TYPE_UTILITY"
.LC30:
	.string	"_NET_WM_WINDOW_TYPE_DIALOG"
.LC31:
	.string	"_NET_WM_WINDOW_TYPE_DOCK"
.LC32:
	.string	"_NET_WM_WINDOW_TYPE_SPLASH"
.LC33:
	.string	"_NET_WM_WINDOW_TYPE_NORMAL"
.LC34:
	.string	"_MOTIF_WM_HINTS"
	.section	.rodata.str1.8
	.align 8
.LC36:
	.string	"[is_manageable] Window 0x%lx ('%s'): MWM undecorated + dimensions (%dx%d) -> NO"
	.align 8
.LC37:
	.string	"[is_manageable] Window 0x%lx ('%s'): default -> YES"
	.align 8
.LC38:
	.string	"[is_manageable] Window 0x%lx: Explicit _NET_WM_WINDOW_TYPE_NORMAL -> YES"
	.align 8
.LC39:
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
	pushq	%rbx
	.cfi_def_cfa_offset 56
	.cfi_offset 3, -56
	movq	%rdi, %rbx
	subq	$648, %rsp
	.cfi_def_cfa_offset 704
	movq	dpy(%rip), %rdi
	leaq	240(%rsp), %rdx
	call	XGetWindowAttributes
	testl	%eax, %eax
	je	.L148
	movl	360(%rsp), %r12d
	testl	%r12d, %r12d
	jne	.L149
	movq	dpy(%rip), %rdi
	leaq	112(%rsp), %rdx
	movq	%rbx, %rsi
	movq	$0, 112(%rsp)
	call	XGetTransientForHint
	testl	%eax, %eax
	je	.L91
	movq	112(%rsp), %rdx
	testq	%rdx, %rdx
	jne	.L150
.L91:
	movq	dpy(%rip), %rdi
	leaq	120(%rsp), %rcx
	leaq	160(%rsp), %rdx
	movq	%rbx, %rsi
	call	XGetWMNormalHints
	testl	%eax, %eax
	je	.L92
	movq	160(%rsp), %rax
	movq	%rax, %rdx
	andl	$48, %edx
	cmpq	$48, %rdx
	je	.L151
.L93:
	testb	$32, %al
	je	.L92
	movl	screen_width(%rip), %esi
	movl	192(%rsp), %edx
	movl	196(%rsp), %ecx
	movl	%esi, %eax
	shrl	$31, %eax
	addl	%esi, %eax
	sarl	%eax
	cmpl	%eax, %edx
	jl	.L94
	movl	screen_height(%rip), %esi
	movl	%esi, %eax
	shrl	$31, %eax
	addl	%esi, %eax
	sarl	%eax
	cmpl	%ecx, %eax
	jg	.L94
.L92:
	movq	dpy(%rip), %rdi
	leaq	152(%rsp), %r15
	xorl	%edx, %edx
	movl	$.LC22, %esi
	movq	$0, 152(%rsp)
	call	XInternAtom
	pushq	%r15
	.cfi_def_cfa_offset 712
	xorl	%r9d, %r9d
	movl	$32, %r8d
	movq	dpy(%rip), %rdi
	movq	%rax, %rdx
	movq	%rbx, %rsi
	leaq	152(%rsp), %r14
	pushq	%r14
	.cfi_def_cfa_offset 720
	leaq	152(%rsp), %r13
	pushq	%r13
	.cfi_def_cfa_offset 728
	leaq	132(%rsp), %rbp
	pushq	%rbp
	.cfi_def_cfa_offset 736
	leaq	160(%rsp), %rcx
	pushq	%rcx
	.cfi_def_cfa_offset 744
	xorl	%ecx, %ecx
	pushq	$4
	.cfi_def_cfa_offset 752
	call	XGetWindowProperty
	addq	$48, %rsp
	.cfi_def_cfa_offset 704
	movl	%eax, %r12d
	testl	%eax, %eax
	jne	.L95
	movq	152(%rsp), %r8
	movq	dpy(%rip), %rdi
	testq	%r8, %r8
	movq	%r8, 48(%rsp)
	je	.L96
	xorl	%edx, %edx
	movl	$.LC23, %esi
	call	XInternAtom
	movq	dpy(%rip), %rdi
	xorl	%edx, %edx
	movl	$.LC24, %esi
	movq	%rax, 88(%rsp)
	call	XInternAtom
	movq	dpy(%rip), %rdi
	xorl	%edx, %edx
	movl	$.LC25, %esi
	movq	%rax, 80(%rsp)
	call	XInternAtom
	movq	dpy(%rip), %rdi
	xorl	%edx, %edx
	movl	$.LC26, %esi
	movq	%rax, 56(%rsp)
	call	XInternAtom
	movq	dpy(%rip), %rdi
	xorl	%edx, %edx
	movl	$.LC27, %esi
	movq	%rax, 64(%rsp)
	call	XInternAtom
	movq	dpy(%rip), %rdi
	xorl	%edx, %edx
	movl	$.LC28, %esi
	movq	%rax, 8(%rsp)
	call	XInternAtom
	movq	dpy(%rip), %rdi
	xorl	%edx, %edx
	movl	$.LC29, %esi
	movq	%rax, 16(%rsp)
	call	XInternAtom
	movq	dpy(%rip), %rdi
	xorl	%edx, %edx
	movl	$.LC30, %esi
	movq	%rax, 24(%rsp)
	call	XInternAtom
	movq	dpy(%rip), %rdi
	xorl	%edx, %edx
	movl	$.LC31, %esi
	movq	%rax, 32(%rsp)
	call	XInternAtom
	movq	dpy(%rip), %rdi
	xorl	%edx, %edx
	movl	$.LC32, %esi
	movq	%rax, 72(%rsp)
	call	XInternAtom
	movq	dpy(%rip), %rdi
	xorl	%edx, %edx
	movl	$.LC33, %esi
	movq	%rax, 40(%rsp)
	call	XInternAtom
	movq	136(%rsp), %rdi
	testq	%rdi, %rdi
	je	.L97
	movq	48(%rsp), %r8
	movq	80(%rsp), %r10
	movq	%rbx, 48(%rsp)
	xorl	%esi, %esi
	movq	72(%rsp), %rcx
	movq	88(%rsp), %r9
	movl	%r12d, 72(%rsp)
	movq	64(%rsp), %rbx
	movq	56(%rsp), %r12
	movq	%rax, 80(%rsp)
	jmp	.L99
	.p2align 4,,10
	.p2align 3
.L153:
	addq	$1, %rsi
	cmpq	%rdi, %rsi
	je	.L152
.L99:
	movq	(%r8,%rsi,8), %rax
	cmpq	%r9, %rax
	sete	%dl
	cmpq	%r10, %rax
	sete	%r11b
	orl	%edx, %r11d
	cmpq	%r12, %rax
	sete	%dl
	orl	%edx, %r11d
	cmpq	%rbx, %rax
	sete	%dl
	orl	%r11d, %edx
	cmpq	8(%rsp), %rax
	sete	%r11b
	orl	%r11d, %edx
	cmpq	16(%rsp), %rax
	sete	%r11b
	orl	%edx, %r11d
	cmpq	24(%rsp), %rax
	sete	%dl
	orl	%edx, %r11d
	cmpq	32(%rsp), %rax
	sete	%dl
	orl	%r11d, %edx
	cmpq	%rcx, %rax
	sete	%r11b
	orb	%r11b, %dl
	jne	.L98
	cmpq	40(%rsp), %rax
	jne	.L153
.L98:
	movq	48(%rsp), %rbx
	movl	$.LC39, %edi
	xorl	%eax, %eax
	movl	72(%rsp), %r12d
	movq	%rbx, %rsi
	call	log_wm
	movq	152(%rsp), %rdi
	call	XFree
	jmp	.L87
	.p2align 4,,10
	.p2align 3
.L95:
	movq	dpy(%rip), %rdi
.L96:
	xorl	%edx, %edx
	movl	$.LC34, %esi
	call	XInternAtom
	pushq	%r15
	.cfi_def_cfa_offset 712
	xorl	%r9d, %r9d
	movl	$20, %r8d
	pushq	%r14
	.cfi_def_cfa_offset 720
	movq	dpy(%rip), %rdi
	movq	%rax, %rdx
	movq	%rbx, %rsi
	pushq	%r13
	.cfi_def_cfa_offset 728
	pushq	%rbp
	.cfi_def_cfa_offset 736
	leaq	160(%rsp), %rcx
	pushq	%rcx
	.cfi_def_cfa_offset 744
	xorl	%ecx, %ecx
	pushq	%rax
	.cfi_def_cfa_offset 752
	call	XGetWindowProperty
	addq	$48, %rsp
	.cfi_def_cfa_offset 704
	movl	%eax, %r12d
	testl	%eax, %eax
	jne	.L147
	movq	152(%rsp), %rdi
	testq	%rdi, %rdi
	je	.L147
	cmpq	$4, 136(%rsp)
	leaq	384(%rsp), %rbp
	jbe	.L104
	testb	$2, (%rdi)
	je	.L104
	cmpq	$0, 16(%rdi)
	je	.L154
.L104:
	call	XFree
	jmp	.L103
	.p2align 4,,10
	.p2align 3
.L149:
	movq	%rbx, %rsi
	movl	$.LC18, %edi
	xorl	%eax, %eax
	xorl	%r12d, %r12d
	call	log_wm
.L87:
	addq	$648, %rsp
	.cfi_remember_state
	.cfi_def_cfa_offset 56
	movl	%r12d, %eax
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
.L148:
	.cfi_restore_state
	movl	%eax, %r12d
	movq	%rbx, %rsi
	movl	$.LC17, %edi
	xorl	%eax, %eax
	call	log_wm
	jmp	.L87
	.p2align 4,,10
	.p2align 3
.L150:
	cmpq	root(%rip), %rdx
	je	.L91
	movq	%rbx, %rsi
	movl	$.LC19, %edi
	xorl	%eax, %eax
	call	log_wm
	jmp	.L87
	.p2align 4,,10
	.p2align 3
.L147:
	leaq	384(%rsp), %rbp
.L103:
	movl	$256, %edx
	movq	%rbp, %rsi
	movq	%rbx, %rdi
	movl	$1, %r12d
	call	get_window_title
	movq	%rbp, %rdx
	movq	%rbx, %rsi
	movl	$.LC37, %edi
	xorl	%eax, %eax
	call	log_wm
	jmp	.L87
	.p2align 4,,10
	.p2align 3
.L94:
	movq	%rbx, %rsi
	movl	$.LC21, %edi
	xorl	%eax, %eax
	call	log_wm
	jmp	.L87
	.p2align 4,,10
	.p2align 3
.L151:
	movl	184(%rsp), %edx
	testl	%edx, %edx
	jle	.L93
	movl	188(%rsp), %ecx
	testl	%ecx, %ecx
	jle	.L93
	movq	192(%rsp), %rsi
	cmpq	%rsi, 184(%rsp)
	jne	.L93
	movq	%rbx, %rsi
	movl	$.LC20, %edi
	xorl	%eax, %eax
	call	log_wm
	jmp	.L87
	.p2align 4,,10
	.p2align 3
.L152:
	movq	80(%rsp), %rax
	movq	48(%rsp), %rbx
	cmpq	(%r8), %rax
	je	.L101
	leaq	8(%r8), %rdx
	leaq	(%r8,%rsi,8), %rcx
	jmp	.L108
	.p2align 4,,10
	.p2align 3
.L102:
	addq	$8, %rdx
	cmpq	%rax, -8(%rdx)
	je	.L101
.L108:
	cmpq	%rdx, %rcx
	jne	.L102
.L97:
	movq	152(%rsp), %rdi
	call	XFree
	movq	dpy(%rip), %rdi
	jmp	.L96
	.p2align 4,,10
	.p2align 3
.L154:
	movl	$256, %edx
	movq	%rbp, %rsi
	movq	%rbx, %rdi
	call	get_window_title
	pxor	%xmm0, %xmm0
	movl	248(%rsp), %ecx
	movsd	.LC35(%rip), %xmm1
	cvtsi2sd	screen_width(%rip), %xmm0
	pxor	%xmm2, %xmm2
	cvtsi2sd	%ecx, %xmm2
	mulsd	%xmm1, %xmm0
	comisd	%xmm2, %xmm0
	jbe	.L105
	pxor	%xmm0, %xmm0
	movl	252(%rsp), %r8d
	pxor	%xmm2, %xmm2
	cvtsi2sd	screen_height(%rip), %xmm0
	cvtsi2sd	%r8d, %xmm2
	mulsd	%xmm0, %xmm1
	comisd	%xmm2, %xmm1
	ja	.L155
.L105:
	movq	152(%rsp), %rdi
	jmp	.L104
	.p2align 4,,10
	.p2align 3
.L101:
	movq	152(%rsp), %rdi
	movl	$1, %r12d
	call	XFree
	movq	%rbx, %rsi
	movl	$.LC38, %edi
	xorl	%eax, %eax
	call	log_wm
	jmp	.L87
.L155:
	movq	%rbp, %rdx
	movq	%rbx, %rsi
	movl	$.LC36, %edi
	xorl	%eax, %eax
	call	log_wm
	movq	152(%rsp), %rdi
	call	XFree
	jmp	.L87
	.cfi_endproc
.LFE31:
	.size	is_manageable, .-is_manageable
	.section	.rodata.str1.8
	.align 8
.LC40:
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
	jne	.L159
	popq	%rbx
	.cfi_remember_state
	.cfi_def_cfa_offset 8
	ret
	.p2align 4,,10
	.p2align 3
.L159:
	.cfi_restore_state
	movl	screen_height(%rip), %ecx
	movq	%rbx, %rsi
	movl	$.LC40, %edi
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
	.p2align 4,,15
	.globl	glitch_window
	.type	glitch_window, @function
glitch_window:
.LFB33:
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
	pushq	%rbx
	.cfi_def_cfa_offset 56
	.cfi_offset 3, -56
	subq	$280, %rsp
	.cfi_def_cfa_offset 336
	movq	dpy(%rip), %rdi
	leaq	128(%rsp), %rdx
	call	XGetWindowAttributes
	testl	%eax, %eax
	je	.L160
	cmpl	$2, 220(%rsp)
	je	.L179
.L160:
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
.L179:
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
.L171:
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
	jne	.L180
.L166:
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
	movl	%ecx, %ebx
	popq	%rcx
	.cfi_def_cfa_offset 344
	popq	%rsi
	.cfi_def_cfa_offset 336
	addl	%eax, %eax
	subl	%eax, %ebx
	cmpl	$-4, %ebx
	jl	.L167
	leal	5(%rbx), %eax
	xorl	%r14d, %r14d
	movl	$458129845, %r12d
	movl	%eax, 8(%rsp)
	.p2align 4,,10
	.p2align 3
.L170:
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
	movl	%ebx, %edi
	movl	%r13d, %esi
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
	subl	%edx, %edi
	cltd
	idivl	136(%rsp)
	movl	%r13d, %eax
	subq	$8, %rsp
	.cfi_def_cfa_offset 344
	leal	50(%rdi), %r9d
	movq	dpy(%rip), %rdi
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
	jne	.L170
.L167:
	movq	dpy(%rip), %rdi
	call	XFlush
	movl	$15000, %edi
	call	usleep
	subl	$1, 12(%rsp)
	jne	.L171
	movq	dpy(%rip), %rdi
	movq	%rbp, %rsi
	call	XDestroyWindow
	movq	dpy(%rip), %rdi
	call	XFlush
	jmp	.L160
	.p2align 4,,10
	.p2align 3
.L180:
	call	rand
	movq	color_cyan(%rip), %rdx
	testb	$1, %al
	cmovne	color_bg(%rip), %rdx
	jmp	.L166
	.cfi_endproc
.LFE33:
	.size	glitch_window, .-glitch_window
	.section	.rodata.str1.1
.LC41:
	.string	"_NET_ACTIVE_WINDOW"
	.text
	.p2align 4,,15
	.globl	set_active_window_prop
	.type	set_active_window_prop, @function
set_active_window_prop:
.LFB34:
	.cfi_startproc
	subq	$24, %rsp
	.cfi_def_cfa_offset 32
	xorl	%edx, %edx
	movl	$.LC41, %esi
	movq	%rdi, 8(%rsp)
	movq	dpy(%rip), %rdi
	call	XInternAtom
	pushq	$1
	.cfi_def_cfa_offset 40
	xorl	%r9d, %r9d
	movl	$32, %r8d
	movq	root(%rip), %rsi
	movq	dpy(%rip), %rdi
	movl	$33, %ecx
	leaq	16(%rsp), %rdx
	pushq	%rdx
	.cfi_def_cfa_offset 48
	movq	%rax, %rdx
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
	jg	.L184
	jmp	.L188
	.p2align 4,,10
	.p2align 3
.L187:
	addq	$1, %rbx
	cmpl	%ebx, num_managed(%rip)
	jle	.L188
.L184:
	movq	managed_windows(,%rbx,8), %rdi
	movslq	%ebx, %rbp
	call	is_emacs
	testl	%eax, %eax
	je	.L187
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
.L183:
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
.L188:
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
	je	.L183
	movq	24(%rsp), %rdi
	testq	%rdi, %rdi
	je	.L183
	movl	4(%rsp), %eax
	testl	%eax, %eax
	je	.L189
	xorl	%ebx, %ebx
	jmp	.L191
	.p2align 4,,10
	.p2align 3
.L190:
	addl	$1, %ebx
	movq	24(%rsp), %rdi
	cmpl	%ebx, 4(%rsp)
	jbe	.L189
.L191:
	movl	%ebx, %eax
	movq	(%rdi,%rax,8), %rdi
	leaq	0(,%rax,8), %rbp
	call	is_emacs
	testl	%eax, %eax
	je	.L190
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
	jmp	.L183
.L189:
	call	XFree
	jmp	.L183
	.cfi_endproc
.LFE35:
	.size	focus_emacs, .-focus_emacs
	.section	.rodata.str1.8
	.align 8
.LC42:
	.string	"================================================="
	.align 8
.LC43:
	.string	"[WM STARTED] Initializing window manager"
	.section	.rodata.str1.1
.LC44:
	.string	"_NET_SUPPORTED"
.LC45:
	.string	""
	.section	.rodata.str1.8
	.align 8
.LC46:
	.string	"-*-liberation sans-medium-r-normal--14-*-*-*-*-*-*-*,fixed,*"
	.section	.rodata.str1.1
.LC47:
	.string	"XInputExtension"
	.section	.rodata.str1.8
	.align 8
.LC48:
	.string	"[EVENT: MapRequest] Window 0x%lx ('%s')"
	.align 8
.LC49:
	.string	"[EVENT: ConfigureRequest] Manageable window 0x%lx -> forcing fullscreen"
	.align 8
.LC50:
	.string	"[EVENT: ConfigureRequest] Non-manageable window 0x%lx -> allowing requested geom (%d,%d %dx%d)"
	.align 8
.LC51:
	.string	"[EVENT: UnmapNotify] Window 0x%lx"
	.align 8
.LC52:
	.string	"[EVENT: DestroyNotify] Window 0x%lx"
	.align 8
.LC53:
	.string	"[EVENT: ClientMessage _NET_ACTIVE_WINDOW] Window 0x%lx"
	.section	.text.startup,"ax",@progbits
	.p2align 4,,15
	.globl	main
	.type	main, @function
main:
.LFB37:
	.cfi_startproc
	pushq	%r15
	.cfi_def_cfa_offset 16
	.cfi_offset 15, -16
	xorl	%edi, %edi
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
	subq	$680, %rsp
	.cfi_def_cfa_offset 736
	call	XOpenDisplay
	movq	%rax, dpy(%rip)
	testq	%rax, %rax
	je	.L202
	movl	$handle_error, %edi
	call	XSetErrorHandler
	xorl	%eax, %eax
	movl	$.LC42, %edi
	call	log_wm
	xorl	%eax, %eax
	movl	$.LC43, %edi
	call	log_wm
	movq	dpy(%rip), %rdi
	movl	$.LC44, %esi
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
	movl	$.LC41, %esi
	movq	%rax, (%rsp)
	call	XInternAtom
	movq	dpy(%rip), %rdi
	xorl	%edx, %edx
	movl	$.LC9, %esi
	movq	%rax, 24(%rsp)
	call	XInternAtom
	movq	dpy(%rip), %rdi
	xorl	%edx, %edx
	movl	$.LC22, %esi
	movq	%rax, 16(%rsp)
	call	XInternAtom
	movq	dpy(%rip), %rdi
	xorl	%edx, %edx
	movl	$.LC33, %esi
	movq	%rax, 8(%rsp)
	call	XInternAtom
	movq	dpy(%rip), %rdi
	xorl	%edx, %edx
	movl	$.LC23, %esi
	movq	%rax, %rbx
	call	XInternAtom
	movq	dpy(%rip), %rdi
	xorl	%edx, %edx
	movl	$.LC24, %esi
	movq	%rax, %r15
	call	XInternAtom
	movq	dpy(%rip), %rdi
	xorl	%edx, %edx
	movl	$.LC25, %esi
	movq	%rax, %r14
	call	XInternAtom
	movq	dpy(%rip), %rdi
	xorl	%edx, %edx
	movl	$.LC26, %esi
	movq	%rax, %r13
	call	XInternAtom
	movq	dpy(%rip), %rdi
	xorl	%edx, %edx
	movl	$.LC30, %esi
	movq	%rax, %r12
	call	XInternAtom
	movq	dpy(%rip), %rdi
	xorl	%edx, %edx
	movl	$.LC29, %esi
	movq	%rax, %rbp
	call	XInternAtom
	movq	24(%rsp), %r10
	movq	16(%rsp), %r9
	movq	%rbx, 168(%rsp)
	movq	8(%rsp), %r8
	movq	%rax, 216(%rsp)
	movl	$4, %ecx
	movq	%r10, 144(%rsp)
	movq	root(%rip), %rsi
	movq	%r9, 152(%rsp)
	movq	dpy(%rip), %rdi
	xorl	%r9d, %r9d
	movq	%r8, 160(%rsp)
	movl	$32, %r8d
	movq	%r15, 176(%rsp)
	movq	%r14, 184(%rsp)
	movq	%r13, 192(%rsp)
	movq	%r12, 200(%rsp)
	movq	%rbp, 208(%rsp)
	pushq	$10
	.cfi_def_cfa_offset 744
	leaq	152(%rsp), %rax
	pushq	%rax
	.cfi_def_cfa_offset 752
	movq	16(%rsp), %rdx
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
	movl	$.LC45, %esi
	movl	$6, %edi
	call	setlocale
	leaq	80(%rsp), %r8
	leaq	56(%rsp), %rcx
	movq	dpy(%rip), %rdi
	leaq	72(%rsp), %rdx
	movl	$.LC46, %esi
	call	XCreateFontSet
	popq	%rsi
	.cfi_def_cfa_offset 744
	popq	%rdi
	.cfi_def_cfa_offset 736
	movq	%rax, font_set(%rip)
	testq	%rax, %rax
	je	.L202
	movq	%rax, %rdi
	leaq	96(%rsp), %rbx
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
	movq	%rax, 96(%rsp)
	movabsq	$279172874304, %rax
	movq	%rax, 104(%rsp)
	movl	$1, %eax
	salq	$33, %rax
	movq	%rax, 112(%rsp)
	movabsq	$77309411344, %rax
	movq	%rax, 120(%rsp)
	movabsq	$558345748608, %rax
	movq	%rax, 128(%rsp)
	movabsq	$627065225360, %rax
	movq	%rax, 136(%rsp)
.L203:
	leaq	112(%rsp), %rax
	movl	(%rbx), %r12d
	leaq	116(%rsp), %r14
	xorl	%edx, %edx
	leaq	32(%rax), %rbp
	jmp	.L206
.L204:
	movl	(%r14), %edx
	addq	$4, %r14
.L206:
	subq	$8, %rsp
	.cfi_def_cfa_offset 744
	orl	%r12d, %edx
	movl	$1, %r9d
	xorl	%r8d, %r8d
	movq	root(%rip), %rcx
	movzbl	tab_code(%rip), %esi
	pushq	$1
	.cfi_def_cfa_offset 752
	movq	dpy(%rip), %rdi
	call	XGrabKey
	popq	%rdx
	.cfi_def_cfa_offset 744
	popq	%rcx
	.cfi_def_cfa_offset 736
	cmpq	%r14, %rbp
	jne	.L204
	addq	$4, %rbx
	cmpq	%rbx, %r13
	jne	.L203
	leaq	48(%rsp), %r8
	leaq	44(%rsp), %rcx
	movl	$xi_opcode, %edx
	movq	dpy(%rip), %rdi
	movl	$.LC47, %esi
	leaq	224(%rsp), %rbx
	call	XQueryExtension
	testl	%eax, %eax
	jne	.L286
	leaq	416(%rsp), %r12
.L207:
	movq	root(%rip), %rsi
	leaq	52(%rsp), %r9
	leaq	88(%rsp), %r8
	movq	dpy(%rip), %rdi
	leaq	80(%rsp), %rcx
	leaq	72(%rsp), %rdx
	movq	$0, 88(%rsp)
	call	XQueryTree
	testl	%eax, %eax
	je	.L214
	cmpq	$0, 88(%rsp)
	je	.L214
	xorl	%ebp, %ebp
	cmpl	$0, 52(%rsp)
	je	.L213
.L209:
	movq	88(%rsp), %rax
	movl	%ebp, %r13d
	movq	dpy(%rip), %rdi
	movq	%r12, %rdx
	movq	(%rax,%r13,8), %rsi
	call	XGetWindowAttributes
	testl	%eax, %eax
	je	.L211
	cmpl	$0, 536(%rsp)
	jne	.L211
	cmpl	$2, 508(%rsp)
	je	.L291
.L211:
	addl	$1, %ebp
	cmpl	%ebp, 52(%rsp)
	ja	.L209
.L213:
	movq	88(%rsp), %rdi
	call	XFree
	.p2align 4,,10
	.p2align 3
.L214:
	movq	dpy(%rip), %rdi
	movq	%rbx, %rsi
	call	XNextEvent
	movl	224(%rsp), %eax
	cmpl	$35, %eax
	je	.L292
.L216:
	cmpl	$33, %eax
	ja	.L214
	jmp	*.L227(,%rax,8)
	.section	.rodata
	.align 8
	.align 4
.L227:
	.quad	.L214
	.quad	.L214
	.quad	.L233
	.quad	.L214
	.quad	.L214
	.quad	.L214
	.quad	.L214
	.quad	.L214
	.quad	.L214
	.quad	.L214
	.quad	.L214
	.quad	.L214
	.quad	.L214
	.quad	.L214
	.quad	.L214
	.quad	.L214
	.quad	.L214
	.quad	.L232
	.quad	.L231
	.quad	.L214
	.quad	.L230
	.quad	.L214
	.quad	.L214
	.quad	.L229
	.quad	.L214
	.quad	.L214
	.quad	.L214
	.quad	.L214
	.quad	.L228
	.quad	.L214
	.quad	.L214
	.quad	.L214
	.quad	.L214
	.quad	.L226
	.section	.text.startup
.L202:
	addq	$680, %rsp
	.cfi_remember_state
	.cfi_def_cfa_offset 56
	movl	$1, %eax
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
.L226:
	.cfi_restore_state
	movq	dpy(%rip), %rdi
	xorl	%edx, %edx
	movl	$.LC41, %esi
	call	XInternAtom
	cmpq	%rax, 264(%rsp)
	jne	.L214
	movq	256(%rsp), %rbp
	xorl	%eax, %eax
	movl	$.LC53, %edi
	movq	%rbp, %rsi
	call	log_wm
	testq	%rbp, %rbp
	je	.L214
	movq	%rbp, %rdi
	call	is_manageable
	testl	%eax, %eax
	je	.L214
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
	jmp	.L214
	.p2align 4,,10
	.p2align 3
.L228:
	movq	dpy(%rip), %rdi
	movq	264(%rsp), %rbp
	xorl	%edx, %edx
	movl	$.LC9, %esi
	call	XInternAtom
	cmpq	%rax, %rbp
	je	.L241
	cmpq	$39, 264(%rsp)
	jne	.L214
.L241:
	xorl	%eax, %eax
	call	update_window_list_file
	jmp	.L214
	.p2align 4,,10
	.p2align 3
.L229:
	movq	264(%rsp), %rdi
	call	is_manageable
	testl	%eax, %eax
	je	.L236
	movq	264(%rsp), %rsi
	xorl	%eax, %eax
	movl	$.LC49, %edi
	call	log_wm
	movl	screen_width(%rip), %eax
	movq	%r12, %rcx
	movl	312(%rsp), %edx
	movq	264(%rsp), %rsi
	movq	dpy(%rip), %rdi
	movq	$0, 416(%rsp)
	movl	%eax, 424(%rsp)
	orl	$31, %edx
	movl	screen_height(%rip), %eax
	movl	$0, 432(%rsp)
	movl	%eax, 428(%rsp)
	movq	296(%rsp), %rax
	movq	%rax, 440(%rsp)
	movl	304(%rsp), %eax
	movl	%eax, 448(%rsp)
	call	XConfigureWindow
	jmp	.L214
	.p2align 4,,10
	.p2align 3
.L230:
	movq	264(%rsp), %rbp
	movl	$256, %edx
	movq	%r12, %rsi
	movq	%rbp, %rdi
	call	get_window_title
	movl	$.LC48, %edi
	xorl	%eax, %eax
	movq	%r12, %rdx
	movq	%rbp, %rsi
	call	log_wm
	movq	%rbp, %rdi
	call	is_manageable
	testl	%eax, %eax
	je	.L234
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
	jmp	.L214
	.p2align 4,,10
	.p2align 3
.L231:
	movq	264(%rsp), %rsi
	movl	$.LC51, %edi
	xorl	%eax, %eax
	call	log_wm
	movq	264(%rsp), %rdi
	cmpq	ignore_unmap_window(%rip), %rdi
	jne	.L290
	movq	$0, ignore_unmap_window(%rip)
	jmp	.L214
	.p2align 4,,10
	.p2align 3
.L233:
	movzbl	tab_code(%rip), %eax
	cmpl	%eax, 308(%rsp)
	jne	.L214
	xorl	%eax, %eax
	call	focus_emacs
	jmp	.L214
	.p2align 4,,10
	.p2align 3
.L232:
	movq	264(%rsp), %rsi
	movl	$.LC52, %edi
	xorl	%eax, %eax
	call	log_wm
	movq	264(%rsp), %rdi
.L290:
	call	remove_window
	movl	num_managed(%rip), %eax
	testl	%eax, %eax
	jne	.L214
	movq	root(%rip), %rsi
	movq	dpy(%rip), %rdi
	call	XClearWindow
	jmp	.L214
	.p2align 4,,10
	.p2align 3
.L292:
	movq	dpy(%rip), %rdi
	movq	%rbx, %rsi
	call	XGetEventData
	testl	%eax, %eax
	jne	.L217
	movl	224(%rsp), %eax
	jmp	.L216
	.p2align 4,,10
	.p2align 3
.L217:
	movq	dpy(%rip), %rdi
	movl	xi_opcode(%rip), %eax
	cmpl	%eax, 256(%rsp)
	je	.L293
.L218:
	movq	%rbx, %rsi
	call	XFreeEventData
	jmp	.L214
	.p2align 4,,10
	.p2align 3
.L293:
	cmpl	$13, 260(%rsp)
	jne	.L218
	movq	272(%rsp), %rdx
	movzbl	tab_code(%rip), %eax
	cmpl	%eax, 56(%rdx)
	jne	.L218
	movq	%r12, %rsi
	call	XQueryKeymap
	movzbl	alt_l_code(%rip), %eax
	testb	%al, %al
	je	.L219
	movl	%eax, %edx
	andl	$7, %eax
	shrb	$3, %dl
	andl	$31, %edx
	movsbl	416(%rsp,%rdx), %edx
	btl	%eax, %edx
	jc	.L220
.L219:
	movzbl	alt_r_code(%rip), %eax
	testb	%al, %al
	je	.L221
	movl	%eax, %edx
	andl	$7, %eax
	shrb	$3, %dl
	andl	$31, %edx
	movsbl	416(%rsp,%rdx), %edx
	btl	%eax, %edx
	jc	.L220
.L221:
	movzbl	meta_l_code(%rip), %eax
	testb	%al, %al
	je	.L222
	movl	%eax, %edx
	andl	$7, %eax
	shrb	$3, %dl
	andl	$31, %edx
	movsbl	416(%rsp,%rdx), %edx
	btl	%eax, %edx
	jc	.L220
.L222:
	movzbl	meta_r_code(%rip), %eax
	testb	%al, %al
	je	.L223
	movl	%eax, %edx
	andl	$7, %eax
	shrb	$3, %dl
	andl	$31, %edx
	movsbl	416(%rsp,%rdx), %edx
	btl	%eax, %edx
	jc	.L220
.L223:
	movzbl	super_l_code(%rip), %eax
	testb	%al, %al
	je	.L224
	movl	%eax, %edx
	andl	$7, %eax
	shrb	$3, %dl
	andl	$31, %edx
	movsbl	416(%rsp,%rdx), %edx
	btl	%eax, %edx
	jc	.L220
.L224:
	movzbl	super_r_code(%rip), %eax
	testb	%al, %al
	je	.L225
	movl	%eax, %edx
	andl	$7, %eax
	shrb	$3, %dl
	andl	$31, %edx
	movsbl	416(%rsp,%rdx), %edx
	btl	%eax, %edx
	jnc	.L225
.L220:
	xorl	%eax, %eax
	call	focus_emacs
.L225:
	movq	dpy(%rip), %rdi
	jmp	.L218
	.p2align 4,,10
	.p2align 3
.L236:
	movl	276(%rsp), %ecx
	movl	272(%rsp), %edx
	xorl	%eax, %eax
	movl	$.LC50, %edi
	movq	264(%rsp), %rsi
	movl	284(%rsp), %r9d
	movl	280(%rsp), %r8d
	call	log_wm
	movq	272(%rsp), %rax
	movq	%r12, %rcx
	movl	312(%rsp), %edx
	movq	264(%rsp), %rsi
	movq	dpy(%rip), %rdi
	movq	%rax, 416(%rsp)
	movq	280(%rsp), %rax
	movq	%rax, 424(%rsp)
	movl	288(%rsp), %eax
	movl	%eax, 432(%rsp)
	movq	296(%rsp), %rax
	movq	%rax, 440(%rsp)
	movl	304(%rsp), %eax
	movl	%eax, 448(%rsp)
	call	XConfigureWindow
	jmp	.L214
	.p2align 4,,10
	.p2align 3
.L234:
	movq	dpy(%rip), %rdi
	movq	%rbp, %rsi
	call	XMapRaised
	jmp	.L214
.L286:
	leaq	416(%rsp), %r12
	movl	$1, %ecx
	movq	root(%rip), %rsi
	movq	dpy(%rip), %rdi
	movabsq	$17179869185, %rax
	movq	%r12, %rdx
	movl	$0, 224(%rsp)
	movq	%rax, 416(%rsp)
	movb	$32, 225(%rsp)
	movq	%rbx, 424(%rsp)
	call	XISelectEvents
	jmp	.L207
.L291:
	movq	88(%rsp), %rax
	movq	(%rax,%r13,8), %rdi
	call	is_manageable
	testl	%eax, %eax
	je	.L211
	movq	88(%rsp), %rax
	movq	(%rax,%r13,8), %rdi
	call	add_window
	movq	88(%rsp), %rax
	movq	(%rax,%r13,8), %rdi
	call	maximize_window
	jmp	.L211
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
.LC35:
	.long	2576980378
	.long	1072273817
	.ident	"GCC: (GNU) 8.4.0"
	.section	.note.GNU-stack,"",@progbits
