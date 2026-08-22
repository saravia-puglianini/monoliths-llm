.intel_syntax noprefix
.global _start

.equ SYS_read,      0
.equ SYS_open,      2
.equ SYS_close,     3
.equ SYS_nanosleep, 35
.equ SYS_execve,    59
.equ SYS_exit,      60

.equ O_RDONLY,      0

.section .rodata
/* Ruta para detección instantánea de hardware sin doas ni dmesg */
sys_vendor_file:    .asciz "/sys/class/dmi/id/sys_vendor"
str_hp_vendor:      .asciz "HP"

/* Prefijo base de la ruta */
str_ocr_prefix:     .asciz "/home/user/monoliths-llm/ocr_"

/* Acciones y lenguajes */
str_vociferar:      .asciz "vociferar"
str_traducir:       .asciz "traducir"
str_es:             .asciz "es"
str_en:             .asciz "en"
str_de:             .asciz "de"
str_hp:             .asciz "HP"
str_asus:           .asciz "ASUS"
str_under:          .asciz "_"

/* 80ms de sleep antes de capturar pantalla (80,000,000 ns) */
timespec_sleep:
    .quad 0
    .quad 80000000

.section .bss
.align 8
buf_vendor:         .zero 128
buf_target_path:    .zero 512
argv_exec:          .zero 64
is_hp_machine:      .byte 0

.section .text

/* -------------------------------------------------------------
 * detect_hardware: Lee /sys/class/dmi/id/sys_vendor
 * Si contiene "HP", fija is_hp_machine = 1, si no 0.
 * ------------------------------------------------------------- */
detect_hardware:
    mov rax, SYS_open
    lea rdi, [rip + sys_vendor_file]
    mov rsi, O_RDONLY
    xor rdx, rdx
    syscall
    test rax, rax
    js .Lset_asus_default
    mov r8, rax         /* fd */

    mov rax, SYS_read
    mov rdi, r8
    lea rsi, [rip + buf_vendor]
    mov rdx, 127
    syscall
    mov r9, rax         /* bytes read */

    mov rax, SYS_close
    mov rdi, r8
    syscall

    test r9, r9
    jle .Lset_asus_default

    /* Buscar "HP" en buf_vendor */
    lea rsi, [rip + buf_vendor]
    xor ecx, ecx
.Lcheck_hp_loop:
    cmp rcx, r9
    jge .Lset_asus_default
    mov al, [rsi + rcx]
    cmp al, 'H'
    jne .Lnext_hp_char
    lea rdx, [rcx + 1]
    cmp rdx, r9
    jge .Lset_asus_default
    mov ah, [rsi + rdx]
    cmp ah, 'P'
    je .Lfound_hp
.Lnext_hp_char:
    inc rcx
    jmp .Lcheck_hp_loop

.Lfound_hp:
    mov byte ptr [rip + is_hp_machine], 1
    ret

.Lset_asus_default:
    mov byte ptr [rip + is_hp_machine], 0
    ret

/* -------------------------------------------------------------
 * append_str: Añade el string en rsi a [rdi], actualiza rdi al final
 * ------------------------------------------------------------- */
append_str:
.Lapp_loop:
    mov al, [rsi]
    test al, al
    jz .Lapp_done
    mov [rdi], al
    inc rsi
    inc rdi
    jmp .Lapp_loop
.Lapp_done:
    ret

/* -------------------------------------------------------------
 * MAIN ENTRY POINT:
 * Argumentos esperados:
 *   argv[1]: "vociferar" | "traducir"
 *   argv[2]: "es" | "en" | "de"
 * Ejemplo de llamada directa:
 *   /usr/local/bin/ocr_fast vociferar es
 * ------------------------------------------------------------- */
_start:
    /* Leer argc y argv desde la pila */
    pop rcx             /* argc */
    cmp rcx, 3
    jl .Lexit_err

    pop rdx             /* argv[0] */
    pop r12             /* argv[1] = action ("vociferar" o "traducir") */
    pop r13             /* argv[2] = lang ("es", "en", "de") */

    /* 1. Nanosleep rápido (80ms) para liberar modificadores */
    mov rax, SYS_nanosleep
    lea rdi, [rip + timespec_sleep]
    xor rsi, rsi
    syscall

    /* 2. Detección instantánea de máquina en syscall directa */
    call detect_hardware

    /* 3. Construir ruta final: "/home/user/monoliths-llm/ocr_" + action + "_" + lang + "_" + (HP|ASUS) */
    lea rdi, [rip + buf_target_path]
    lea rsi, [rip + str_ocr_prefix]
    call append_str

    mov rsi, r12
    call append_str

    lea rsi, [rip + str_under]
    call append_str

    mov rsi, r13
    call append_str

    lea rsi, [rip + str_under]
    call append_str

    cmp byte ptr [rip + is_hp_machine], 1
    je .Lappend_hp
    lea rsi, [rip + str_asus]
    jmp .Ldo_append_brand
.Lappend_hp:
    lea rsi, [rip + str_hp]
.Ldo_append_brand:
    call append_str
    mov byte ptr [rdi], 0

    /* 4. Configurar argv_exec y ejecutar execve */
    lea rax, [rip + buf_target_path]
    lea rbx, [rip + argv_exec]
    mov [rbx], rax          /* argv[0] = target binary/script */
    mov [rbx + 8], r12      /* argv[1] = action */
    mov [rbx + 16], r13     /* argv[2] = lang */
    mov qword ptr [rbx + 24], 0 /* NULL */

    mov rax, SYS_execve
    lea rdi, [rip + buf_target_path]
    lea rsi, [rip + argv_exec]
    xor rdx, rdx            /* envp = NULL (hereda o vacío) */
    syscall

.Lexit_err:
    mov rax, SYS_exit
    mov rdi, 1
    syscall
