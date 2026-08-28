# ==============================================================================
# hotkey_listener_asm.s - Reemplazo integral y nativo de xbindkeys en x86_64 ASM
# Soporta Cambio Dinámico de Modo:
#   - Modo Teclado (Normal)
#   - Modo Mouse (Type-to-move-cursor: Q,W,E,A,S,D,Z,X,C,F,J,U,M, etc.)
#   - Atajos para alternar:
#       * Alt + 2: Activa Modo Mouse
#       * Alt + 1: Vuelve al Modo Teclado
#       * XF86TouchpadToggle: Alterna entre ambos modos
# ==============================================================================

.intel_syntax noprefix
.global main

.section .rodata
msg_started:
    .ascii "[hotkey_listener_asm] Reemplazo de xbindkeys activo en X11 (:0).\n"
    .ascii "[*] Modo TECLADO activo. (Presiona Alt+2 para pasar a Modo Mouse)\n"
len_started = . - msg_started

msg_mode_mouse:
    .ascii "[*] Cambiando a MODO MOUSE (WASD/QEZXC=Mover, F=Click Izq, J=Click Der, U/M=Scroll, Alt+1=Salir)\n"
len_mode_mouse = . - msg_mode_mouse

msg_mode_kbd:
    .ascii "[*] Regresando a MODO TECLADO normal.\n"
len_mode_kbd = . - msg_mode_kbd

# Modificadores X11
.set ShiftMask,    1
.set LockMask,     2
.set ControlMask,  4
.set Mod1Mask,     8     # Alt
.set Mod2Mask,     16    # NumLock
.set Mod4Mask,     64    # Super / Windows key

.set GrabModeAsync, 1
.set KeyPress,      2
.set ButtonRelease, 5

sh_bin:             .asciz "/bin/sh"
sh_arg_c:           .asciz "-c"

# Comandos de Sistema
cmd_alt3:           .asciz "touch /tmp/.stop && sleep 3 && [ -f /tmp/.stop ] && rm /tmp/.stop"
cmd_alt4:           .asciz "sleep 0.5 && bash ~/monoliths-llm/english-or-german-to-clipboard-on-spanish.sh"
cmd_alt5:           .asciz "sleep 0.5 && ([ -f /tmp/_xcalib_working ] && rm /tmp/_xcalib_working || touch /tmp/_xcalib_working ) ; xcalib -i -a"
cmd_alt6:           .asciz "sleep 0.5 && if pgrep picom > /dev/null; then killall picom; else sleep 0.9 && picom --backend glx --no-fading-openclose --inactive-opacity=1.0 --active-opacity=1.0 --frame-opacity=1.0 --no-use-damage --window-shader-fg $HOME/monoliths-llm/blackandwhite.frag & fi"
cmd_alt8:           .asciz "sleep 0.5 && ( pgrep -x scrot && (killall scrot; cd ~ && scrot -e 'xclip -selection clipboard -t image/png -i $f') || ( cd ~ && scrot -s -e 'xclip -selection clipboard -t image/png -i $f') )"
cmd_alt9:           .asciz "sleep 0.5 && (cat ~/.emacs.d/lineamientos.md; echo) | xclip -selection clipboard"
cmd_alt_shift8:     .asciz "/home/user/monoliths-llm/screenshot.sh"

cmd_vol_down:       .asciz "amixer -q sset Master 5%-"
cmd_vol_up:         .asciz "amixer -q sset Master 5%+"
cmd_vol_mute:       .asciz "amixer -q sset Master toggle"
cmd_bright_down:    .asciz "/home/user/monoliths-llm/change_brightness.sh down"
cmd_bright_up:      .asciz "/home/user/monoliths-llm/change_brightness.sh up"
cmd_poweroff:       .asciz "doas poweroff"
cmd_mod4_p:         .asciz "pgrep arandr && killall arandr || arandr"
cmd_mod4_l:         .asciz "[ -f /tmp/_xcalib_working ] && i3lock -c ffffff || i3lock -c 000000"

# Comandos de Modo Mouse (type_move)
cmd_mouse_q:        .asciz "/home/user/.type-to-move-cursor/bin/type_move move -45 -45 -11 -11"
cmd_mouse_w:        .asciz "/home/user/.type-to-move-cursor/bin/type_move move 0 -45 0 -11"
cmd_mouse_e:        .asciz "/home/user/.type-to-move-cursor/bin/type_move move 45 -45 11 -11"
cmd_mouse_a:        .asciz "/home/user/.type-to-move-cursor/bin/type_move move -45 0 -11 0"
cmd_mouse_d:        .asciz "/home/user/.type-to-move-cursor/bin/type_move move 45 0 11 0"
cmd_mouse_z:        .asciz "/home/user/.type-to-move-cursor/bin/type_move wrapper z"
cmd_mouse_x:        .asciz "/home/user/.type-to-move-cursor/bin/type_move move 0 45 0 11"
cmd_mouse_c:        .asciz "/home/user/.type-to-move-cursor/bin/type_move move 45 45 11 11"
cmd_mouse_y:        .asciz "/home/user/.type-to-move-cursor/bin/type_move wrapper y"
cmd_mouse_f:        .asciz "/home/user/.type-to-move-cursor/bin/type_move click 1"
cmd_mouse_j:        .asciz "/home/user/.type-to-move-cursor/bin/type_move click 3"
cmd_mouse_u:        .asciz "/home/user/.type-to-move-cursor/bin/type_move click_repeat 4 1"
cmd_mouse_m:        .asciz "/home/user/.type-to-move-cursor/bin/type_move click_repeat 5 1"
cmd_mouse_s:        .asciz "/home/user/.type-to-move-cursor/bin/type_move toggle_middle"
cmd_mouse_r:        .asciz "/home/user/.type-to-move-cursor/bin/type_move drag_start"
cmd_mouse_g:        .asciz "/home/user/.type-to-move-cursor/bin/type_move release_all"
cmd_mouse_p:        .asciz "dash $HOME/.type-to-move-cursor/P.sh"
cmd_mouse_o:        .asciz "dash $HOME/.type-to-move-cursor/O.sh"
cmd_mouse_ctrl_u:   .asciz "/home/user/.type-to-move-cursor/bin/type_move ctrl_wheel 4"
cmd_mouse_ctrl_m:   .asciz "/home/user/.type-to-move-cursor/bin/type_move ctrl_wheel 5"

notify_mouse_on:    .asciz "sh -c '(notify-send \"Keyboard is Mouse\" &) && sleep .5 && pkill -f \"Keyboard is Mouse\"' &>/dev/null"
notify_mouse_off:   .asciz "sh -c '(notify-send \"Keyboard is Keyboard\" &) && sleep .5 && pkill -f \"Keyboard is Keyboard\"' &>/dev/null"

# Keysyms strings
sym_vol_down:       .asciz "XF86AudioLowerVolume"
sym_vol_up:         .asciz "XF86AudioRaiseVolume"
sym_vol_mute:       .asciz "XF86AudioMute"
sym_bright_down:    .asciz "XF86MonBrightnessDown"
sym_bright_up:      .asciz "XF86MonBrightnessUp"
sym_poweroff:       .asciz "XF86PowerOff"
sym_touchpad:       .asciz "XF86TouchpadToggle"

ocr_cmd1:           .asciz "ocr_fast vociferar es"
ocr_cmd2:           .asciz "ocr_fast traducir es"
ocr_cmd3:           .asciz "ocr_fast vociferar en"
ocr_cmd4:           .asciz "ocr_fast traducir en"
ocr_cmd5:           .asciz "ocr_fast vociferar de"
ocr_cmd6:           .asciz "ocr_fast traducir de"
fmt_dbg:            .asciz "[DBG] KeyPress: keycode=%d, state=%d\n"
fmt_grab_dbg:       .asciz "[DBG] XGrabKey: keycode=%ld, modifiers=%ld -> status=%ld\n"

.section .bss
.align 8
display_ptr:        .skip 8
root_window:        .skip 8
x_event:            .skip 192
argv_exec:          .skip 64
saved_envp:         .skip 8

# Estado del modo: 0 = Teclado Normal, 1 = Modo Mouse
current_mode:       .skip 8

# Keycodes generales
kc_1:               .skip 8
kc_2:               .skip 8
kc_3:               .skip 8
kc_4:               .skip 8
kc_5:               .skip 8
kc_6:               .skip 8
kc_8:               .skip 8
kc_9:               .skip 8
kc_b:               .skip 8
kc_r:               .skip 8
kc_p:               .skip 8
kc_l:               .skip 8
kc_vol_down:        .skip 8
kc_vol_up:          .skip 8
kc_vol_mute:        .skip 8
kc_bright_down:     .skip 8
kc_bright_up:       .skip 8
kc_poweroff:        .skip 8
kc_touchpad:        .skip 8

# Keycodes de modo mouse
kc_m_q:             .skip 8
kc_m_w:             .skip 8
kc_m_e:             .skip 8
kc_m_a:             .skip 8
kc_m_s:             .skip 8
kc_m_d:             .skip 8
kc_m_z:             .skip 8
kc_m_x:             .skip 8
kc_m_c:             .skip 8
kc_m_y:             .skip 8
kc_m_f:             .skip 8
kc_m_j:             .skip 8
kc_m_u:             .skip 8
kc_m_m:             .skip 8
kc_m_g:             .skip 8
kc_m_o:             .skip 8

.section .text
main:
    push rbp
    mov rbp, rsp
    sub rsp, 32

    # Guardar puntero al entorno (envp en rdx según System V ABI)
    mov [saved_envp], rdx

    # Evitar zombis: el kernel libera automáticamente los hijos al terminar.
    # signal(SIGCHLD, SIG_IGN)
    mov edi, 17
    mov esi, 1
    call signal

    mov qword ptr [current_mode], 0

    # 1. Abrir Display
    xor rdi, rdi
    call XOpenDisplay
    test rax, rax
    jz .err_exit
    mov [display_ptr], rax

    # 2. Root Window
    mov rdi, [display_ptr]
    call XDefaultRootWindow
    mov [root_window], rax

    # 3. Mapear Keysyms a Keycodes
    call init_keycodes

    # 4. Registrar atajos globales permanentes (Modo Teclado)
    call register_base_hotkeys

    # 5. Registrar mouse OCR triggers
    call register_mouse_triggers

    # Mensaje de inicio
    lea rsi, [msg_started]
    mov rdx, len_started
    mov rdi, 1
    mov rax, 1
    syscall

.main_event_loop:
    mov rdi, [display_ptr]
    lea rsi, [x_event]
    call XNextEvent

    mov eax, dword ptr [x_event]
    cmp eax, KeyPress
    je .handle_key_press

    cmp eax, ButtonRelease
    je .handle_mouse_release

    jmp .main_event_loop

# -----------------------------------------------------------------------------
# Manejador de Pulsación de Teclas
# -----------------------------------------------------------------------------
.handle_key_press:
    mov edx, dword ptr [x_event + 84]   # keycode
    mov ecx, dword ptr [x_event + 80]   # state
    and ecx, ~(Mod2Mask | LockMask)     # ignorar NumLock y CapsLock

    # -------------------------------------------------------------------------
    # SWITCH DE MODOS: Alt+1 (KBD), Alt+2 (MOUSE), TouchpadToggle
    # -------------------------------------------------------------------------
    cmp rdx, [kc_2]
    jne .check_mode_switch_1
    cmp ecx, Mod1Mask
    jne .check_mode_switch_1
    call activate_mouse_mode
    jmp .main_event_loop

.check_mode_switch_1:
    cmp rdx, [kc_1]
    jne .check_touchpad_toggle
    cmp ecx, Mod1Mask
    jne .check_touchpad_toggle
    call activate_keyboard_mode
    jmp .main_event_loop

.check_touchpad_toggle:
    cmp rdx, [kc_touchpad]
    jne .check_current_mode_bindings
    cmp qword ptr [current_mode], 0
    je .do_toggle_to_mouse
    call activate_keyboard_mode
    jmp .main_event_loop
.do_toggle_to_mouse:
    call activate_mouse_mode
    jmp .main_event_loop

.check_current_mode_bindings:
    cmp qword ptr [current_mode], 1
    je .handle_mouse_mode_keys

    # -------------------------------------------------------------------------
    # MODO TECLADO NORMAL:
    # -------------------------------------------------------------------------
.check_3:
    cmp rdx, [kc_3]
    jne .check_4
    cmp ecx, Mod1Mask
    jne .check_4
    lea rdi, [cmd_alt3]
    call execute_sh
    jmp .main_event_loop

.check_4:
    cmp rdx, [kc_4]
    jne .check_5
    cmp ecx, Mod1Mask
    jne .check_5
    lea rdi, [cmd_alt4]
    call execute_sh
    jmp .main_event_loop

.check_5:
    cmp rdx, [kc_5]
    jne .check_6
    cmp ecx, Mod1Mask
    jne .check_6
    lea rdi, [cmd_alt5]
    call execute_sh
    jmp .main_event_loop

.check_6:
    cmp rdx, [kc_6]
    jne .check_8
    cmp ecx, Mod1Mask
    jne .check_8
    lea rdi, [cmd_alt6]
    call execute_sh
    jmp .main_event_loop

.check_8:
    cmp rdx, [kc_8]
    jne .check_9
    cmp ecx, Mod1Mask | ShiftMask
    jne .check_8_norm
    lea rdi, [cmd_alt_shift8]
    call execute_sh
    jmp .main_event_loop
.check_8_norm:
    cmp ecx, Mod1Mask
    jne .check_9
    lea rdi, [cmd_alt8]
    call execute_sh
    jmp .main_event_loop

.check_9:
    cmp rdx, [kc_9]
    jne .check_multimedia
    cmp ecx, Mod1Mask
    jne .check_multimedia
    lea rdi, [cmd_alt9]
    call execute_sh
    jmp .main_event_loop

.check_multimedia:
    cmp rdx, [kc_vol_down]; je .do_vol_down
    cmp rdx, 122; je .do_vol_down
    cmp rdx, [kc_vol_up]; je .do_vol_up
    cmp rdx, 123; je .do_vol_up
    cmp rdx, [kc_vol_mute]; je .do_vol_mute
    cmp rdx, 121; je .do_vol_mute
    cmp rdx, [kc_bright_down]; je .do_bright_down
    cmp rdx, 232; je .do_bright_down
    cmp rdx, [kc_bright_up]; je .do_bright_up
    cmp rdx, 233; je .do_bright_up
    cmp rdx, [kc_poweroff]; je .do_poweroff

    cmp rdx, [kc_p]; jne .check_l
    cmp ecx, Mod4Mask; jne .check_l
    lea rdi, [cmd_mod4_p]; call execute_sh; jmp .main_event_loop

.check_l:
    cmp rdx, [kc_l]; jne .main_event_loop
    cmp ecx, Mod4Mask; jne .main_event_loop
    lea rdi, [cmd_mod4_l]; call execute_sh; jmp .main_event_loop

.do_vol_down: lea rdi, [cmd_vol_down]; call execute_sh; jmp .main_event_loop
.do_vol_up: lea rdi, [cmd_vol_up]; call execute_sh; jmp .main_event_loop
.do_vol_mute: lea rdi, [cmd_vol_mute]; call execute_sh; jmp .main_event_loop
.do_bright_down: lea rdi, [cmd_bright_down]; call execute_sh; jmp .main_event_loop
.do_bright_up: lea rdi, [cmd_bright_up]; call execute_sh; jmp .main_event_loop
.do_poweroff: lea rdi, [cmd_poweroff]; call execute_sh; jmp .main_event_loop

# -----------------------------------------------------------------------------
# MODO MOUSE (Type-to-move-cursor)
# -----------------------------------------------------------------------------
.handle_mouse_mode_keys:
    cmp rdx, [kc_m_q]; jne .chk_w
    lea rdi, [cmd_mouse_q]; call execute_sh; jmp .main_event_loop
.chk_w:
    cmp rdx, [kc_m_w]; jne .chk_e
    lea rdi, [cmd_mouse_w]; call execute_sh; jmp .main_event_loop
.chk_e:
    cmp rdx, [kc_m_e]; jne .chk_a
    lea rdi, [cmd_mouse_e]; call execute_sh; jmp .main_event_loop
.chk_a:
    cmp rdx, [kc_m_a]; jne .chk_d
    lea rdi, [cmd_mouse_a]; call execute_sh; jmp .main_event_loop
.chk_d:
    cmp rdx, [kc_m_d]; jne .chk_z
    lea rdi, [cmd_mouse_d]; call execute_sh; jmp .main_event_loop
.chk_z:
    cmp rdx, [kc_m_z]; jne .chk_x
    lea rdi, [cmd_mouse_z]; call execute_sh; jmp .main_event_loop
.chk_x:
    cmp rdx, [kc_m_x]; jne .chk_c
    lea rdi, [cmd_mouse_x]; call execute_sh; jmp .main_event_loop
.chk_c:
    cmp rdx, [kc_m_c]; jne .chk_y
    lea rdi, [cmd_mouse_c]; call execute_sh; jmp .main_event_loop
.chk_y:
    cmp rdx, [kc_m_y]; jne .chk_f
    lea rdi, [cmd_mouse_y]; call execute_sh; jmp .main_event_loop
.chk_f:
    cmp rdx, [kc_m_f]; jne .chk_j
    lea rdi, [cmd_mouse_f]; call execute_sh; jmp .main_event_loop
.chk_j:
    cmp rdx, [kc_m_j]; jne .chk_u
    lea rdi, [cmd_mouse_j]; call execute_sh; jmp .main_event_loop
.chk_u:
    cmp rdx, [kc_m_u]; jne .chk_m
    cmp ecx, ControlMask
    jne .chk_u_norm
    lea rdi, [cmd_mouse_ctrl_u]; call execute_sh; jmp .main_event_loop
.chk_u_norm:
    lea rdi, [cmd_mouse_u]; call execute_sh; jmp .main_event_loop
.chk_m:
    cmp rdx, [kc_m_m]; jne .chk_s
    cmp ecx, ControlMask
    jne .chk_m_norm
    lea rdi, [cmd_mouse_ctrl_m]; call execute_sh; jmp .main_event_loop
.chk_m_norm:
    lea rdi, [cmd_mouse_m]; call execute_sh; jmp .main_event_loop
.chk_s:
    cmp rdx, [kc_m_s]; jne .chk_r_mouse
    lea rdi, [cmd_mouse_s]; call execute_sh; jmp .main_event_loop
.chk_r_mouse:
    cmp rdx, [kc_r]; jne .chk_g
    lea rdi, [cmd_mouse_r]; call execute_sh; jmp .main_event_loop
.chk_g:
    cmp rdx, [kc_m_g]; jne .chk_p_mouse
    lea rdi, [cmd_mouse_g]; call execute_sh; jmp .main_event_loop
.chk_p_mouse:
    cmp rdx, [kc_p]; jne .chk_o
    lea rdi, [cmd_mouse_p]; call execute_sh; jmp .main_event_loop
.chk_o:
    cmp rdx, [kc_m_o]; jne .chk_common_fallback
    lea rdi, [cmd_mouse_o]; call execute_sh; jmp .main_event_loop

.chk_common_fallback:
    jmp .check_multimedia

# -----------------------------------------------------------------------------
# ACTIVAR / DESACTIVAR MODO MOUSE
# -----------------------------------------------------------------------------
activate_mouse_mode:
    push rbp
    mov rbp, rsp
    sub rsp, 16

    cmp qword ptr [current_mode], 1
    je .already_mouse

    mov qword ptr [current_mode], 1

    mov rdi, [kc_m_q]; mov rsi, 0; call grab_key
    mov rdi, [kc_m_w]; mov rsi, 0; call grab_key
    mov rdi, [kc_m_e]; mov rsi, 0; call grab_key
    mov rdi, [kc_m_a]; mov rsi, 0; call grab_key
    mov rdi, [kc_m_s]; mov rsi, 0; call grab_key
    mov rdi, [kc_m_d]; mov rsi, 0; call grab_key
    mov rdi, [kc_m_z]; mov rsi, 0; call grab_key
    mov rdi, [kc_m_x]; mov rsi, 0; call grab_key
    mov rdi, [kc_m_c]; mov rsi, 0; call grab_key
    mov rdi, [kc_m_y]; mov rsi, 0; call grab_key
    mov rdi, [kc_m_f]; mov rsi, 0; call grab_key
    mov rdi, [kc_m_j]; mov rsi, 0; call grab_key
    mov rdi, [kc_m_u]; mov rsi, 0; call grab_key
    mov rdi, [kc_m_m]; mov rsi, 0; call grab_key
    mov rdi, [kc_r];   mov rsi, 0; call grab_key
    mov rdi, [kc_m_g]; mov rsi, 0; call grab_key
    mov rdi, [kc_p];   mov rsi, 0; call grab_key
    mov rdi, [kc_m_o]; mov rsi, 0; call grab_key

    mov rdi, [kc_m_u]; mov rsi, ControlMask; call grab_key
    mov rdi, [kc_m_m]; mov rsi, ControlMask; call grab_key

    lea rsi, [msg_mode_mouse]
    mov rdx, len_mode_mouse
    mov rdi, 1
    mov rax, 1
    syscall

    lea rdi, [notify_mouse_on]
    call execute_sh

.already_mouse:
    mov rsp, rbp
    pop rbp
    ret

activate_keyboard_mode:
    push rbp
    mov rbp, rsp
    sub rsp, 16

    cmp qword ptr [current_mode], 0
    je .already_kbd

    mov qword ptr [current_mode], 0

    mov rdi, [kc_m_q]; mov rsi, 0; call ungrab_key
    mov rdi, [kc_m_w]; mov rsi, 0; call ungrab_key
    mov rdi, [kc_m_e]; mov rsi, 0; call ungrab_key
    mov rdi, [kc_m_a]; mov rsi, 0; call ungrab_key
    mov rdi, [kc_m_s]; mov rsi, 0; call ungrab_key
    mov rdi, [kc_m_d]; mov rsi, 0; call ungrab_key
    mov rdi, [kc_m_z]; mov rsi, 0; call ungrab_key
    mov rdi, [kc_m_x]; mov rsi, 0; call ungrab_key
    mov rdi, [kc_m_c]; mov rsi, 0; call ungrab_key
    mov rdi, [kc_m_y]; mov rsi, 0; call ungrab_key
    mov rdi, [kc_m_f]; mov rsi, 0; call ungrab_key
    mov rdi, [kc_m_j]; mov rsi, 0; call ungrab_key
    mov rdi, [kc_m_u]; mov rsi, 0; call ungrab_key
    mov rdi, [kc_m_m]; mov rsi, 0; call ungrab_key
    mov rdi, [kc_r];   mov rsi, 0; call ungrab_key
    mov rdi, [kc_m_g]; mov rsi, 0; call ungrab_key
    mov rdi, [kc_p];   mov rsi, 0; call ungrab_key
    mov rdi, [kc_m_o]; mov rsi, 0; call ungrab_key

    mov rdi, [kc_m_u]; mov rsi, ControlMask; call ungrab_key
    mov rdi, [kc_m_m]; mov rsi, ControlMask; call ungrab_key

    lea rsi, [msg_mode_kbd]
    mov rdx, len_mode_kbd
    mov rdi, 1
    mov rax, 1
    syscall

    lea rdi, [notify_mouse_off]
    call execute_sh

.already_kbd:
    mov rsp, rbp
    pop rbp
    ret

# -----------------------------------------------------------------------------
# Manejador de Botones del Mouse (OCR Release Triggers)
# -----------------------------------------------------------------------------
.handle_mouse_release:
    mov edx, dword ptr [x_event + 84]
    mov ecx, dword ptr [x_event + 80]
    and ecx, 0xFF                       # conservar solo modificadores de teclado (Shift, Lock, Ctrl, Alt, Mod4)
    and ecx, ~(Mod2Mask | LockMask)     # ignorar NumLock y CapsLock

    cmp ecx, ControlMask; jne .check_ocr2
    lea rdi, [ocr_cmd1]; call execute_sh; jmp .main_event_loop
.check_ocr2:
    cmp ecx, ControlMask | ShiftMask; jne .check_ocr3
    lea rdi, [ocr_cmd2]; call execute_sh; jmp .main_event_loop
.check_ocr3:
    cmp ecx, Mod4Mask; jne .check_ocr4
    lea rdi, [ocr_cmd3]; call execute_sh; jmp .main_event_loop
.check_ocr4:
    cmp ecx, Mod4Mask | ShiftMask; jne .check_ocr5
    lea rdi, [ocr_cmd4]; call execute_sh; jmp .main_event_loop
.check_ocr5:
    cmp ecx, Mod1Mask; jne .check_ocr6
    lea rdi, [ocr_cmd5]; call execute_sh; jmp .main_event_loop
.check_ocr6:
    cmp ecx, Mod1Mask | ShiftMask; jne .main_event_loop
    lea rdi, [ocr_cmd6]; call execute_sh; jmp .main_event_loop

# -----------------------------------------------------------------------------
# Funciones auxiliares
# -----------------------------------------------------------------------------
execute_command:
    push rdi
    mov rax, 57         # sys_fork
    syscall
    test rax, rax
    jnz .fork_parent
    pop rdi
    lea rbx, [argv_exec]
    mov [rbx], rdi
    mov qword ptr [rbx+8], 0
    mov rsi, rbx
    mov rdx, [saved_envp] # pasar variables de entorno (DISPLAY, PATH, HOME, etc.)
    mov rax, 59         # sys_execve
    syscall
    mov rdi, 127; mov rax, 60; syscall
.fork_parent:
    pop rdi
    ret

execute_sh:
    push rdi
    mov rax, 57         # sys_fork
    syscall
    test rax, rax
    jnz .fork_parent_sh
    pop rdi
    lea rbx, [argv_exec]
    lea rax, [sh_bin]
    mov [rbx], rax
    lea rax, [sh_arg_c]
    mov [rbx+8], rax
    mov [rbx+16], rdi
    mov qword ptr [rbx+24], 0
    lea rdi, [sh_bin]
    mov rsi, rbx
    mov rdx, [saved_envp] # pasar variables de entorno (DISPLAY, PATH, HOME, etc.)
    mov rax, 59         # sys_execve
    syscall
    mov rdi, 127; mov rax, 60; syscall
.fork_parent_sh:
    pop rdi
    ret

grab_key:
    push rbp
    mov rbp, rsp
    sub rsp, 32
    mov [rbp-8], rdi    # keycode
    mov [rbp-16], rsi   # modifiers

    # 7mo arg en stack
    mov qword ptr [rsp], GrabModeAsync

    mov rdi, [display_ptr]
    mov rsi, [rbp-8]
    mov rdx, [rbp-16]
    mov rcx, [root_window]
    mov r8, 0
    mov r9, GrabModeAsync
    call XGrabKey

    mov rsp, rbp
    pop rbp
    ret

ungrab_key:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    mov [rbp-8], rdi
    mov [rbp-16], rsi

    mov rdi, [display_ptr]
    mov rsi, [rbp-8]
    mov rdx, [rbp-16]
    mov rcx, [root_window]
    call XUngrabKey

    mov rsp, rbp
    pop rbp
    ret

grab_mouse_button:
    push rbp
    mov rbp, rsp
    sub rsp, 48
    mov [rbp-8], rdi    # button
    mov [rbp-16], rsi   # modifiers

    # stack args para XGrabButton (args 7..10: pointer_mode, keyboard_mode, confine_to, cursor)
    mov qword ptr [rsp], GrabModeAsync
    mov qword ptr [rsp+8], GrabModeAsync
    mov qword ptr [rsp+16], 0
    mov qword ptr [rsp+24], 0

    mov rdi, [display_ptr]
    mov rsi, [rbp-8]
    mov rdx, [rbp-16]
    mov rcx, [root_window]
    mov r8, 0
    mov r9, 12          # ButtonPressMask (4) | ButtonReleaseMask (8)
    call XGrabButton

    mov rsp, rbp
    pop rbp
    ret

init_keycodes:
    push rbp
    mov rbp, rsp
    sub rsp, 16

    mov rdi, [display_ptr]; mov rsi, '1'; call XKeysymToKeycode; movzx eax, al; mov [kc_1], rax
    mov rdi, [display_ptr]; mov rsi, '2'; call XKeysymToKeycode; movzx eax, al; mov [kc_2], rax
    mov rdi, [display_ptr]; mov rsi, '3'; call XKeysymToKeycode; movzx eax, al; mov [kc_3], rax
    mov rdi, [display_ptr]; mov rsi, '4'; call XKeysymToKeycode; movzx eax, al; mov [kc_4], rax
    mov rdi, [display_ptr]; mov rsi, '5'; call XKeysymToKeycode; movzx eax, al; mov [kc_5], rax
    mov rdi, [display_ptr]; mov rsi, '6'; call XKeysymToKeycode; movzx eax, al; mov [kc_6], rax
    mov rdi, [display_ptr]; mov rsi, '8'; call XKeysymToKeycode; movzx eax, al; mov [kc_8], rax
    mov rdi, [display_ptr]; mov rsi, '9'; call XKeysymToKeycode; movzx eax, al; mov [kc_9], rax
    mov rdi, [display_ptr]; mov rsi, 'b'; call XKeysymToKeycode; movzx eax, al; mov [kc_b], rax
    mov rdi, [display_ptr]; mov rsi, 'r'; call XKeysymToKeycode; movzx eax, al; mov [kc_r], rax
    mov rdi, [display_ptr]; mov rsi, 'p'; call XKeysymToKeycode; movzx eax, al; mov [kc_p], rax
    mov rdi, [display_ptr]; mov rsi, 'l'; call XKeysymToKeycode; movzx eax, al; mov [kc_l], rax

    # Teclas de modo mouse
    mov rdi, [display_ptr]; mov rsi, 'q'; call XKeysymToKeycode; movzx eax, al; mov [kc_m_q], rax
    mov rdi, [display_ptr]; mov rsi, 'w'; call XKeysymToKeycode; movzx eax, al; mov [kc_m_w], rax
    mov rdi, [display_ptr]; mov rsi, 'e'; call XKeysymToKeycode; movzx eax, al; mov [kc_m_e], rax
    mov rdi, [display_ptr]; mov rsi, 'a'; call XKeysymToKeycode; movzx eax, al; mov [kc_m_a], rax
    mov rdi, [display_ptr]; mov rsi, 's'; call XKeysymToKeycode; movzx eax, al; mov [kc_m_s], rax
    mov rdi, [display_ptr]; mov rsi, 'd'; call XKeysymToKeycode; movzx eax, al; mov [kc_m_d], rax
    mov rdi, [display_ptr]; mov rsi, 'z'; call XKeysymToKeycode; movzx eax, al; mov [kc_m_z], rax
    mov rdi, [display_ptr]; mov rsi, 'x'; call XKeysymToKeycode; movzx eax, al; mov [kc_m_x], rax
    mov rdi, [display_ptr]; mov rsi, 'c'; call XKeysymToKeycode; movzx eax, al; mov [kc_m_c], rax
    mov rdi, [display_ptr]; mov rsi, 'y'; call XKeysymToKeycode; movzx eax, al; mov [kc_m_y], rax
    mov rdi, [display_ptr]; mov rsi, 'f'; call XKeysymToKeycode; movzx eax, al; mov [kc_m_f], rax
    mov rdi, [display_ptr]; mov rsi, 'j'; call XKeysymToKeycode; movzx eax, al; mov [kc_m_j], rax
    mov rdi, [display_ptr]; mov rsi, 'u'; call XKeysymToKeycode; movzx eax, al; mov [kc_m_u], rax
    mov rdi, [display_ptr]; mov rsi, 'm'; call XKeysymToKeycode; movzx eax, al; mov [kc_m_m], rax
    mov rdi, [display_ptr]; mov rsi, 'g'; call XKeysymToKeycode; movzx eax, al; mov [kc_m_g], rax
    mov rdi, [display_ptr]; mov rsi, 'o'; call XKeysymToKeycode; movzx eax, al; mov [kc_m_o], rax

    # Teclas multimedia
    lea rdi, [sym_vol_down]; call XStringToKeysym; mov rdi, [display_ptr]; mov rsi, rax; call XKeysymToKeycode; movzx eax, al; mov [kc_vol_down], rax
    lea rdi, [sym_vol_up]; call XStringToKeysym; mov rdi, [display_ptr]; mov rsi, rax; call XKeysymToKeycode; movzx eax, al; mov [kc_vol_up], rax
    lea rdi, [sym_vol_mute]; call XStringToKeysym; mov rdi, [display_ptr]; mov rsi, rax; call XKeysymToKeycode; movzx eax, al; mov [kc_vol_mute], rax
    lea rdi, [sym_bright_down]; call XStringToKeysym; mov rdi, [display_ptr]; mov rsi, rax; call XKeysymToKeycode; movzx eax, al; mov [kc_bright_down], rax
    lea rdi, [sym_bright_up]; call XStringToKeysym; mov rdi, [display_ptr]; mov rsi, rax; call XKeysymToKeycode; movzx eax, al; mov [kc_bright_up], rax
    lea rdi, [sym_poweroff]; call XStringToKeysym; mov rdi, [display_ptr]; mov rsi, rax; call XKeysymToKeycode; movzx eax, al; mov [kc_poweroff], rax
    lea rdi, [sym_touchpad]; call XStringToKeysym; mov rdi, [display_ptr]; mov rsi, rax; call XKeysymToKeycode; movzx eax, al; mov [kc_touchpad], rax

    mov rsp, rbp
    pop rbp
    ret

register_base_hotkeys:
    push rbp
    mov rbp, rsp
    sub rsp, 16

    # Alt + 1 (Volver a KBD), Alt + 2 (Ir a MOUSE)
    mov rdi, [kc_1]; mov rsi, Mod1Mask; call grab_key
    mov rdi, [kc_1]; mov rsi, Mod1Mask | Mod2Mask; call grab_key
    mov rdi, [kc_2]; mov rsi, Mod1Mask; call grab_key
    mov rdi, [kc_2]; mov rsi, Mod1Mask | Mod2Mask; call grab_key

    # Alt + 3,4,5,6,8,9
    mov rdi, [kc_3]; mov rsi, Mod1Mask; call grab_key
    mov rdi, [kc_3]; mov rsi, Mod1Mask | Mod2Mask; call grab_key
    mov rdi, [kc_4]; mov rsi, Mod1Mask; call grab_key
    mov rdi, [kc_4]; mov rsi, Mod1Mask | Mod2Mask; call grab_key
    mov rdi, [kc_5]; mov rsi, Mod1Mask; call grab_key
    mov rdi, [kc_5]; mov rsi, Mod1Mask | Mod2Mask; call grab_key
    mov rdi, [kc_6]; mov rsi, Mod1Mask; call grab_key
    mov rdi, [kc_6]; mov rsi, Mod1Mask | Mod2Mask; call grab_key
    mov rdi, [kc_8]; mov rsi, Mod1Mask; call grab_key
    mov rdi, [kc_8]; mov rsi, Mod1Mask | Mod2Mask; call grab_key
    mov rdi, [kc_8]; mov rsi, Mod1Mask | ShiftMask; call grab_key
    mov rdi, [kc_8]; mov rsi, Mod1Mask | ShiftMask | Mod2Mask; call grab_key
    mov rdi, [kc_9]; mov rsi, Mod1Mask; call grab_key
    mov rdi, [kc_9]; mov rsi, Mod1Mask | Mod2Mask; call grab_key

    # Super / Mod4
    mov rdi, [kc_p]; mov rsi, Mod4Mask; call grab_key
    mov rdi, [kc_p]; mov rsi, Mod4Mask | Mod2Mask; call grab_key
    mov rdi, [kc_l]; mov rsi, Mod4Mask; call grab_key
    mov rdi, [kc_l]; mov rsi, Mod4Mask | Mod2Mask; call grab_key

    # Multimedia
    mov rdi, [kc_vol_down]; mov rsi, 0; call grab_key
    mov rdi, [kc_vol_up]; mov rsi, 0; call grab_key
    mov rdi, [kc_vol_mute]; mov rsi, 0; call grab_key
    mov rdi, [kc_bright_down]; mov rsi, 0; call grab_key
    mov rdi, [kc_bright_up]; mov rsi, 0; call grab_key
    mov rdi, [kc_poweroff]; mov rsi, 0; call grab_key
    mov rdi, [kc_touchpad]; mov rsi, 0; call grab_key

    # ASUS Keycodes
    mov rdi, 121; mov rsi, 0; call grab_key
    mov rdi, 122; mov rsi, 0; call grab_key
    mov rdi, 123; mov rsi, 0; call grab_key
    mov rdi, 232; mov rsi, 0; call grab_key
    mov rdi, 233; mov rsi, 0; call grab_key

    mov rsp, rbp
    pop rbp
    ret

register_mouse_triggers:
    push rbp
    mov rbp, rsp
    sub rsp, 16

    mov rdi, 1; mov rsi, ControlMask; call grab_mouse_button
    mov rdi, 1; mov rsi, ControlMask | Mod2Mask; call grab_mouse_button
    mov rdi, 1; mov rsi, ControlMask | ShiftMask; call grab_mouse_button
    mov rdi, 1; mov rsi, ControlMask | ShiftMask | Mod2Mask; call grab_mouse_button
    mov rdi, 1; mov rsi, Mod4Mask; call grab_mouse_button
    mov rdi, 1; mov rsi, Mod4Mask | Mod2Mask; call grab_mouse_button
    mov rdi, 1; mov rsi, Mod4Mask | ShiftMask; call grab_mouse_button
    mov rdi, 1; mov rsi, Mod4Mask | ShiftMask | Mod2Mask; call grab_mouse_button
    mov rdi, 1; mov rsi, Mod1Mask; call grab_mouse_button
    mov rdi, 1; mov rsi, Mod1Mask | Mod2Mask; call grab_mouse_button
    mov rdi, 1; mov rsi, Mod1Mask | ShiftMask; call grab_mouse_button
    mov rdi, 1; mov rsi, Mod1Mask | ShiftMask | Mod2Mask; call grab_mouse_button

    mov rsp, rbp
    pop rbp
    ret

.err_exit:
    mov rsp, rbp
    pop rbp
    mov rdi, 1
    mov rax, 60
    syscall
