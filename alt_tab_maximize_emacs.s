.intel_syntax noprefix
.global _start
.global main

/* Constantes X11 y Linux */
.equ SYS_read,          0
.equ SYS_write,         1
.equ SYS_open,          2
.equ SYS_close,         3
.equ SYS_nanosleep,     35
.equ SYS_exit,          60

.equ O_WRONLY_CREAT_TRUNC, 01101  /* O_WRONLY|O_CREAT|O_TRUNC (octal: 01 | 0100 | 01000) */
.equ MODE_644,          0644

.equ MAX_WINDOWS,       1000
.equ None,              0
.equ False,             0
.equ True,              1
.equ CurrentTime,       0
.equ RevertToPointerRoot, 1
.equ GrabModeAsync,     1
.equ PropModeReplace,   0

/* X11 Event Types */
.equ KeyPress,          2
.equ KeyRelease,        3
.equ ButtonPress,       4
.equ MotionNotify,      6
.equ DestroyNotify,     17
.equ UnmapNotify,       18
.equ MapNotify,         19
.equ MapRequest,        20
.equ ConfigureRequest,  23
.equ PropertyNotify,    28
.equ ClientMessage,     33
.equ GenericEvent,      35

/* X11 Event Masks */
.equ KeyPressMask,            1
.equ KeyReleaseMask,          2
.equ SubstructureNotifyMask,   0x80000
.equ SubstructureRedirectMask, 0x100000

/* Modifiers */
.equ ShiftMask,         1
.equ LockMask,          2
.equ Mod1Mask,          8
.equ Mod2Mask,          16
.equ Mod4Mask,          64
.equ Mod5Mask,          128

/* ConfigureWindow value masks */
.equ CWX,               1
.equ CWY,               2
.equ CWWidth,           4
.equ CWHeight,          8
.equ CWBorderWidth,     16

.section .rodata
str_display:            .asciz ":0"
str_emacs_lower:        .asciz "emacs"
str_list_file:          .asciz "/tmp/emacs_non_emacs_windows"
str_net_supported:      .asciz "_NET_SUPPORTED"
str_net_active:         .asciz "_NET_ACTIVE_WINDOW"
str_net_wm_name:        .asciz "_NET_WM_NAME"
str_utf8_string:        .asciz "UTF8_STRING"
str_untitled:           .asciz "Untitled Window"
tab_char:               .asciz "\t"
newline_char:           .asciz "\n"

/* Keysyms X11 */
.equ XK_Tab,            0xff09
.equ XK_Alt_L,          0xffe9
.equ XK_Alt_R,          0xffea
.equ XK_Meta_L,         0xffe7
.equ XK_Meta_R,         0xffe8
.equ XK_Super_L,        0xffeb
.equ XK_Super_R,        0xffec

/* Tiempos de sleep para glitch (15ms = 15000000ns) */
ts_glitch:
    .quad 0
    .quad 15000000

.section .bss
.align 8
dpy:                    .quad 0
root:                   .quad 0
screen:                 .long 0
screen_width:           .long 0
screen_height:          .long 0
num_managed:            .long 0
managed_windows:        .zero 8 * MAX_WINDOWS

atom_net_supported:     .quad 0
atom_net_active:        .quad 0
atom_net_wm_name:       .quad 0
atom_utf8_string:       .quad 0

tab_code:               .byte 0
alt_l_code:             .byte 0
alt_r_code:             .byte 0
meta_l_code:            .byte 0
meta_r_code:            .byte 0
super_l_code:           .byte 0
super_r_code:           .byte 0

/* Buffers de pila/temporales */
buf_keymap:             .zero 32
buf_title:              .zero 512
buf_num:                .zero 32
xevent_buf:             .zero 192
xattrs_buf:             .zero 256
xwinchanges_buf:        .zero 64

.section .text

/* Manejador dummy de errores de X11 */
handle_x_error:
    xor eax, eax
    ret

/* -------------------------------------------------------------
 * uint64_to_str: Convierte un uint64 (rdi) a string en (rsi).
 * Retorna en rax la longitud del string.
 * ------------------------------------------------------------- */
uint64_to_str:
    mov rax, rdi
    mov r8, rsi
    test rax, rax
    jnz .Lconvert_loop_start
    mov byte ptr [r8], '0'
    mov byte ptr [r8+1], 0
    mov eax, 1
    ret
.Lconvert_loop_start:
    lea rcx, [r8 + 30]
    mov byte ptr [rcx], 0
    mov r9, 10
.Lconv_div:
    xor rdx, rdx
    div r9
    add dl, '0'
    dec rcx
    mov [rcx], dl
    test rax, rax
    jnz .Lconv_div
    /* Mover a r8 */
    mov rsi, rcx
    mov rdi, r8
    mov rdx, 0
.Lcopy_conv:
    mov al, [rsi]
    mov [rdi], al
    test al, al
    jz .Lconv_done
    inc rsi
    inc rdi
    inc edx
    jmp .Lcopy_conv
.Lconv_done:
    mov eax, edx
    ret

/* -------------------------------------------------------------
 * strlen_asm: Longitud de string en rdi -> rax
 * ------------------------------------------------------------- */
strlen_asm:
    xor eax, eax
.Lstr_loop:
    cmp byte ptr [rdi + rax], 0
    je .Lstr_done
    inc rax
    jmp .Lstr_loop
.Lstr_done:
    ret

/* -------------------------------------------------------------
 * get_window_title: Obtiene el título de la ventana (rdi = Window, rsi = buf, rdx = max_len)
 * ------------------------------------------------------------- */
get_window_title:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 88

    mov r12, rdi         /* Window */
    mov r13, rsi         /* buf */
    mov r14, rdx         /* max_len */

    /* Intentar XFetchName(dpy, w, &name) */
    mov rdi, [dpy]
    mov rsi, r12
    lea rdx, [rbp - 48]  /* name pointer */
    mov qword ptr [rbp - 48], 0
    call XFetchName
    test eax, eax
    jz .Ltry_net_wm_name

    mov rbx, [rbp - 48]
    test rbx, rbx
    jz .Ltry_net_wm_name
    cmp byte ptr [rbx], 0
    je .Lfree_and_try_net

    /* Copiar name a r13 */
    mov rdi, rbx
    call strlen_asm
    cmp rax, r14
    jb .Lcopy_fetch_name
    lea rax, [r14 - 1]
.Lcopy_fetch_name:
    mov rcx, rax
    mov rsi, rbx
    mov rdi, r13
    rep movsb
    mov byte ptr [rdi], 0

    mov rdi, rbx
    call XFree
    jmp .Ltitle_done

.Lfree_and_try_net:
    mov rdi, rbx
    call XFree

.Ltry_net_wm_name:
    /* XGetWindowProperty(dpy, w, atom_net_wm_name, 0, 1024, False, atom_utf8_string, ...) */
    mov rdi, [dpy]
    mov rsi, r12
    mov rdx, [atom_net_wm_name]
    mov rcx, 0           /* offset */
    mov r8, 1024         /* length */
    mov r9, False        /* delete */
    
    /* Argumentos en stack (6 a 11) */
    mov rax, [atom_utf8_string]
    mov [rsp], rax       /* req_type */
    lea rax, [rbp - 56]
    mov [rsp + 8], rax   /* actual_type_return */
    lea rax, [rbp - 64]
    mov [rsp + 16], rax  /* actual_format_return */
    lea rax, [rbp - 72]
    mov [rsp + 24], rax  /* nitems_return */
    lea rax, [rbp - 80]
    mov [rsp + 32], rax  /* bytes_after_return */
    lea rax, [rbp - 88]
    mov [rsp + 40], rax  /* prop_return */
    mov qword ptr [rbp - 88], 0

    call XGetWindowProperty
    test eax, eax
    jnz .Lfallback_untitled

    mov rbx, [rbp - 88]
    test rbx, rbx
    jz .Lfallback_untitled

    /* Copiar prop */
    mov rdi, rbx
    call strlen_asm
    cmp rax, r14
    jb .Lcopy_prop
    lea rax, [r14 - 1]
.Lcopy_prop:
    mov rcx, rax
    mov rsi, rbx
    mov rdi, r13
    rep movsb
    mov byte ptr [rdi], 0

    mov rdi, rbx
    call XFree
    jmp .Ltitle_done

.Lfallback_untitled:
    lea rsi, [rip + str_untitled]
    mov rdi, r13
.Lcopy_unt:
    lodsb
    stosb
    test al, al
    jnz .Lcopy_unt

.Ltitle_done:
    add rsp, 88
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

/* -------------------------------------------------------------
 * strcasecmp_asm: Comparación case-insensitive de cadenas (rdi, rsi)
 * Retorna 0 en eax si coinciden.
 * ------------------------------------------------------------- */
strcasecmp_asm:
.Lcase_loop:
    movzx eax, byte ptr [rdi]
    movzx edx, byte ptr [rsi]
    
    /* Convertir eax a minúscula */
    cmp al, 'A'
    jb .Lskip_a
    cmp al, 'Z'
    ja .Lskip_a
    add al, 32
.Lskip_a:

    /* Convertir edx a minúscula */
    cmp dl, 'A'
    jb .Lskip_d
    cmp dl, 'Z'
    ja .Lskip_d
    add dl, 32
.Lskip_d:

    cmp al, dl
    jne .Ldiff_char
    test al, al
    jz .Lmatch_done
    inc rdi
    inc rsi
    jmp .Lcase_loop
.Ldiff_char:
    sub eax, edx
    ret
.Lmatch_done:
    xor eax, eax
    ret

/* -------------------------------------------------------------
 * is_emacs: Determina si una ventana es Emacs (rdi = Window) -> eax (1 si es Emacs, 0 si no)
 * ------------------------------------------------------------- */
is_emacs:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    sub rsp, 40

    mov r12, rdi
    xor r13d, r13d       /* res = 0 */

    /* XGetClassHint(dpy, w, &class_hint) */
    mov rdi, [dpy]
    mov rsi, r12
    lea rdx, [rbp - 32]  /* XClassHint: {char* res_name; char* res_class;} */
    mov qword ptr [rbp - 32], 0
    mov qword ptr [rbp - 24], 0
    call XGetClassHint
    test eax, eax
    jz .Ldone_is_emacs

    /* Chequear res_name */
    mov rdi, [rbp - 32]
    test rdi, rdi
    jz .Lcheck_res_class
    lea rsi, [rip + str_emacs_lower]
    call strcasecmp_asm
    test eax, eax
    jnz .Lcheck_res_class
    mov r13d, 1

.Lcheck_res_class:
    mov rdi, [rbp - 24]
    test rdi, rdi
    jz .Lfree_class_hints
    lea rsi, [rip + str_emacs_lower]
    call strcasecmp_asm
    test eax, eax
    jnz .Lfree_class_hints
    mov r13d, 1

.Lfree_class_hints:
    mov rdi, [rbp - 32]
    test rdi, rdi
    jz .Lfree_rc
    call XFree
.Lfree_rc:
    mov rdi, [rbp - 24]
    test rdi, rdi
    jz .Ldone_is_emacs
    call XFree

.Ldone_is_emacs:
    mov eax, r13d
    add rsp, 40
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

/* -------------------------------------------------------------
 * is_manageable: Verifica si la ventana no tiene override_redirect ni transient_for
 * rdi = Window -> eax (1 si es manejable, 0 si no)
 * ------------------------------------------------------------- */
is_manageable:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    sub rsp, 24

    mov r12, rdi

    /* XGetWindowAttributes(dpy, w, &attrs) */
    mov rdi, [dpy]
    mov rsi, r12
    lea rdx, [rip + xattrs_buf]
    call XGetWindowAttributes
    test eax, eax
    jz .Lnot_manageable

    /* offset de override_redirect en XWindowAttributes es byte/int según struct (offset 84/88) */
    /* En x86_64, override_redirect es int (offset 84) */
    mov eax, dword ptr [rip + xattrs_buf + 84]
    test eax, eax
    jnz .Lnot_manageable

    /* XGetTransientForHint(dpy, w, &transient_for) */
    mov rdi, [dpy]
    mov rsi, r12
    lea rdx, [rbp - 16]
    mov qword ptr [rbp - 16], 0
    call XGetTransientForHint
    test eax, eax
    jz .Lis_manageable_yes

    mov rax, [rbp - 16]
    test rax, rax
    jz .Lis_manageable_yes
    cmp rax, [root]
    je .Lis_manageable_yes

.Lnot_manageable:
    xor eax, eax
    jmp .Ldone_is_manageable

.Lis_manageable_yes:
    mov eax, 1

.Ldone_is_manageable:
    add rsp, 24
    pop r12
    pop rbx
    pop rbp
    ret

/* -------------------------------------------------------------
 * update_window_list_file: Vuelca /tmp/emacs_non_emacs_windows con syscalls directas
 * ------------------------------------------------------------- */
update_window_list_file:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 16

    /* open(str_list_file, O_WRONLY|O_CREAT|O_TRUNC, 0644) */
    mov rax, SYS_open
    lea rdi, [rip + str_list_file]
    mov rsi, O_WRONLY_CREAT_TRUNC
    mov rdx, MODE_644
    syscall
    test rax, rax
    js .Lupdate_done
    mov r12, rax         /* r12 = fd */

    xor r13d, r13d       /* i = 0 */
.Lupdate_loop:
    mov eax, [num_managed]
    cmp r13d, eax
    jge .Lclose_file

    lea rax, [rip + managed_windows]
    mov rbx, [rax + r13*8]

    mov rdi, rbx
    call is_emacs
    test eax, eax
    jnz .Lnext_win_update

    /* uint64_to_str(rbx, buf_num) */
    mov rdi, rbx
    lea rsi, [rip + buf_num]
    call uint64_to_str
    mov r14, rax         /* longitud num */

    /* write(fd, buf_num, len) */
    mov rax, SYS_write
    mov rdi, r12
    lea rsi, [rip + buf_num]
    mov rdx, r14
    syscall

    /* write(fd, "\t", 1) */
    mov rax, SYS_write
    mov rdi, r12
    lea rsi, [rip + tab_char]
    mov rdx, 1
    syscall

    /* get_window_title(rbx, buf_title, 512) */
    mov rdi, rbx
    lea rsi, [rip + buf_title]
    mov rdx, 512
    call get_window_title

    lea rdi, [rip + buf_title]
    call strlen_asm
    mov r14, rax

    /* write(fd, buf_title, len) */
    mov rax, SYS_write
    mov rdi, r12
    lea rsi, [rip + buf_title]
    mov rdx, r14
    syscall

    /* write(fd, "\n", 1) */
    mov rax, SYS_write
    mov rdi, r12
    lea rsi, [rip + newline_char]
    mov rdx, 1
    syscall

.Lnext_win_update:
    inc r13d
    jmp .Lupdate_loop

.Lclose_file:
    mov rax, SYS_close
    mov rdi, r12
    syscall

.Lupdate_done:
    add rsp, 16
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

/* -------------------------------------------------------------
 * remove_window: Elimina una ventana de la lista MRU (rdi = Window)
 * ------------------------------------------------------------- */
remove_window:
    push rbx
    push r12
    push r13

    mov r12, rdi
    xor ebx, ebx
.Lrem_loop:
    mov eax, [num_managed]
    cmp ebx, eax
    jge .Lrem_done

    lea rdx, [rip + managed_windows]
    cmp [rdx + rbx*8], r12
    je .Lrem_found
    inc ebx
    jmp .Lrem_loop

.Lrem_found:
    /* memmove(&managed_windows[i], &managed_windows[i+1], (num_managed - i - 1)*8) */
    mov eax, [num_managed]
    dec eax
    mov [num_managed], eax
    sub eax, ebx
    test eax, eax
    jle .Lrem_after_move

    mov ecx, eax         /* count */
    lea rdi, [rip + managed_windows]
    lea rdi, [rdi + rbx*8]
    lea rsi, [rdi + 8]
    shl rcx, 3
    /* copiar bytes hacia adelante */
    cld
    rep movsb

.Lrem_after_move:
    call update_window_list_file

.Lrem_done:
    pop r13
    pop r12
    pop rbx
    ret

/* -------------------------------------------------------------
 * add_window: Inserta al inicio de la lista MRU (rdi = Window)
 * ------------------------------------------------------------- */
add_window:
    push rbx
    push r12

    mov r12, rdi
    call remove_window

    mov eax, [num_managed]
    cmp eax, MAX_WINDOWS
    jge .Ladd_done

    /* Desplazar elementos a la derecha si num_managed > 0 */
    test eax, eax
    jz .Linsert_first

    lea rsi, [rip + managed_windows]
    mov ecx, eax
    dec ecx
.Lshift_right:
    mov rdx, [rsi + rcx*8]
    mov [rsi + rcx*8 + 8], rdx
    dec ecx
    jns .Lshift_right

.Linsert_first:
    lea rsi, [rip + managed_windows]
    mov [rsi], r12
    inc dword ptr [num_managed]

    /* XSelectInput(dpy, w, PropertyChangeMask) -> PropertyChangeMask = 0x400000 */
    mov rdi, [dpy]
    mov rsi, r12
    mov rdx, 0x400000
    call XSelectInput

    call update_window_list_file

.Ladd_done:
    pop r12
    pop rbx
    ret

/* -------------------------------------------------------------
 * maximize_window: Maximiza la ventana (rdi = Window)
 * ------------------------------------------------------------- */
maximize_window:
    push rbx
    push r12
    mov r12, rdi

    call is_manageable
    test eax, eax
    jz .Lmax_done

    /* XMoveResizeWindow(dpy, w, 0, 0, screen_width, screen_height) */
    mov rdi, [dpy]
    mov rsi, r12
    mov rdx, 0
    mov rcx, 0
    mov r8d, [screen_width]
    mov r9d, [screen_height]
    call XMoveResizeWindow

    /* XSetWindowBorderWidth(dpy, w, 0) */
    mov rdi, [dpy]
    mov rsi, r12
    mov rdx, 0
    call XSetWindowBorderWidth

.Lmax_done:
    pop r12
    pop rbx
    ret

/* -------------------------------------------------------------
 * set_active_window_prop: Establece _NET_ACTIVE_WINDOW (rdi = Window)
 * ------------------------------------------------------------- */
set_active_window_prop:
    push rbp
    mov rbp, rsp
    push rbx
    sub rsp, 72

    mov [rbp - 8], rdi

    mov rdi, [dpy]
    mov rsi, [root]
    mov rdx, [atom_net_active]
    mov rcx, 33          /* XA_WINDOW = 33 */
    mov r8, 32           /* format = 32 */
    mov r9, PropModeReplace

    lea rax, [rbp - 8]
    mov [rsp], rax       /* data */
    mov qword ptr [rsp + 8], 1 /* nelements */

    call XChangeProperty

    add rsp, 72
    pop rbx
    pop rbp
    ret

/* -------------------------------------------------------------
 * focus_emacs: Busca y enfoca la ventana de Emacs
 * ------------------------------------------------------------- */
focus_emacs:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    sub rsp, 48

    xor r13d, r13d
.Lsearch_managed:
    mov eax, [num_managed]
    cmp r13d, eax
    jge .Lsearch_tree

    lea rax, [rip + managed_windows]
    mov r12, [rax + r13*8]
    mov rdi, r12
    call is_emacs
    test eax, eax
    jnz .Lfound_emacs
    inc r13d
    jmp .Lsearch_managed

.Lsearch_tree:
    /* XQueryTree(dpy, root, &root_ret, &parent_ret, &windows, &nwindows) */
    mov rdi, [dpy]
    mov rsi, [root]
    lea rdx, [rbp - 16]  /* root_ret */
    lea rcx, [rbp - 24]  /* parent_ret */
    lea r8, [rbp - 32]   /* windows */
    lea r9, [rbp - 40]   /* nwindows */
    mov qword ptr [rbp - 32], 0
    call XQueryTree
    test eax, eax
    jz .Lfocus_emacs_done

    mov rbx, [rbp - 32]
    test rbx, rbx
    jz .Lfocus_emacs_done

    mov r14d, dword ptr [rbp - 40]
    xor r13d, r13d
.Ltree_loop:
    cmp r13d, r14d
    jge .Lfree_tree_none

    mov r12, [rbx + r13*8]
    mov rdi, r12
    call is_emacs
    test eax, eax
    jnz .Lfound_tree_emacs
    inc r13d
    jmp .Ltree_loop

.Lfound_tree_emacs:
    mov rdi, rbx
    call XFree
    jmp .Lfound_emacs

.Lfree_tree_none:
    mov rdi, rbx
    call XFree
    jmp .Lfocus_emacs_done

.Lfound_emacs:
    /* XRaiseWindow(dpy, r12) */
    mov rdi, [dpy]
    mov rsi, r12
    call XRaiseWindow

    /* XSetInputFocus(dpy, r12, RevertToPointerRoot, CurrentTime) */
    mov rdi, [dpy]
    mov rsi, r12
    mov rdx, RevertToPointerRoot
    mov rcx, CurrentTime
    call XSetInputFocus

    mov rdi, r12
    call set_active_window_prop

    mov rdi, r12
    call add_window

.Lfocus_emacs_done:
    add rsp, 48
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

/* -------------------------------------------------------------
 * MAIN ENTRY POINT
 * ------------------------------------------------------------- */
_start:
main:
    push rbp
    mov rbp, rsp
    sub rsp, 64

    /* XOpenDisplay(NULL) */
    xor rdi, rdi
    call XOpenDisplay
    test rax, rax
    jnz .Ldpy_ok
    mov rax, SYS_exit
    mov rdi, 1
    syscall
.Ldpy_ok:
    mov [dpy], rax

    /* XSetErrorHandler(handle_x_error) */
    lea rdi, [rip + handle_x_error]
    call XSetErrorHandler

    /* Screen & Dimensiones */
    mov rdi, [dpy]
    call XDefaultScreen
    mov [screen], eax

    mov rdi, [dpy]
    mov esi, [screen]
    call XRootWindow
    mov [root], rax

    mov rdi, [dpy]
    mov esi, [screen]
    call XDisplayWidth
    mov [screen_width], eax

    mov rdi, [dpy]
    mov esi, [screen]
    call XDisplayHeight
    mov [screen_height], eax

    /* Intern Atoms */
    mov rdi, [dpy]
    lea rsi, [rip + str_net_supported]
    mov rdx, False
    call XInternAtom
    mov [atom_net_supported], rax

    mov rdi, [dpy]
    lea rsi, [rip + str_net_active]
    mov rdx, False
    call XInternAtom
    mov [atom_net_active], rax

    mov rdi, [dpy]
    lea rsi, [rip + str_net_wm_name]
    mov rdx, False
    call XInternAtom
    mov [atom_net_wm_name], rax

    mov rdi, [dpy]
    lea rsi, [rip + str_utf8_string]
    mov rdx, False
    call XInternAtom
    mov [atom_utf8_string], rax

    /* Configurar eventos en root window */
    mov rdi, [dpy]
    mov rsi, [root]
    mov rdx, SubstructureRedirectMask | SubstructureNotifyMask | KeyPressMask | KeyReleaseMask
    call XSelectInput

    /* Obtener Keycodes */
    mov rdi, [dpy]
    mov rsi, XK_Tab
    call XKeysymToKeycode
    mov [tab_code], al

    mov rdi, [dpy]
    mov rsi, XK_Alt_L
    call XKeysymToKeycode
    mov [alt_l_code], al

    mov rdi, [dpy]
    mov rsi, XK_Alt_R
    call XKeysymToKeycode
    mov [alt_r_code], al

    mov rdi, [dpy]
    mov rsi, XK_Meta_L
    call XKeysymToKeycode
    mov [meta_l_code], al

    mov rdi, [dpy]
    mov rsi, XK_Meta_R
    call XKeysymToKeycode
    mov [meta_r_code], al

    mov rdi, [dpy]
    mov rsi, XK_Super_L
    call XKeysymToKeycode
    mov [super_l_code], al

    mov rdi, [dpy]
    mov rsi, XK_Super_R
    call XKeysymToKeycode
    mov [super_r_code], al

    /* XGrabKey para combinaciones de Alt+Tab y Super+Tab con locks (Caps, NumLock) */
    /* Modificadores: Mod1 (Alt), Mod4 (Super) */
    movzx esi, byte ptr [tab_code]

    /* Alt + Tab */
    mov rdi, [dpy]
    movzx rsi, byte ptr [tab_code]
    mov rdx, Mod1Mask
    mov rcx, [root]
    mov r8, False
    mov r9, GrabModeAsync
    push GrabModeAsync
    call XGrabKey
    add rsp, 8

    /* Alt + Shift + Tab */
    mov rdi, [dpy]
    movzx rsi, byte ptr [tab_code]
    mov rdx, Mod1Mask | ShiftMask
    mov rcx, [root]
    mov r8, False
    mov r9, GrabModeAsync
    push GrabModeAsync
    call XGrabKey
    add rsp, 8

    /* Super + Tab */
    mov rdi, [dpy]
    movzx rsi, byte ptr [tab_code]
    mov rdx, Mod4Mask
    mov rcx, [root]
    mov r8, False
    mov r9, GrabModeAsync
    push GrabModeAsync
    call XGrabKey
    add rsp, 8

    /* Escaneo inicial de ventanas ya existentes */
    mov rdi, [dpy]
    mov rsi, [root]
    lea rdx, [rbp - 8]
    lea rcx, [rbp - 16]
    lea r8, [rbp - 24]
    lea r9, [rbp - 32]
    call XQueryTree
    test eax, eax
    jz .Levent_loop

    mov rbx, [rbp - 24]
    test rbx, rbx
    jz .Levent_loop

    mov r12d, dword ptr [rbp - 32]
    xor r13d, r13d
.Linit_tree_loop:
    cmp r13d, r12d
    jge .Linit_tree_done
    mov rdi, [rbx + r13*8]
    push rdi
    call is_manageable
    pop rdi
    test eax, eax
    jz .Linit_next
    push rdi
    call add_window
    pop rdi
    call maximize_window
.Linit_next:
    inc r13d
    jmp .Linit_tree_loop
.Linit_tree_done:
    mov rdi, rbx
    call XFree

/* =============================================================
 * BUCLE PRINCIPAL DE EVENTOS X11
 * ============================================================= */
.Levent_loop:
    mov rdi, [dpy]
    lea rsi, [rip + xevent_buf]
    call XNextEvent

    mov eax, dword ptr [rip + xevent_buf]   /* ev.type */

    cmp eax, MapRequest
    je .Lhandle_map_request

    cmp eax, ConfigureRequest
    je .Lhandle_configure_request

    cmp eax, UnmapNotify
    je .Lhandle_unmap_notify

    cmp eax, DestroyNotify
    je .Lhandle_destroy_notify

    cmp eax, PropertyNotify
    je .Lhandle_property_notify

    cmp eax, ClientMessage
    je .Lhandle_client_message

    cmp eax, KeyPress
    je .Lhandle_key_press

    jmp .Levent_loop

/* -------------------------------------------------------------
 * Handler: MapRequest (offset window = 32)
 * ------------------------------------------------------------- */
.Lhandle_map_request:
    mov r12, qword ptr [rip + xevent_buf + 32]

    mov rdi, r12
    call is_manageable
    test eax, eax
    jz .Lmap_non_manageable

    mov rdi, r12
    call add_window
    mov rdi, r12
    call maximize_window

    mov rdi, [dpy]
    mov rsi, r12
    call XMapWindow

    mov rdi, [dpy]
    mov rsi, r12
    mov rdx, RevertToPointerRoot
    mov rcx, CurrentTime
    call XSetInputFocus

    mov rdi, r12
    call set_active_window_prop
    jmp .Levent_loop

.Lmap_non_manageable:
    mov rdi, [dpy]
    mov rsi, r12
    call XMapRaised
    jmp .Levent_loop

/* -------------------------------------------------------------
 * Handler: ConfigureRequest
 * ------------------------------------------------------------- */
.Lhandle_configure_request:
    /* window = offset 32, x=40, y=44, w=48, h=52, border=56, above=64, detail=72, mask=80 */
    mov r12, qword ptr [rip + xevent_buf + 32]

    mov rdi, r12
    call is_manageable
    test eax, eax
    jz .Lconfig_non_manageable

    /* Manageable -> Forzar fullscreen 0,0,screen_width,screen_height */
    lea rbx, [rip + xwinchanges_buf]
    mov dword ptr [rbx + 0], 0               /* x = 0 */
    mov dword ptr [rbx + 4], 0               /* y = 0 */
    mov eax, [screen_width]
    mov dword ptr [rbx + 8], eax             /* width */
    mov eax, [screen_height]
    mov dword ptr [rbx + 12], eax            /* height */
    mov dword ptr [rbx + 16], 0              /* border_width = 0 */
    mov rax, qword ptr [rip + xevent_buf + 64]
    mov qword ptr [rbx + 24], rax            /* sibling */
    mov eax, dword ptr [rip + xevent_buf + 72]
    mov dword ptr [rbx + 32], eax            /* stack_mode */

    mov rdi, [dpy]
    mov rsi, r12
    mov rdx, qword ptr [rip + xevent_buf + 80]
    or rdx, (CWX | CWY | CWWidth | CWHeight | CWBorderWidth)
    lea rcx, [rip + xwinchanges_buf]
    call XConfigureWindow
    jmp .Levent_loop

.Lconfig_non_manageable:
    lea rbx, [rip + xwinchanges_buf]
    mov eax, dword ptr [rip + xevent_buf + 40]
    mov dword ptr [rbx + 0], eax             /* x */
    mov eax, dword ptr [rip + xevent_buf + 44]
    mov dword ptr [rbx + 4], eax             /* y */
    mov eax, dword ptr [rip + xevent_buf + 48]
    mov dword ptr [rbx + 8], eax             /* width */
    mov eax, dword ptr [rip + xevent_buf + 52]
    mov dword ptr [rbx + 12], eax            /* height */
    mov eax, dword ptr [rip + xevent_buf + 56]
    mov dword ptr [rbx + 16], eax            /* border_width */
    mov rax, qword ptr [rip + xevent_buf + 64]
    mov qword ptr [rbx + 24], rax            /* sibling */
    mov eax, dword ptr [rip + xevent_buf + 72]
    mov dword ptr [rbx + 32], eax            /* stack_mode */

    mov rdi, [dpy]
    mov rsi, r12
    mov rdx, qword ptr [rip + xevent_buf + 80]
    lea rcx, [rip + xwinchanges_buf]
    call XConfigureWindow
    jmp .Levent_loop

/* -------------------------------------------------------------
 * Handler: UnmapNotify (window = offset 32)
 * ------------------------------------------------------------- */
.Lhandle_unmap_notify:
    mov rdi, qword ptr [rip + xevent_buf + 32]
    call remove_window
    jmp .Levent_loop

/* -------------------------------------------------------------
 * Handler: DestroyNotify (window = offset 32)
 * ------------------------------------------------------------- */
.Lhandle_destroy_notify:
    mov rdi, qword ptr [rip + xevent_buf + 32]
    call remove_window
    jmp .Levent_loop

/* -------------------------------------------------------------
 * Handler: PropertyNotify (atom = offset 40)
 * ------------------------------------------------------------- */
.Lhandle_property_notify:
    mov rax, qword ptr [rip + xevent_buf + 40]
    cmp rax, [atom_net_wm_name]
    je .Lupdate_prop
    cmp rax, 39                              /* XA_WM_NAME = 39 */
    je .Lupdate_prop
    jmp .Levent_loop
.Lupdate_prop:
    call update_window_list_file
    jmp .Levent_loop

/* -------------------------------------------------------------
 * Handler: ClientMessage (message_type = offset 40, window = offset 32)
 * ------------------------------------------------------------- */
.Lhandle_client_message:
    mov rax, qword ptr [rip + xevent_buf + 40]
    cmp rax, [atom_net_active]
    jne .Levent_loop

    /* Window en data.l[0] o xclient.window */
    mov r12, qword ptr [rip + xevent_buf + 32]
    test r12, r12
    jz .Levent_loop

    mov rdi, r12
    call is_manageable
    test eax, eax
    jz .Levent_loop

    mov rdi, [dpy]
    mov rsi, r12
    call XRaiseWindow

    mov rdi, [dpy]
    mov rsi, r12
    mov rdx, RevertToPointerRoot
    mov rcx, CurrentTime
    call XSetInputFocus

    mov rdi, r12
    call set_active_window_prop

    mov rdi, r12
    call add_window
    jmp .Levent_loop

/* -------------------------------------------------------------
 * Handler: KeyPress (keycode = offset 84)
 * ------------------------------------------------------------- */
.Lhandle_key_press:
    movzx eax, byte ptr [rip + xevent_buf + 84]
    movzx edx, byte ptr [tab_code]
    cmp eax, edx
    jne .Levent_loop

    /* Alt/Super + Tab presionado -> enfocar Emacs inmediatamente */
    call focus_emacs
    jmp .Levent_loop
