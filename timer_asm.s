# ==============================================================================
# timer_asm.s - Temporizador / Cuenta Regresiva de Precisión en Assembly x86_64
# Ensamblado con GNU as y enlazado con GNU ld (sin libc, binario ELF estático)
# Uso: ./timer_asm <minutos>
# ==============================================================================

.intel_syntax noprefix
.global _start

.section .rodata
usage_msg:
    .ascii "Uso: timer_asm <minutos>\n"
len_usage_msg = . - usage_msg

stop_file:
    .asciz "/tmp/.stop"

ansi_clear_line:
    .ascii "\r\033[K"
len_clear_line = . - ansi_clear_line

str_alt3:
    .ascii " [alt+3 / touch /tmp/.stop to exit]\r"
len_alt3 = . - str_alt3

newline:
    .ascii "\n"

# Estructura timespec para 1 segundo (1s, 0ns)
one_sec_ts:
    .quad 1             # tv_sec
    .quad 0             # tv_nsec

.section .bss
rem_ts:
    .skip 16
out_buf:
    .skip 64

.section .text
_start:
    # Leer argumentos desde la pila
    # RSP apunta a argc, RSP+8 a argv[0], RSP+16 a argv[1]
    mov rcx, [rsp]       # argc
    cmp rcx, 2
    jl .show_usage

    mov rsi, [rsp + 16]  # argv[1]
    test rsi, rsi
    jz .show_usage

    # Convertir argv[1] (ASCII) a entero
    xor rax, rax        # minutos
    xor rdx, rdx
.parse_digits:
    movzx edx, byte ptr [rsi]
    test dl, dl
    jz .parsed
    cmp dl, '0'
    jl .show_usage
    cmp dl, '9'
    jg .show_usage
    sub dl, '0'
    imul rax, rax, 10
    add rax, rdx
    inc rsi
    jmp .parse_digits

.parsed:
    # rax tiene los minutos
    # Segundos totales = minutos * 60 - 13 (siguiendo timer.sh)
    imul rax, rax, 60
    sub rax, 13
    test rax, rax
    jle .done           # si ya es <= 0, salir
    mov r12, rax        # r12 = segundos restantes

.loop:
    # 1. Chequear si existe /tmp/.stop (sys_access = 21, F_OK = 0)
    lea rdi, [stop_file]
    mov rsi, 0          # F_OK
    mov rax, 21         # sys_access
    syscall
    test rax, rax
    jz .done            # si existe el archivo, salir

    # 2. Calcular Minutos y Segundos
    mov rax, r12
    xor rdx, rdx
    mov rbx, 60
    div rbx             # rax = min (cociente), rdx = sec (residuo)
    mov r13, rax        # r13 = min
    mov r14, rdx        # r14 = sec

    # 3. Formatear "MM:SS" en out_buf
    lea rdi, [out_buf]

    # Minutos (decenas y unidades)
    mov rax, r13
    xor rdx, rdx
    mov rbx, 10
    div rbx
    add al, '0'
    mov [rdi], al
    add dl, '0'
    mov [rdi+1], dl

    mov byte ptr [rdi+2], ':'

    # Segundos (decenas y unidades)
    mov rax, r14
    xor rdx, rdx
    mov rbx, 10
    div rbx
    add al, '0'
    mov [rdi+3], al
    add dl, '0'
    mov [rdi+4], dl

    # 4. Imprimir en pantalla con retorno de carro
    # Limpiar linea
    lea rsi, [ansi_clear_line]
    mov rdx, len_clear_line
    mov rdi, 1
    mov rax, 1          # sys_write
    syscall

    # Imprimir MM:SS
    lea rsi, [out_buf]
    mov rdx, 5
    mov rdi, 1
    mov rax, 1
    syscall

    # Imprimir aviso de salida
    lea rsi, [str_alt3]
    mov rdx, len_alt3
    mov rdi, 1
    mov rax, 1
    syscall

    # 5. Dormir exactamente 1 segundo (sys_nanosleep = 35)
    lea rdi, [one_sec_ts]
    lea rsi, [rem_ts]
    mov rax, 35         # sys_nanosleep
    syscall

    # 6. Decrementar segundos
    dec r12
    jnz .loop

.done:
    # Imprimir salto de linea final
    lea rsi, [newline]
    mov rdx, 1
    mov rdi, 1
    mov rax, 1
    syscall

    mov rdi, 0
    mov rax, 60         # sys_exit
    syscall

.show_usage:
    lea rsi, [usage_msg]
    mov rdx, len_usage_msg
    mov rdi, 2          # stderr
    mov rax, 1          # sys_write
    syscall

    mov rdi, 1
    mov rax, 60         # sys_exit
    syscall
