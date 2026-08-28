	.file	"alt_tab_maximize_emacs-buffer_only.c"
	.text
	.globl	handle_error
	.type	handle_error, @function
handle_error:
	xorl	%eax, %eax
	ret
	.size	handle_error, .-handle_error
	.globl	get_color
	.type	get_color, @function
get_color:
	pushq	%rbx
	movq	%rdi, %rdx
	subq	$16, %rsp
	movq	dpy(%rip), %rdi
	movslq	screen(%rip), %rax
	movq	%rsp, %rcx
	salq	$7, %rax
	addq	232(%rdi), %rax
	movq	80(%rax), %rbx
	movq	%rbx, %rsi
	call	XParseColor
	testl	%eax, %eax
	je	.L3
	movq	dpy(%rip), %rdi
	movq	%rsp, %rdx
	movq	%rbx, %rsi
	call	XAllocColor
	testl	%eax, %eax
	je	.L3
	movq	(%rsp), %rax
	jmp	.L2
.L3:
	movslq	screen(%rip), %rax
	movq	dpy(%rip), %rdx
	salq	$7, %rax
	addq	232(%rdx), %rax
	movq	96(%rax), %rax
.L2:
	addq	$16, %rsp
	popq	%rbx
	ret
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
	.text
	.globl	init_colors
	.type	init_colors, @function
init_colors:
	pushq	%rax
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
	movq	%rax, color_border(%rip)
	popq	%rdx
	ret
	.size	init_colors, .-init_colors
	.section	.rodata.str1.1
.LC5:
	.string	"%s"
.LC6:
	.string	"Untitled Window"
	.text
	.globl	get_window_title
	.type	get_window_title, @function
get_window_title:
	pushq	%r12
	movq	%rdi, %r12
	pushq	%rbp
	movq	%rsi, %rbp
	movq	%rdi, %rsi
	pushq	%rbx
	movslq	%edx, %rbx
	subq	$48, %rsp
	movq	dpy(%rip), %rdi
	movq	$0, 8(%rsp)
	leaq	8(%rsp), %rdx
	call	XFetchName
	movq	8(%rsp), %rcx
	testl	%eax, %eax
	je	.L16
	testq	%rcx, %rcx
	je	.L18
	cmpb	$0, (%rcx)
	je	.L16
	movq	%rbp, %rdi
	movl	$.LC5, %edx
	movq	%rbx, %rsi
	xorl	%eax, %eax
	call	snprintf
	movq	8(%rsp), %rdi
	jmp	.L34
.L16:
	testq	%rcx, %rcx
	je	.L18
	movq	%rcx, %rdi
	call	XFree
.L18:
	leaq	40(%rsp), %rax
	xorl	%r9d, %r9d
	movl	$1024, %r8d
	xorl	%ecx, %ecx
	movq	$0, 40(%rsp)
	movq	atom_net_wm_name(%rip), %rdx
	movq	%r12, %rsi
	pushq	%rax
	movq	dpy(%rip), %rdi
	leaq	40(%rsp), %rax
	pushq	%rax
	leaq	40(%rsp), %rax
	pushq	%rax
	leaq	28(%rsp), %rax
	pushq	%rax
	leaq	48(%rsp), %rax
	pushq	%rax
	pushq	atom_utf8_string(%rip)
	call	XGetWindowProperty
	addq	$48, %rsp
	testl	%eax, %eax
	jne	.L19
	movq	40(%rsp), %rcx
	testq	%rcx, %rcx
	je	.L19
	movq	%rbp, %rdi
	movl	$.LC5, %edx
	movq	%rbx, %rsi
	call	snprintf
	movq	40(%rsp), %rdi
.L34:
	call	XFree
	jmp	.L15
.L19:
	movl	$.LC6, %edx
	movq	%rbx, %rsi
	movq	%rbp, %rdi
	xorl	%eax, %eax
	call	snprintf
.L15:
	addq	$48, %rsp
	popq	%rbx
	popq	%rbp
	popq	%r12
	ret
	.size	get_window_title, .-get_window_title
	.section	.rodata.str1.1
.LC7:
	.string	"emacs"
	.text
	.globl	is_emacs
	.type	is_emacs, @function
is_emacs:
	pushq	%rbp
	movq	%rdi, %rsi
	pushq	%rbx
	subq	$24, %rsp
	movq	dpy(%rip), %rdi
	movq	%rsp, %rdx
	call	XGetClassHint
	movl	%eax, %ebx
	testl	%eax, %eax
	je	.L35
	movq	(%rsp), %rbp
	testq	%rbp, %rbp
	je	.L37
	movl	$.LC7, %esi
	movq	%rbp, %rdi
	call	strcasecmp
	testl	%eax, %eax
	je	.L41
.L37:
	movq	8(%rsp), %rdi
	xorl	%ebx, %ebx
	testq	%rdi, %rdi
	je	.L39
	movl	$.LC7, %esi
	xorl	%ebx, %ebx
	call	strcasecmp
	testl	%eax, %eax
	sete	%bl
.L39:
	testq	%rbp, %rbp
	je	.L40
	jmp	.L38
.L41:
	movl	$1, %ebx
.L38:
	movq	%rbp, %rdi
	call	XFree
.L40:
	movq	8(%rsp), %rdi
	testq	%rdi, %rdi
	je	.L35
	call	XFree
.L35:
	addq	$24, %rsp
	movl	%ebx, %eax
	popq	%rbx
	popq	%rbp
	ret
	.size	is_emacs, .-is_emacs
	.section	.rodata.str1.1
.LC8:
	.string	"w"
.LC9:
	.string	"/tmp/emacs_non_emacs_windows"
.LC10:
	.string	"%lu\t%s\n"
	.text
	.globl	update_window_list_file
	.type	update_window_list_file, @function
update_window_list_file:
	pushq	%r12
	movl	$.LC8, %esi
	movl	$.LC9, %edi
	pushq	%rbp
	pushq	%rbx
	subq	$256, %rsp
	call	fopen
	testq	%rax, %rax
	je	.L56
	movq	%rax, %rbp
	xorl	%ebx, %ebx
.L58:
	cmpl	%ebx, num_managed(%rip)
	jle	.L65
	movq	managed_windows(,%rbx,8), %r12
	movq	%r12, %rdi
	call	is_emacs
	testl	%eax, %eax
	jne	.L59
	movl	$256, %edx
	movq	%rsp, %rsi
	movq	%r12, %rdi
	call	get_window_title
	movq	%rsp, %rcx
	movq	%r12, %rdx
	movl	$.LC10, %esi
	movq	%rbp, %rdi
	xorl	%eax, %eax
	call	fprintf
.L59:
	incq	%rbx
	jmp	.L58
.L65:
	movq	%rbp, %rdi
	call	fclose
.L56:
	addq	$256, %rsp
	popq	%rbx
	popq	%rbp
	popq	%r12
	ret
	.size	update_window_list_file, .-update_window_list_file
	.globl	remove_window
	.type	remove_window, @function
remove_window:
	pushq	%rbx
	movl	num_managed(%rip), %ebx
	xorl	%eax, %eax
.L67:
	movslq	%eax, %rcx
	cmpl	%eax, %ebx
	jle	.L71
	movq	managed_windows(,%rax,8), %rdx
	leal	1(%rax), %esi
	incq	%rax
	cmpq	%rdi, %rdx
	jne	.L67
	movl	%ebx, %edx
	movslq	%esi, %rsi
	leaq	managed_windows(,%rcx,8), %rdi
	decl	%ebx
	subl	%ecx, %edx
	leaq	managed_windows(,%rsi,8), %rsi
	decl	%edx
	movslq	%edx, %rdx
	salq	$3, %rdx
	call	memmove
	movl	%ebx, num_managed(%rip)
	xorl	%eax, %eax
	popq	%rbx
	jmp	update_window_list_file
.L71:
	popq	%rbx
	ret
	.size	remove_window, .-remove_window
	.globl	is_managed_window
	.type	is_managed_window, @function
is_managed_window:
	movl	num_managed(%rip), %edx
	xorl	%eax, %eax
.L73:
	cmpl	%eax, %edx
	jle	.L77
	incq	%rax
	cmpq	%rdi, managed_windows-8(,%rax,8)
	jne	.L73
	movl	$1, %eax
	ret
.L77:
	xorl	%eax, %eax
	ret
	.size	is_managed_window, .-is_managed_window
	.globl	add_window
	.type	add_window, @function
add_window:
	pushq	%rbp
	xorl	%eax, %eax
	pushq	%rbx
	movq	%rdi, %rbx
	pushq	%rcx
	movl	num_managed(%rip), %ebp
.L79:
	movslq	%eax, %rcx
	cmpl	%eax, %ebp
	jle	.L80
	movq	managed_windows(,%rax,8), %rdx
	leal	1(%rax), %esi
	incq	%rax
	cmpq	%rbx, %rdx
	jne	.L79
	movl	%ebp, %edx
	movslq	%esi, %rax
	leaq	managed_windows(,%rcx,8), %rdi
	decl	%ebp
	subl	%ecx, %edx
	leaq	managed_windows(,%rax,8), %rsi
	decl	%edx
	movslq	%edx, %rdx
	salq	$3, %rdx
	call	memmove
	movl	%ebp, num_managed(%rip)
.L80:
	movl	num_managed(%rip), %ebp
	cmpl	$999, %ebp
	jg	.L78
	movslq	%ebp, %rdx
	movl	$managed_windows, %esi
	movl	$managed_windows+8, %edi
	incl	%ebp
	salq	$3, %rdx
	call	memmove
	movq	dpy(%rip), %rdi
	movq	%rbx, %rsi
	movl	$4194304, %edx
	movq	%rbx, managed_windows(%rip)
	movl	%ebp, num_managed(%rip)
	call	XSelectInput
	popq	%rdx
	xorl	%eax, %eax
	popq	%rbx
	popq	%rbp
	jmp	update_window_list_file
.L78:
	popq	%rax
	popq	%rbx
	popq	%rbp
	ret
	.size	add_window, .-add_window
	.section	.rodata.str1.1
.LC11:
	.string	"ALT_TAB_SYNC_LOG"
.LC12:
	.string	"a"
.LC13:
	.string	"/tmp/alt_tab_wm.log"
	.text
	.globl	log_wm
	.type	log_wm, @function
log_wm:
	pushq	%rbx
	subq	$208, %rsp
	movq	%rsi, 40(%rsp)
	movq	%rdx, 48(%rsp)
	movq	%rcx, 56(%rsp)
	movq	%r8, 64(%rsp)
	movq	%r9, 72(%rsp)
	testb	%al, %al
	je	.L94
	movaps	%xmm0, 80(%rsp)
	movaps	%xmm1, 96(%rsp)
	movaps	%xmm2, 112(%rsp)
	movaps	%xmm3, 128(%rsp)
	movaps	%xmm4, 144(%rsp)
	movaps	%xmm5, 160(%rsp)
	movaps	%xmm6, 176(%rsp)
	movaps	%xmm7, 192(%rsp)
.L94:
	cmpl	$0, logging_enabled(%rip)
	je	.L85
	cmpq	$0, log_file(%rip)
	movq	%rdi, %rbx
	je	.L89
.L92:
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
	movl	$.LC11, %edi
	call	getenv
	testq	%rax, %rax
	je	.L85
	movq	log_file(%rip), %rdi
	call	fflush
	jmp	.L85
.L89:
	movl	$.LC12, %esi
	movl	$.LC13, %edi
	call	fopen
	movq	%rax, log_file(%rip)
	testq	%rax, %rax
	jne	.L92
.L85:
	addq	$208, %rsp
	popq	%rbx
	ret
	.size	log_wm, .-log_wm
	.section	.rodata.str1.1
.LC14:
	.string	"[is_manageable] Window 0x%lx: Failed to get attributes -> NO"
.LC15:
	.string	"[is_manageable] Window 0x%lx: override_redirect=True -> NO"
.LC16:
	.string	"[is_manageable] Window 0x%lx: transient_for=0x%lx -> NO"
.LC17:
	.string	"[is_manageable] Window 0x%lx: fixed size (%dx%d) -> NO"
.LC18:
	.string	"[is_manageable] Window 0x%lx: max_size too small (%dx%d) -> NO"
.LC19:
	.string	"[is_manageable] Window 0x%lx: Explicit _NET_WM_WINDOW_TYPE_NORMAL -> YES"
.LC21:
	.string	"[is_manageable] Window 0x%lx ('%s'): MWM undecorated + dimensions (%dx%d) -> NO"
.LC22:
	.string	"[is_manageable] Window 0x%lx ('%s'): default -> YES"
.LC23:
	.string	"[is_manageable] Window 0x%lx: Matched non-normal _NET_WM_WINDOW_TYPE -> NO"
	.text
	.globl	is_manageable
	.type	is_manageable, @function
is_manageable:
	pushq	%r15
	movq	%rdi, %rsi
	pushq	%r14
	pushq	%r13
	pushq	%r12
	pushq	%rbp
	pushq	%rbx
	movq	%rdi, %rbx
	subq	$568, %rsp
	movq	dpy(%rip), %rdi
	leaq	168(%rsp), %rdx
	call	XGetWindowAttributes
	testl	%eax, %eax
	jne	.L97
	movl	%eax, %ebp
	movq	%rbx, %rsi
	movl	$.LC14, %edi
	jmp	.L148
.L97:
	movl	288(%rsp), %ebp
	testl	%ebp, %ebp
	je	.L99
	movq	%rbx, %rsi
	movl	$.LC15, %edi
	xorl	%eax, %eax
	xorl	%ebp, %ebp
	call	log_wm
	jmp	.L96
.L99:
	movq	dpy(%rip), %rdi
	leaq	40(%rsp), %rdx
	movq	%rbx, %rsi
	movq	$0, 40(%rsp)
	call	XGetTransientForHint
	testl	%eax, %eax
	je	.L100
	movq	40(%rsp), %rdx
	testq	%rdx, %rdx
	je	.L100
	cmpq	root(%rip), %rdx
	je	.L100
	movq	%rbx, %rsi
	movl	$.LC16, %edi
	xorl	%eax, %eax
	call	log_wm
	jmp	.L96
.L100:
	movq	dpy(%rip), %rdi
	leaq	48(%rsp), %rcx
	leaq	88(%rsp), %rdx
	movq	%rbx, %rsi
	call	XGetWMNormalHints
	testl	%eax, %eax
	je	.L101
	movq	88(%rsp), %rax
	movq	%rax, %rdx
	andl	$48, %edx
	cmpq	$48, %rdx
	jne	.L102
	movl	112(%rsp), %edx
	testl	%edx, %edx
	jle	.L102
	movl	116(%rsp), %ecx
	testl	%ecx, %ecx
	jle	.L102
	movq	120(%rsp), %rsi
	cmpq	%rsi, 112(%rsp)
	jne	.L102
	movq	%rbx, %rsi
	movl	$.LC17, %edi
	jmp	.L149
.L102:
	testb	$32, %al
	je	.L101
	movl	screen_width(%rip), %eax
	movl	$2, %esi
	movl	120(%rsp), %edi
	movl	124(%rsp), %ecx
	cltd
	idivl	%esi
	cmpl	%eax, %edi
	jl	.L103
	movl	screen_height(%rip), %eax
	cltd
	idivl	%esi
	cmpl	%ecx, %eax
	jle	.L101
.L103:
	movl	%edi, %edx
	movq	%rbx, %rsi
	movl	$.LC18, %edi
.L149:
	xorl	%eax, %eax
	call	log_wm
	jmp	.L96
.L101:
	leaq	80(%rsp), %r13
	xorl	%r9d, %r9d
	movl	$32, %r8d
	xorl	%ecx, %ecx
	movq	$0, 80(%rsp)
	movq	atom_net_wm_type(%rip), %rdx
	movq	%rbx, %rsi
	pushq	%r13
	movq	dpy(%rip), %rdi
	leaq	80(%rsp), %r12
	pushq	%r12
	leaq	80(%rsp), %rax
	pushq	%rax
	leaq	60(%rsp), %rax
	pushq	%rax
	leaq	88(%rsp), %rax
	pushq	%rax
	pushq	$4
	call	XGetWindowProperty
	addq	$48, %rsp
	movl	%eax, %ebp
	testl	%eax, %eax
	jne	.L104
	movq	80(%rsp), %rdi
	testq	%rdi, %rdi
	je	.L104
	movq	64(%rsp), %rax
	movq	atom_type_menu(%rip), %rcx
	xorl	%edx, %edx
	movq	atom_type_tooltip(%rip), %rsi
	movq	atom_type_notification(%rip), %r8
	movq	%rax, 24(%rsp)
	movq	atom_type_dropdown(%rip), %rax
	movq	atom_type_combo(%rip), %r9
	movq	atom_type_utility(%rip), %r10
	movq	%rax, 8(%rsp)
	movq	atom_type_popup(%rip), %rax
	movq	atom_type_dialog(%rip), %r11
	movq	atom_type_dock(%rip), %r14
	movq	%rax, 16(%rsp)
	movq	atom_type_splash(%rip), %r15
.L105:
	cmpq	%rdx, 24(%rsp)
	je	.L150
	movq	(%rdi,%rdx,8), %rax
	cmpq	8(%rsp), %rax
	je	.L106
	cmpq	16(%rsp), %rax
	je	.L106
	cmpq	%rcx, %rax
	je	.L106
	cmpq	%rsi, %rax
	je	.L106
	cmpq	%r8, %rax
	je	.L106
	cmpq	%r9, %rax
	je	.L106
	cmpq	%r10, %rax
	je	.L106
	cmpq	%r11, %rax
	je	.L106
	cmpq	%r14, %rax
	je	.L106
	cmpq	%r15, %rax
	je	.L106
	incq	%rdx
	jmp	.L105
.L150:
	movq	atom_type_normal(%rip), %rcx
	xorl	%eax, %eax
.L108:
	cmpq	%rax, %rdx
	je	.L109
	cmpq	%rcx, (%rdi,%rax,8)
	je	.L116
	incq	%rax
	jmp	.L108
.L116:
	movl	$1, %ebp
.L109:
	call	XFree
	testl	%ebp, %ebp
	je	.L104
	movq	%rbx, %rsi
	movl	$.LC19, %edi
.L148:
	xorl	%eax, %eax
	call	log_wm
	jmp	.L96
.L104:
	pushq	%r13
	movq	atom_motif_wm_hints(%rip), %rdx
	xorl	%r9d, %r9d
	xorl	%ecx, %ecx
	pushq	%r12
	movq	dpy(%rip), %rdi
	movl	$20, %r8d
	movq	%rbx, %rsi
	leaq	80(%rsp), %rax
	pushq	%rax
	leaq	60(%rsp), %rax
	pushq	%rax
	leaq	88(%rsp), %rax
	pushq	%rax
	pushq	%rdx
	call	XGetWindowProperty
	addq	$48, %rsp
	movl	%eax, %ebp
	testl	%eax, %eax
	jne	.L111
	movq	80(%rsp), %rax
	testq	%rax, %rax
	je	.L111
	cmpq	$4, 64(%rsp)
	jbe	.L112
	testb	$2, (%rax)
	je	.L112
	cmpq	$0, 16(%rax)
	jne	.L112
	movl	$256, %edx
	leaq	304(%rsp), %rsi
	movq	%rbx, %rdi
	call	get_window_title
	cvtsi2sd	screen_width(%rip), %xmm1
	movsd	.LC20(%rip), %xmm2
	movl	176(%rsp), %ecx
	cvtsi2sd	%ecx, %xmm0
	mulsd	%xmm2, %xmm1
	comisd	%xmm0, %xmm1
	jbe	.L112
	cvtsi2sd	screen_height(%rip), %xmm0
	movl	180(%rsp), %r8d
	cvtsi2sd	%r8d, %xmm1
	mulsd	%xmm2, %xmm0
	comisd	%xmm1, %xmm0
	jbe	.L112
	leaq	304(%rsp), %rdx
	movq	%rbx, %rsi
	movl	$.LC21, %edi
	xorl	%eax, %eax
	call	log_wm
	jmp	.L147
.L112:
	movq	80(%rsp), %rdi
	call	XFree
.L111:
	movl	$256, %edx
	leaq	304(%rsp), %rsi
	movq	%rbx, %rdi
	movl	$1, %ebp
	call	get_window_title
	movq	%rbx, %rsi
	movl	$.LC22, %edi
	xorl	%eax, %eax
	leaq	304(%rsp), %rdx
	call	log_wm
	jmp	.L96
.L106:
	movq	%rbx, %rsi
	movl	$.LC23, %edi
	xorl	%eax, %eax
	call	log_wm
.L147:
	movq	80(%rsp), %rdi
	call	XFree
.L96:
	addq	$568, %rsp
	movl	%ebp, %eax
	popq	%rbx
	popq	%rbp
	popq	%r12
	popq	%r13
	popq	%r14
	popq	%r15
	ret
	.size	is_manageable, .-is_manageable
	.section	.rodata.str1.1
.LC24:
	.string	"[maximize_window] Maximizing Window 0x%lx to (%d x %d)"
	.text
	.globl	maximize_window
	.type	maximize_window, @function
maximize_window:
	pushq	%rbx
	movq	%rdi, %rbx
	call	is_manageable
	testl	%eax, %eax
	je	.L151
	movl	screen_height(%rip), %ecx
	movq	%rbx, %rsi
	movl	$.LC24, %edi
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
	jmp	XSetWindowBorderWidth
.L151:
	popq	%rbx
	ret
	.size	maximize_window, .-maximize_window
	.globl	set_active_window_prop
	.type	set_active_window_prop, @function
set_active_window_prop:
	subq	$24, %rsp
	movq	atom_net_active(%rip), %rdx
	xorl	%r9d, %r9d
	movq	root(%rip), %rsi
	movq	%rdi, 8(%rsp)
	movl	$32, %r8d
	movl	$33, %ecx
	movq	dpy(%rip), %rdi
	pushq	$1
	leaq	16(%rsp), %rax
	pushq	%rax
	call	XChangeProperty
	addq	$40, %rsp
	ret
	.size	set_active_window_prop, .-set_active_window_prop
	.globl	managed_ancestor
	.type	managed_ancestor, @function
managed_ancestor:
	pushq	%rbx
	movq	%rdi, %rbx
	subq	$32, %rsp
.L157:
	testq	%rbx, %rbx
	je	.L156
	cmpq	%rbx, root(%rip)
	je	.L163
	movl	num_managed(%rip), %edx
	xorl	%eax, %eax
.L158:
	cmpl	%eax, %edx
	jle	.L175
	incq	%rax
	cmpq	%rbx, managed_windows-8(,%rax,8)
	jne	.L158
	jmp	.L156
.L175:
	movq	dpy(%rip), %rdi
	leaq	4(%rsp), %r9
	leaq	24(%rsp), %r8
	movq	%rbx, %rsi
	leaq	16(%rsp), %rcx
	leaq	8(%rsp), %rdx
	movq	$0, 24(%rsp)
	movl	$0, 4(%rsp)
	call	XQueryTree
	testl	%eax, %eax
	je	.L163
	movq	24(%rsp), %rdi
	testq	%rdi, %rdi
	je	.L162
	call	XFree
.L162:
	movq	16(%rsp), %rax
	cmpq	%rbx, %rax
	je	.L163
	movq	%rax, %rbx
	jmp	.L157
.L163:
	xorl	%ebx, %ebx
.L156:
	addq	$32, %rsp
	movq	%rbx, %rax
	popq	%rbx
	ret
	.size	managed_ancestor, .-managed_ancestor
	.globl	focus_next_window
	.type	focus_next_window, @function
focus_next_window:
	cmpl	$0, num_managed(%rip)
	jle	.L184
	pushq	%rbx
	subq	$16, %rsp
	movq	dpy(%rip), %rdi
	leaq	8(%rsp), %rsi
	leaq	4(%rsp), %rdx
	movq	$0, 8(%rsp)
	call	XGetInputFocus
	movq	8(%rsp), %rdi
	call	managed_ancestor
	movl	num_managed(%rip), %esi
	xorl	%ecx, %ecx
	movq	%rax, 8(%rsp)
	movq	%rax, %rdi
.L178:
	cmpl	%ecx, %esi
	jle	.L187
	movq	managed_windows(,%rcx,8), %rdx
	leal	1(%rcx), %eax
	incq	%rcx
	cmpq	%rdx, %rdi
	jne	.L178
	cltd
	idivl	%esi
	jmp	.L182
.L187:
	xorl	%edx, %edx
.L182:
	movslq	%edx, %rdx
	movq	managed_windows(,%rdx,8), %rbx
	cmpq	%rbx, %rdi
	je	.L176
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
.L176:
	addq	$16, %rsp
	popq	%rbx
	ret
.L184:
	ret
	.size	focus_next_window, .-focus_next_window
	.section	.rodata.str1.1
.LC25:
	.string	"emacs_persistent"
.LC26:
	.string	"true"
	.text
	.globl	focus_emacs
	.type	focus_emacs, @function
focus_emacs:
	pushq	%rbp
	movl	$.LC25, %edi
	pushq	%rbx
	subq	$40, %rsp
	call	getenv
	testq	%rax, %rax
	je	.L193
	movl	$.LC26, %esi
	movq	%rax, %rdi
	xorl	%ebx, %ebx
	call	strcasecmp
	testl	%eax, %eax
	jne	.L193
.L190:
	cmpl	%ebx, num_managed(%rip)
	movslq	%ebx, %rbp
	jle	.L212
	movq	managed_windows(,%rbx,8), %rdi
	incq	%rbx
	call	is_emacs
	testl	%eax, %eax
	je	.L190
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
	jmp	.L188
.L212:
	movq	root(%rip), %rsi
	leaq	4(%rsp), %r9
	leaq	24(%rsp), %r8
	movq	dpy(%rip), %rdi
	leaq	16(%rsp), %rcx
	leaq	8(%rsp), %rdx
	movq	$0, 24(%rsp)
	call	XQueryTree
	testl	%eax, %eax
	je	.L193
	xorl	%ebx, %ebx
	cmpq	$0, 24(%rsp)
	je	.L193
.L194:
	movq	24(%rsp), %rdi
	cmpl	%ebx, 4(%rsp)
	jbe	.L213
	movl	%ebx, %eax
	movq	(%rdi,%rax,8), %rdi
	leaq	0(,%rax,8), %rbp
	call	is_emacs
	testl	%eax, %eax
	je	.L195
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
	movq	24(%rsp), %rdi
	call	XFree
	jmp	.L188
.L195:
	incl	%ebx
	jmp	.L194
.L213:
	call	XFree
.L193:
	xorl	%eax, %eax
	call	focus_next_window
.L188:
	addq	$40, %rsp
	popq	%rbx
	popq	%rbp
	ret
	.size	focus_emacs, .-focus_emacs
	.section	.rodata.str1.1
.LC27:
	.string	"ALT_TAB_LOG"
.LC28:
	.string	"================================================="
.LC29:
	.string	"[WM STARTED] Initializing window manager"
.LC30:
	.string	"_NET_SUPPORTED"
.LC31:
	.string	"_NET_ACTIVE_WINDOW"
.LC32:
	.string	"_NET_WM_NAME"
.LC33:
	.string	"_NET_WM_WINDOW_TYPE"
.LC34:
	.string	"UTF8_STRING"
.LC35:
	.string	"_NET_WM_WINDOW_TYPE_NORMAL"
.LC36:
	.string	"_NET_WM_WINDOW_TYPE_DROPDOWN_MENU"
.LC37:
	.string	"_NET_WM_WINDOW_TYPE_POPUP_MENU"
.LC38:
	.string	"_NET_WM_WINDOW_TYPE_MENU"
.LC39:
	.string	"_NET_WM_WINDOW_TYPE_TOOLTIP"
.LC40:
	.string	"_NET_WM_WINDOW_TYPE_NOTIFICATION"
.LC41:
	.string	"_NET_WM_WINDOW_TYPE_COMBO"
.LC42:
	.string	"_NET_WM_WINDOW_TYPE_UTILITY"
.LC43:
	.string	"_NET_WM_WINDOW_TYPE_DIALOG"
.LC44:
	.string	"_NET_WM_WINDOW_TYPE_DOCK"
.LC45:
	.string	"_NET_WM_WINDOW_TYPE_SPLASH"
.LC46:
	.string	"_MOTIF_WM_HINTS"
.LC47:
	.string	""
.LC48:
	.string	"-*-liberation sans-medium-r-normal--14-*-*-*-*-*-*-*,fixed,*"
.LC49:
	.string	"[EVENT: MapRequest] Window 0x%lx ('%s')"
.LC50:
	.string	"[EVENT: ConfigureRequest] Manageable window 0x%lx -> forcing fullscreen"
.LC51:
	.string	"[EVENT: ConfigureRequest] Non-manageable window 0x%lx -> allowing requested geom (%d,%d %dx%d)"
.LC52:
	.string	"[EVENT: UnmapNotify] Window 0x%lx"
.LC53:
	.string	"[EVENT: DestroyNotify] Window 0x%lx"
.LC54:
	.string	"[EVENT: ClientMessage _NET_ACTIVE_WINDOW] Window 0x%lx"
	.section	.text.startup,"ax",@progbits
	.globl	main
	.type	main, @function
main:
	pushq	%r12
	xorl	%edi, %edi
	pushq	%rbp
	pushq	%rbx
	subq	$624, %rsp
	call	XOpenDisplay
	movq	%rax, dpy(%rip)
	testq	%rax, %rax
	je	.L215
	movl	$handle_error, %edi
	call	XSetErrorHandler
	movl	$.LC27, %edi
	call	getenv
	movl	$.LC28, %edi
	testq	%rax, %rax
	setne	%al
	movzbl	%al, %eax
	movl	%eax, logging_enabled(%rip)
	xorl	%eax, %eax
	call	log_wm
	xorl	%eax, %eax
	movl	$.LC29, %edi
	call	log_wm
	movq	dpy(%rip), %rdi
	movl	$.LC30, %esi
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
	movl	$.LC31, %esi
	movq	%rax, %rbx
	call	XInternAtom
	movq	dpy(%rip), %rdi
	xorl	%edx, %edx
	movl	$.LC32, %esi
	movq	%rax, atom_net_active(%rip)
	call	XInternAtom
	movq	dpy(%rip), %rdi
	xorl	%edx, %edx
	movl	$.LC33, %esi
	movq	%rax, atom_net_wm_name(%rip)
	call	XInternAtom
	movq	dpy(%rip), %rdi
	xorl	%edx, %edx
	movl	$.LC34, %esi
	movq	%rax, atom_net_wm_type(%rip)
	call	XInternAtom
	movq	dpy(%rip), %rdi
	xorl	%edx, %edx
	movl	$.LC35, %esi
	movq	%rax, atom_utf8_string(%rip)
	call	XInternAtom
	movq	dpy(%rip), %rdi
	xorl	%edx, %edx
	movl	$.LC36, %esi
	movq	%rax, atom_type_normal(%rip)
	call	XInternAtom
	movq	dpy(%rip), %rdi
	xorl	%edx, %edx
	movl	$.LC37, %esi
	movq	%rax, atom_type_dropdown(%rip)
	call	XInternAtom
	movq	dpy(%rip), %rdi
	xorl	%edx, %edx
	movl	$.LC38, %esi
	movq	%rax, atom_type_popup(%rip)
	call	XInternAtom
	movq	dpy(%rip), %rdi
	xorl	%edx, %edx
	movl	$.LC39, %esi
	movq	%rax, atom_type_menu(%rip)
	call	XInternAtom
	movq	dpy(%rip), %rdi
	xorl	%edx, %edx
	movl	$.LC40, %esi
	movq	%rax, atom_type_tooltip(%rip)
	call	XInternAtom
	movq	dpy(%rip), %rdi
	xorl	%edx, %edx
	movl	$.LC41, %esi
	movq	%rax, atom_type_notification(%rip)
	call	XInternAtom
	movq	dpy(%rip), %rdi
	xorl	%edx, %edx
	movl	$.LC42, %esi
	movq	%rax, atom_type_combo(%rip)
	call	XInternAtom
	movq	dpy(%rip), %rdi
	xorl	%edx, %edx
	movl	$.LC43, %esi
	movq	%rax, atom_type_utility(%rip)
	call	XInternAtom
	movq	dpy(%rip), %rdi
	xorl	%edx, %edx
	movl	$.LC44, %esi
	movq	%rax, atom_type_dialog(%rip)
	call	XInternAtom
	movq	dpy(%rip), %rdi
	xorl	%edx, %edx
	movl	$.LC45, %esi
	movq	%rax, atom_type_dock(%rip)
	call	XInternAtom
	movq	dpy(%rip), %rdi
	xorl	%edx, %edx
	movl	$.LC46, %esi
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
	movq	%rax, 96(%rsp)
	movq	atom_net_wm_name(%rip), %rax
	movq	%rax, 104(%rsp)
	movq	atom_net_wm_type(%rip), %rax
	movq	%rax, 112(%rsp)
	movq	atom_type_normal(%rip), %rax
	movq	%rax, 120(%rsp)
	movq	atom_type_dropdown(%rip), %rax
	movq	%rax, 128(%rsp)
	movq	atom_type_popup(%rip), %rax
	movq	%rax, 136(%rsp)
	movq	atom_type_menu(%rip), %rax
	movq	%rax, 144(%rsp)
	movq	atom_type_tooltip(%rip), %rax
	movq	%rax, 152(%rsp)
	movq	atom_type_dialog(%rip), %rax
	movq	%rax, 160(%rsp)
	movq	atom_type_utility(%rip), %rax
	movq	%rax, 168(%rsp)
	pushq	$10
	leaq	104(%rsp), %rax
	pushq	%rax
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
	movl	$.LC47, %esi
	movl	$6, %edi
	call	setlocale
	leaq	32(%rsp), %r8
	leaq	16(%rsp), %rcx
	movq	dpy(%rip), %rdi
	leaq	24(%rsp), %rdx
	movl	$.LC48, %esi
	call	XCreateFontSet
	popq	%rsi
	popq	%rdi
	movq	%rax, font_set(%rip)
	testq	%rax, %rax
	je	.L215
	movq	%rax, %rdi
	leaq	48(%rsp), %rbx
	call	XExtentsOfFontSet
	leaq	16(%rbx), %r12
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
	movq	%rax, 48(%rsp)
	movabsq	$279172874304, %rax
	movq	%rax, 56(%rsp)
	movl	$1, %eax
	salq	$33, %rax
	movq	%rax, 64(%rsp)
	movabsq	$77309411344, %rax
	movq	%rax, 72(%rsp)
	movabsq	$558345748608, %rax
	movq	%rax, 80(%rsp)
	movabsq	$627065225360, %rax
	movq	%rax, 88(%rsp)
.L216:
	xorl	%ebp, %ebp
.L217:
	movl	(%rbx), %edx
	orl	64(%rsp,%rbp,4), %edx
	pushq	%rax
	movl	$1, %r9d
	pushq	$1
	movq	root(%rip), %rcx
	xorl	%r8d, %r8d
	incq	%rbp
	movzbl	tab_code(%rip), %esi
	movq	dpy(%rip), %rdi
	call	XGrabKey
	popq	%rdx
	popq	%rcx
	cmpq	$8, %rbp
	jne	.L217
	addq	$4, %rbx
	cmpq	%r12, %rbx
	jne	.L216
	movq	root(%rip), %rsi
	leaq	4(%rsp), %r9
	leaq	40(%rsp), %r8
	movq	dpy(%rip), %rdi
	leaq	32(%rsp), %rcx
	leaq	24(%rsp), %rdx
	movq	$0, 40(%rsp)
	call	XQueryTree
	testl	%eax, %eax
	je	.L225
	xorl	%ebx, %ebx
	cmpq	$0, 40(%rsp)
	je	.L225
.L220:
	movq	40(%rsp), %rdi
	cmpl	%ebx, 4(%rsp)
	jbe	.L273
	movl	%ebx, %ebp
	leaq	368(%rsp), %rdx
	movq	(%rdi,%rbp,8), %rsi
	movq	dpy(%rip), %rdi
	call	XGetWindowAttributes
	testl	%eax, %eax
	je	.L222
	cmpl	$0, 488(%rsp)
	jne	.L222
	cmpl	$2, 460(%rsp)
	jne	.L222
	movq	40(%rsp), %rax
	movq	(%rax,%rbp,8), %rdi
	call	is_manageable
	testl	%eax, %eax
	je	.L222
	movq	40(%rsp), %rax
	movq	(%rax,%rbp,8), %rdi
	call	add_window
	movq	40(%rsp), %rax
	movq	(%rax,%rbp,8), %rdi
	call	maximize_window
.L222:
	incl	%ebx
	jmp	.L220
.L273:
	call	XFree
.L225:
	movq	dpy(%rip), %rdi
	leaq	176(%rsp), %rsi
	call	XNextEvent
	movl	176(%rsp), %eax
	cmpl	$20, %eax
	je	.L226
	jg	.L227
	cmpl	$17, %eax
	je	.L228
	cmpl	$18, %eax
	je	.L229
	cmpl	$2, %eax
	jne	.L225
	jmp	.L274
.L227:
	cmpl	$28, %eax
	je	.L232
	cmpl	$33, %eax
	je	.L233
	cmpl	$23, %eax
	jne	.L225
	jmp	.L275
.L226:
	cmpl	$0, logging_enabled(%rip)
	movq	216(%rsp), %rbx
	je	.L235
	movl	$256, %edx
	leaq	368(%rsp), %rsi
	movq	%rbx, %rdi
	call	get_window_title
	movq	%rbx, %rsi
	movl	$.LC49, %edi
	xorl	%eax, %eax
	leaq	368(%rsp), %rdx
	call	log_wm
.L235:
	movq	%rbx, %rdi
	call	is_manageable
	testl	%eax, %eax
	je	.L236
	movq	%rbx, %rdi
	call	add_window
	movq	%rbx, %rdi
	call	maximize_window
	movq	dpy(%rip), %rdi
	movq	%rbx, %rsi
	call	XMapWindow
	xorl	%ecx, %ecx
	movl	$1, %edx
	movq	%rbx, %rsi
	movq	dpy(%rip), %rdi
	call	XSetInputFocus
	movq	%rbx, %rdi
	call	set_active_window_prop
	jmp	.L225
.L236:
	movq	dpy(%rip), %rdi
	movq	%rbx, %rsi
	call	XMapRaised
	jmp	.L225
.L275:
	movq	216(%rsp), %rsi
	movq	%rsi, %rdi
	call	is_managed_window
	testl	%eax, %eax
	je	.L237
	xorl	%eax, %eax
	movl	$.LC50, %edi
	call	log_wm
	movl	screen_width(%rip), %eax
	movl	264(%rsp), %edx
	movq	$0, 368(%rsp)
	movl	$0, 384(%rsp)
	leaq	368(%rsp), %rcx
	movl	%eax, 376(%rsp)
	movl	screen_height(%rip), %eax
	orl	$31, %edx
	movl	%eax, 380(%rsp)
	movq	248(%rsp), %rax
	movq	%rax, 392(%rsp)
	movl	256(%rsp), %eax
	movl	%eax, 400(%rsp)
	jmp	.L269
.L237:
	movl	228(%rsp), %ecx
	xorl	%eax, %eax
	movl	$.LC51, %edi
	movl	224(%rsp), %edx
	movl	236(%rsp), %r9d
	movl	232(%rsp), %r8d
	call	log_wm
	movq	224(%rsp), %rax
	movl	264(%rsp), %edx
	leaq	368(%rsp), %rcx
	movq	%rax, 368(%rsp)
	movq	232(%rsp), %rax
	movq	%rax, 376(%rsp)
	movl	240(%rsp), %eax
	movl	%eax, 384(%rsp)
	movq	248(%rsp), %rax
	movq	%rax, 392(%rsp)
	movl	256(%rsp), %eax
	movl	%eax, 400(%rsp)
.L269:
	movq	216(%rsp), %rsi
	movq	dpy(%rip), %rdi
	call	XConfigureWindow
	jmp	.L225
.L229:
	movq	216(%rsp), %rsi
	movl	$.LC52, %edi
	xorl	%eax, %eax
	call	log_wm
	movq	216(%rsp), %rdi
	cmpq	ignore_unmap_window(%rip), %rdi
	jne	.L272
	movq	$0, ignore_unmap_window(%rip)
	jmp	.L225
.L228:
	movq	216(%rsp), %rsi
	movl	$.LC53, %edi
	xorl	%eax, %eax
	call	log_wm
	movq	216(%rsp), %rdi
.L272:
	call	remove_window
	cmpl	$0, num_managed(%rip)
	jne	.L225
	movq	root(%rip), %rsi
	movq	dpy(%rip), %rdi
	call	XClearWindow
	jmp	.L225
.L232:
	movq	216(%rsp), %rax
	cmpq	%rax, atom_net_wm_name(%rip)
	je	.L244
	cmpq	$39, %rax
	jne	.L225
.L244:
	xorl	%eax, %eax
	call	update_window_list_file
	jmp	.L225
.L233:
	movq	atom_net_active(%rip), %rax
	cmpq	%rax, 216(%rsp)
	jne	.L225
	movq	208(%rsp), %rbx
	xorl	%eax, %eax
	movl	$.LC54, %edi
	movq	%rbx, %rsi
	call	log_wm
	testq	%rbx, %rbx
	je	.L225
	movq	%rbx, %rdi
	call	is_manageable
	testl	%eax, %eax
	je	.L225
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
	jmp	.L225
.L274:
	movzbl	tab_code(%rip), %eax
	cmpl	%eax, 260(%rsp)
	jne	.L225
	xorl	%eax, %eax
	call	focus_emacs
	jmp	.L225
.L215:
	addq	$624, %rsp
	movl	$1, %eax
	popq	%rbx
	popq	%rbp
	popq	%r12
	ret
	.size	main, .-main
	.globl	logging_enabled
	.bss
	.align 4
	.type	logging_enabled, @object
	.size	logging_enabled, 4
logging_enabled:
	.zero	4
	.globl	log_file
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
	.comm	screen_height,4,4
	.comm	screen_width,4,4
	.comm	screen,4,4
	.comm	root,8,8
	.comm	dpy,8,8
	.section	.rodata.cst8,"aM",@progbits,8
	.align 8
.LC20:
	.long	2576980378
	.long	1072273817
	.ident	"GCC: (GNU) 8.4.0"
	.section	.note.GNU-stack,"",@progbits
