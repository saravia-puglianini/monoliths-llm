# ==============================================================================
# bat_asm.s - Monitor ultra rápido de Batería y Fuente de Poder para x86_64
# Ensamblado con GNU as y enlazado con GNU ld (sin libc, binario ELF estático)
# ==============================================================================

.intel_syntax noprefix
.global _start

.section .rodata
adp_path:
    .asciz "/sys/class/power_supply/ADP1/online"
bat_cap_path:
    .asciz "/sys/class/power_supply/BAT0/capacity"
bat_stat_path:
    .asciz "/sys/class/power_supply/BAT0/status"

msg_adp_on:
    .ascii "Corriente: Conectada 🔌\n"
len_adp_on = . - msg_adp_on

msg_adp_off:
    .ascii "Corriente: Desconectada 🔋\n"
len_adp_off = . - msg_adp_off

msg_charge_p1:
    .ascii "Carga actual: "
len_charge_p1 = . - msg_charge_p1

msg_charge_p2:
    .ascii "% ("
len_charge_p2 = . - msg_charge_p2

msg_close_paren:
    .ascii ")\n"
len_close_paren = . - msg_close_paren

.section .bss
buf:
    .skip 128

.section .text
_start:
    # -------------------------------------------------------------------------
    # 1. Leer ADP1/online
    # -------------------------------------------------------------------------
    lea rdi, [adp_path]
    mov rsi, 0              # O_RDONLY
    mov rax, 2              # sys_open
    syscall
    test rax, rax
    js .adp_unknown

    mov rbx, rax            # rbx = fd
    lea rsi, [buf]
    mov rdx, 64
    mov rdi, rbx
    mov rax, 0              # sys_read
    syscall
    push rax                # bytes read

    # sys_close
    mov rdi, rbx
    mov rax, 3
    syscall

    pop rax
    test rax, rax
    jle .adp_unknown

    # Chequear si es '1'
    lea rsi, [buf]
    movzx ecx, byte ptr [rsi]
    cmp cl, '1'
    jne .adp_is_off

.adp_is_on:
    lea rsi, [msg_adp_on]
    mov rdx, len_adp_on
    mov rdi, 1              # stdout
    mov rax, 1              # sys_write
    syscall
    jmp .read_battery

.adp_is_off:
    lea rsi, [msg_adp_off]
    mov rdx, len_adp_off
    mov rdi, 1              # stdout
    mov rax, 1              # sys_write
    syscall
    jmp .read_battery

.adp_unknown:
    lea rsi, [msg_adp_off]
    mov rdx, len_adp_off
    mov rdi, 1
    mov rax, 1
    syscall

    # -------------------------------------------------------------------------
    # 2. Imprimir prefijo de carga
    # -------------------------------------------------------------------------
.read_battery:
    lea rsi, [msg_charge_p1]
    mov rdx, len_charge_p1
    mov rdi, 1
    mov rax, 1
    syscall

    # -------------------------------------------------------------------------
    # 3. Leer BAT0/capacity
    # -------------------------------------------------------------------------
    lea rdi, [bat_cap_path]
    mov rsi, 0              # O_RDONLY
    mov rax, 2              # sys_open
    syscall
    test rax, rax
    js .cap_fail

    mov rbx, rax            # fd
    lea rsi, [buf]
    mov rdx, 64
    mov rdi, rbx
    mov rax, 0              # sys_read
    syscall
    mov r12, rax            # r12 = bytes leidos

    # sys_close
    mov rdi, rbx
    mov rax, 3
    syscall

    # Si hay '\n' al final, quitarlo para imprimir porcentaje
    cmp r12, 0
    jle .cap_fail

    # Recortar espacios/nueva linea
    mov rdx, r12
    lea rsi, [buf]
.trim_cap:
    movzx eax, byte ptr [rsi + rdx - 1]
    cmp al, '\n'
    je .dec_cap
    cmp al, '\r'
    je .dec_cap
    cmp al, ' '
    je .dec_cap
    jmp .print_cap
.dec_cap:
    dec rdx
    jnz .trim_cap

.print_cap:
    mov rdi, 1
    mov rax, 1              # sys_write
    syscall

.print_mid:
    lea rsi, [msg_charge_p2]
    mov rdx, len_charge_p2
    mov rdi, 1
    mov rax, 1
    syscall
    jmp .read_status

.cap_fail:
    # Si falla la capacidad
    lea rsi, [buf]
    mov byte ptr [rsi], 'N'
    mov byte ptr [rsi+1], '/'
    mov byte ptr [rsi+2], 'A'
    mov rdx, 3
    mov rdi, 1
    mov rax, 1
    syscall
    jmp .print_mid

    # -------------------------------------------------------------------------
    # 4. Leer BAT0/status
    # -------------------------------------------------------------------------
.read_status:
    lea rdi, [bat_stat_path]
    mov rsi, 0              # O_RDONLY
    mov rax, 2              # sys_open
    syscall
    test rax, rax
    js .stat_fail

    mov rbx, rax            # fd
    lea rsi, [buf]
    mov rdx, 64
    mov rdi, rbx
    mov rax, 0              # sys_read
    syscall
    mov r12, rax            # r12 = bytes leidos

    # sys_close
    mov rdi, rbx
    mov rax, 3
    syscall

    cmp r12, 0
    jle .stat_fail

    # Recortar nueva linea al final
    mov rdx, r12
    lea rsi, [buf]
.trim_stat:
    movzx eax, byte ptr [rsi + rdx - 1]
    cmp al, '\n'
    je .dec_stat
    cmp al, '\r'
    je .dec_stat
    cmp al, ' '
    je .dec_stat
    jmp .print_stat
.dec_stat:
    dec rdx
    jnz .trim_stat

.print_stat:
    mov rdi, 1
    mov rax, 1              # sys_write
    syscall
    jmp .done_status

.stat_fail:
    lea rsi, [buf]
    mov byte ptr [rsi], '?'
    mov rdx, 1
    mov rdi, 1
    mov rax, 1
    syscall

.done_status:
    # -------------------------------------------------------------------------
    # 5. Imprimir parentesis de cierre y salto de linea
    # -------------------------------------------------------------------------
    lea rsi, [msg_close_paren]
    mov rdx, len_close_paren
    mov rdi, 1
    mov rax, 1
    syscall

    # Exit
    mov rdi, 0
    mov rax, 60             # sys_exit
    syscall
