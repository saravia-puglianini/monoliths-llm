# ==============================================================================
# ram_report_asm.s - Monitor ultra rápido de memoria RAM en Assembly x86_64
# Ensamblado con GNU as y enlazado con GNU ld (sin libc, binario ELF estático)
# ==============================================================================

.intel_syntax noprefix
.global _start

.set BUF_SIZE, 32768
.set MAX_ENTRIES, 256
.set COMM_LEN, 32
.set ENTRY_SIZE, 40

.section .rodata
proc_dir:
    .asciz "/proc"
statm_suffix:
    .asciz "/statm"
comm_suffix:
    .asciz "/comm"

header_msg:
    .ascii "Memoria (MB)   Programa\n------------   --------\n"
len_header = . - header_msg

mb_str:
    .ascii " MB\t"
len_mb = . - mb_str

newline_str:
    .ascii "\n"

.section .bss
dir_buf:
    .skip BUF_SIZE

path_buf:
    .skip 256

file_buf:
    .skip 512

num_buf:
    .skip 32

table_data:
    .skip MAX_ENTRIES * ENTRY_SIZE
table_count:
    .skip 8

.section .text
_start:
    # Imprimir cabecera
    lea rsi, [header_msg]
    mov rdx, len_header
    mov rdi, 1
    mov rax, 1
    syscall

    # Abrir /proc
    lea rdi, [proc_dir]
    mov rsi, 0x10000        # O_RDONLY | O_DIRECTORY
    mov rax, 2              # sys_open
    syscall
    test rax, rax
    js .exit_done
    mov r12, rax            # fd de /proc

    mov qword ptr [table_count], 0

.read_proc_loop:
    mov rdi, r12
    lea rsi, [dir_buf]
    mov rdx, BUF_SIZE
    mov rax, 217            # sys_getdents64
    syscall

    test rax, rax
    jle .close_proc

    mov r13, rax            # bytes leídos
    xor r14, r14            # offset actual

.parse_dents:
    cmp r14, r13
    jge .read_proc_loop

    lea rbx, [dir_buf + r14]
    movzx r15d, word ptr [rbx + 16]   # d_reclen

    # Verificar si d_type == DT_DIR (4)
    movzx eax, byte ptr [rbx + 18]
    cmp al, 4
    jne .next_dent

    # Verificar si es un PID numérico
    lea rsi, [rbx + 19]
    movzx eax, byte ptr [rsi]
    cmp al, '0'
    jl .next_dent
    cmp al, '9'
    jg .next_dent

    call process_pid

.next_dent:
    add r14, r15
    jmp .parse_dents

.close_proc:
    mov rdi, r12
    mov rax, 3              # sys_close
    syscall

    call sort_and_print_table

.exit_done:
    mov rdi, 0
    mov rax, 60             # sys_exit
    syscall

# -----------------------------------------------------------------------------
process_pid:
    push r12
    push r13
    push r14
    push r15
    push rsi

    # Construir "/proc/<pid>/statm"
    lea rdi, [path_buf]
    mov dword ptr [rdi], 0x6f72702f   # "/pro"
    mov word ptr [rdi+4], 0x2f63      # "c/"
    add rdi, 6

    pop rsi
    push rsi
.copy_pid_statm:
    lodsb
    test al, al
    jz .append_statm
    stosb
    jmp .copy_pid_statm
.append_statm:
    lea rsi, [statm_suffix]
.copy_statm_suf:
    lodsb
    stosb
    test al, al
    jnz .copy_statm_suf

    # Abrir y leer statm
    lea rdi, [path_buf]
    mov rsi, 0
    mov rax, 2
    syscall
    test rax, rax
    js .pid_done
    mov r8, rax

    mov rdi, r8
    lea rsi, [file_buf]
    mov rdx, 256
    mov rax, 0
    syscall
    push rax

    mov rdi, r8
    mov rax, 3
    syscall

    pop rax
    test rax, rax
    jle .pid_done

    # Saltar primer número
    lea rsi, [file_buf]
.skip_first_num:
    lodsb
    cmp al, ' '
    je .found_space
    test al, al
    jz .pid_done
    jmp .skip_first_num
.found_space:
    lodsb
    cmp al, ' '
    je .found_space
    dec rsi

    # Parsear resident
    xor rax, rax
.parse_res_loop:
    movzx edx, byte ptr [rsi]
    cmp dl, '0'
    jl .res_parsed
    cmp dl, '9'
    jg .res_parsed
    sub dl, '0'
    imul rax, rax, 10
    add rax, rdx
    inc rsi
    jmp .parse_res_loop
.res_parsed:
    shl rax, 2              # páginas a KB
    mov r9, rax             # r9 = rss_kb
    test r9, r9
    jz .pid_done

    # Construir "/proc/<pid>/comm"
    lea rdi, [path_buf]
    mov dword ptr [rdi], 0x6f72702f   # "/pro"
    mov word ptr [rdi+4], 0x2f63      # "c/"
    add rdi, 6

    pop rsi
    push rsi
.copy_pid_comm:
    lodsb
    test al, al
    jz .append_comm
    stosb
    jmp .copy_pid_comm
.append_comm:
    lea rsi, [comm_suffix]
.copy_comm_suf:
    lodsb
    stosb
    test al, al
    jnz .copy_comm_suf

    # Abrir y leer comm
    lea rdi, [path_buf]
    mov rsi, 0
    mov rax, 2
    syscall
    test rax, rax
    js .pid_done
    mov r8, rax

    mov rdi, r8
    lea rsi, [file_buf]
    mov rdx, COMM_LEN
    mov rax, 0
    syscall
    mov r10, rax

    mov rdi, r8
    mov rax, 3
    syscall

    cmp r10, 0
    jle .pid_done

    lea rsi, [file_buf]
    cmp byte ptr [rsi + r10 - 1], '\n'
    jne .null_term_comm
    mov byte ptr [rsi + r10 - 1], 0
    dec r10
.null_term_comm:
    mov byte ptr [rsi + r10], 0

    call table_insert_or_add

.pid_done:
    pop rsi
    pop r15
    pop r14
    pop r13
    pop r12
    ret

# -----------------------------------------------------------------------------
table_insert_or_add:
    push rbx
    push rcx
    push rdi
    push rsi
    push r12

    mov rcx, [table_count]
    xor rbx, rbx

.search_entry:
    cmp rbx, rcx
    jge .add_new_entry

    # offset = rbx * 40
    mov rax, rbx
    imul rax, rax, ENTRY_SIZE
    lea r12, [table_data]
    add r12, rax

    lea rdi, [r12 + 8]      # comm
    lea rsi, [file_buf]

.cmp_str:
    mov al, [rsi]
    mov dl, [rdi]
    cmp al, dl
    jne .next_entry
    test al, al
    jz .match_entry
    inc rsi
    inc rdi
    jmp .cmp_str

.next_entry:
    inc rbx
    jmp .search_entry

.match_entry:
    add [r12], r9           # sumar RSS
    jmp .insert_done

.add_new_entry:
    cmp rcx, MAX_ENTRIES
    jge .insert_done

    mov rax, rcx
    imul rax, rax, ENTRY_SIZE
    lea r12, [table_data]
    add r12, rax

    mov [r12], r9           # guardar RSS

    lea rdi, [r12 + 8]
    lea rsi, [file_buf]
    mov r8, 0
.copy_comm_loop:
    mov al, [rsi + r8]
    mov [rdi + r8], al
    test al, al
    jz .comm_copied
    inc r8
    cmp r8, 31
    jl .copy_comm_loop
    mov byte ptr [rdi + 31], 0
.comm_copied:
    inc qword ptr [table_count]

.insert_done:
    pop r12
    pop rsi
    pop rdi
    pop rcx
    pop rbx
    ret

# -----------------------------------------------------------------------------
sort_and_print_table:
    mov rcx, [table_count]
    cmp rcx, 1
    jle .print_entries

    dec rcx
.outer_sort:
    xor rbx, rbx
.inner_sort:
    mov rax, rbx
    imul rax, rax, ENTRY_SIZE
    lea r10, [table_data]
    add r10, rax            # r10 = entrada i
    lea r11, [r10 + ENTRY_SIZE] # r11 = entrada i+1

    mov rax, [r10]
    mov rdx, [r11]
    cmp rax, rdx
    jge .no_swap

    # Swap 40 bytes
    mov rsi, r10
    mov rdi, r11
    mov r8, 5
.swap_loop:
    mov rax, [rsi]
    mov rdx, [rdi]
    mov [rsi], rdx
    mov [rdi], rax
    add rsi, 8
    add rdi, 8
    dec r8
    jnz .swap_loop

.no_swap:
    inc rbx
    cmp rbx, rcx
    jl .inner_sort
    dec rcx
    jnz .outer_sort

.print_entries:
    mov rcx, [table_count]
    cmp rcx, 25
    jle .set_limit
    mov rcx, 25
.set_limit:
    mov r12, rcx
    xor r13, r13

.print_loop:
    cmp r13, r12
    jge .table_done

    mov rax, r13
    imul rax, rax, ENTRY_SIZE
    lea r15, [table_data]
    add r15, rax

    # RSS en KB -> MB (2 decimales)
    mov rax, [r15]
    imul rax, rax, 100
    shr rax, 10
    xor rdx, rdx
    mov rbx, 100
    div rbx

    push rdx
    call print_u64
    pop rdx

    lea rdi, [num_buf]
    mov byte ptr [rdi], '.'
    mov rax, rdx
    xor rdx, rdx
    mov rbx, 10
    div rbx
    add al, '0'
    add dl, '0'
    mov [rdi+1], al
    mov [rdi+2], dl
    lea rsi, [num_buf]
    mov rdx, 3
    mov rdi, 1
    mov rax, 1
    syscall

    lea rsi, [mb_str]
    mov rdx, len_mb
    mov rdi, 1
    mov rax, 1
    syscall

    lea rsi, [r15 + 8]
    xor rdx, rdx
.get_len_comm:
    cmp byte ptr [rsi + rdx], 0
    jz .comm_len_found
    inc rdx
    cmp rdx, 32
    jl .get_len_comm
.comm_len_found:
    mov rdi, 1
    mov rax, 1
    syscall

    lea rsi, [newline_str]
    mov rdx, 1
    mov rdi, 1
    mov rax, 1
    syscall

    inc r13
    jmp .print_loop

.table_done:
    ret

print_u64:
    push r12
    push r13
    lea rdi, [num_buf + 30]
    mov byte ptr [rdi+1], 0
    mov rbx, 10
    xor rcx, rcx

    test rax, rax
    jnz .div_u64_loop
    mov byte ptr [rdi], '0'
    mov rsi, rdi
    mov rdx, 1
    mov rdi, 1
    mov rax, 1
    syscall
    pop r13
    pop r12
    ret

.div_u64_loop:
    xor rdx, rdx
    div rbx
    add dl, '0'
    mov [rdi], dl
    dec rdi
    inc rcx
    test rax, rax
    jnz .div_u64_loop

    inc rdi
    mov rsi, rdi
    mov rdx, rcx
    mov rdi, 1
    mov rax, 1
    syscall

    pop r13
    pop r12
    ret
