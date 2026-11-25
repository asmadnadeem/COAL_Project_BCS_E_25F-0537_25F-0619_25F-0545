; module 6, 7, 8, 9, 10: interrupts, timer, camera, physics and collisions

; keyboard interrupt service routine (int 9)
kbisr:
    push ax
    push bx
    push ds

    push cs
    pop ds

    in al, 0x60
    cmp al, 0xe0
    jne .proc
    mov byte [e0_flag], 1
    jmp .exit

.proc:
    mov byte [e0_flag], 0
    mov bl, al
    and bl, 0x7f
    xor bh, bh
    test al, 0x80
    jnz .rel
    mov byte [key_state + bx], 1
    jmp .exit
.rel:
    mov byte [key_state + bx], 0

.exit:
    mov al, 0x20
    out 0x20, al
    pop ds
    pop bx
    pop ax
    iret

; timer interrupt service routine (int 8)
timer:
    push ax
    inc word [cs:tickcount]
    pop ax
    jmp far [cs:oldtimer]

; subroutine to hook int 8 and int 9 in IVT
hook_ints:
    push es
    push ax

    xor ax, ax
    mov es, ax

    mov ax, [es:9*4]
    mov [oldkb], ax
    mov ax, [es:9*4+2]
    mov [oldkb+2], ax

    mov ax, [es:8*4]
    mov [oldtimer], ax
    mov ax, [es:8*4+2]
    mov [oldtimer+2], ax

    cli
    mov word [es:9*4], kbisr
    mov [es:9*4+2], cs
    mov word [es:8*4], timer
    mov [es:8*4+2], cs
    sti

    pop ax
    pop es
    ret

; subroutine to restore original int 8 and int 9 vectors
unhook_ints:
    push es
    push ax
    push bx

    xor ax, ax
    mov es, ax

    cli
    mov ax, [oldkb]
    mov bx, [oldkb+2]
    mov [es:9*4], ax
    mov [es:9*4+2], bx

    mov ax, [oldtimer]
    mov bx, [oldtimer+2]
    mov [es:8*4], ax
    mov [es:8*4+2], bx
    sti

    pop bx
    pop ax
    pop es
    ret

; subroutine to wait for next timer tick
waitframe:
    push ax
.wait:
    mov ax, [tickcount]
    cmp ax, [last_tick]
    je .wait
    mov [last_tick], ax
    pop ax
    ret
