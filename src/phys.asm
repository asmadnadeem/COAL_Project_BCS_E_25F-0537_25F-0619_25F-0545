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

; subroutine to update camera_x when mario passes screen x = 160
updatecam:
    push ax
    push bx

    mov ax, [mario_x]
    mov bx, ax
    sub bx, [camera_x]
    cmp bx, 160
    jle .done

    sub ax, 160
    cmp ax, MAX_CAM
    jle .chk
    mov ax, MAX_CAM
.chk:
    cmp ax, [camera_x]
    jle .done
    mov [camera_x], ax

.done:
    pop bx
    pop ax
    ret

; helper to check if tile in AL is solid (1..10)
issolid:
    cmp al, TILE_GROUND
    jl .no
    cmp al, TILE_STAIR
    jg .no
    or al, al
    ret
.no:
    cmp al, al
    ret

; subroutine to update mario 8.8 fixed-point physics and tile collisions
movemario:
    push ax
    push bx
    push cx
    push dx

    mov ax, [mario_y]
    mov [mario_prev_y], ax

    mov cx, MAX_WALK
    cmp byte [key_state + KEY_LSHIFT], 1
    jne .chk_l
    mov cx, MAX_RUN

.chk_l:
    cmp byte [key_state + KEY_LEFT], 1
    jne .chk_r
    mov byte [mario_dir], 1
    mov ax, [mario_vx]
    sub ax, WALK_ACCEL
    mov bx, cx
    neg bx
    cmp ax, bx
    jge .set_vxl
    mov ax, bx
.set_vxl:
    mov [mario_vx], ax
    jmp .h_done

.chk_r:
    cmp byte [key_state + KEY_RIGHT], 1
    jne .fric
    mov byte [mario_dir], 0
    mov ax, [mario_vx]
    add ax, WALK_ACCEL
    cmp ax, cx
    jle .set_vxr
    mov ax, cx
.set_vxr:
    mov [mario_vx], ax
    jmp .h_done

.fric:
    mov ax, [mario_vx]
    cmp ax, 0
    je .h_done
    jg .fpos
    add ax, FRICTION
    cmp ax, 0
    jle .set_f
    xor ax, ax
    jmp .set_f
.fpos:
    sub ax, FRICTION
    cmp ax, 0
    jge .set_f
    xor ax, ax
.set_f:
    mov [mario_vx], ax

.h_done:
    cmp byte [key_state + KEY_SPACE], 1
    jne .var_jmp
    cmp byte [on_ground], 1
    jne .var_jmp
    mov word [mario_vy], JUMP_START
    mov byte [on_ground], 0
    call sound_jump

.var_jmp:
    cmp byte [key_state + KEY_SPACE], 0
    jne .grav
    mov ax, [mario_vy]
    cmp ax, JUMP_CUTOFF
    jge .grav
    mov word [mario_vy], JUMP_CUTOFF

.grav:
    mov ax, [mario_vy]
    add ax, GRAVITY
    cmp ax, MAX_FALL
    jle .set_vy
    mov ax, MAX_FALL
.set_vy:
    mov [mario_vy], ax

    ; apply 8.8 fixed point horizontal velocity to mario_x
    mov ax, [mario_vx]
    add [mario_xf], al
    mov al, ah
    cbw
    adc [mario_x], ax

    ; clamp left camera edge and right world edge
    mov ax, [mario_x]
    cmp ax, [camera_x]
    jge .chk_rmax
    mov ax, [camera_x]
    mov [mario_x], ax
    mov word [mario_vx], 0
.chk_rmax:
    cmp word [mario_x], 944
    jle .wall_chk
    mov word [mario_x], 944
    mov word [mario_vx], 0

.wall_chk:
    mov bx, [mario_x]
    mov cx, [mario_y]
    mov dx, 12
    cmp byte [mario_form], 1
    jne .do_wchk
    mov dx, 28

.do_wchk:
    cmp word [mario_vx], 0
    je .vert_move
    jg .w_right

    mov ax, bx
    add ax, 2
    push ax
    mov ax, cx
    add ax, 4
    push ax
    call gettile
    call issolid
    jnz .hit_lw

    mov ax, bx
    add ax, 2
    push ax
    mov ax, cx
    add ax, dx
    push ax
    call gettile
    call issolid
    jz .vert_move

.hit_lw:
    mov ax, bx
    add ax, 2
    and ax, 0xfff0
    add ax, 14
    mov [mario_x], ax
    mov word [mario_vx], 0
    jmp .vert_move

.w_right:
    mov ax, bx
    add ax, 13
    push ax
    mov ax, cx
    add ax, 4
    push ax
    call gettile
    call issolid
    jnz .hit_rw

    mov ax, bx
    add ax, 13
    push ax
    mov ax, cx
    add ax, dx
    push ax
    call gettile
    call issolid
    jz .vert_move

.hit_rw:
    mov ax, bx
    add ax, 13
    and ax, 0xfff0
    sub ax, 14
    mov [mario_x], ax
    mov word [mario_vx], 0

.vert_move:
    ; apply 8.8 fixed point vertical velocity to mario_y
    mov ax, [mario_vy]
    add [mario_yf], al
    mov al, ah
    cbw
    adc [mario_y], ax

    mov bx, [mario_x]
    mov cx, [mario_y]

    cmp word [mario_vy], 0
    jl .head_chk

    mov dx, cx
    add dx, 16
    cmp byte [mario_form], 1
    jne .feet_chk
    add dx, 16
.feet_chk:
    cmp dx, 192
    jge .air

    mov ax, bx
    add ax, 4
    push ax
    push dx
    call gettile
    call issolid
    jnz .land

    mov ax, bx
    add ax, 11
    push ax
    push dx
    call gettile
    call issolid
    jnz .land

.air:
    mov byte [on_ground], 0
    jmp .pose

.land:
    and dx, 0xfff0
    sub dx, 16
    cmp byte [mario_form], 1
    jne .set_ly
    sub dx, 16
.set_ly:
    mov [mario_y], dx
    mov word [mario_vy], 0
    mov byte [on_ground], 1
    mov word [stomp_chain], 0
    jmp .pose

.head_chk:
    mov ax, bx
    add ax, 8
    push ax
    push cx
    call gettile
    call issolid
    jz .pose

    mov ax, bx
    add ax, 8
    push ax
    push cx
    call hitblock

    mov ax, cx
    and ax, 0xfff0
    add ax, 16
    mov [mario_y], ax
    mov word [mario_vy], 0

.pose:
    cmp byte [on_ground], 0
    jne .gpose
    mov byte [mario_pose], 2
    jmp .done
.gpose:
    cmp word [mario_vx], 0
    je .spose
    mov byte [mario_pose], 1
    jmp .done
.spose:
    mov byte [mario_pose], 0

.done:
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; subroutine to check rectangle overlap between mario and 16x16 entity
; inputs on stack: [bp+6]=ex, [bp+4]=ey; output: AL=1 if overlap, 0 otherwise
check_overlap:
    push bp
    mov bp, sp
    push bx
    push cx
    push dx

    mov bx, [mario_x]
    mov cx, [mario_y]
    mov dx, 16
    cmp byte [mario_form], 1
    jne .tx
    mov dx, 32

.tx:
    mov ax, bx
    add ax, 14
    cmp ax, [bp+6]
    jle .no
    mov ax, [bp+6]
    add ax, 14
    cmp ax, bx
    jle .no

    mov ax, cx
    add ax, dx
    cmp ax, [bp+4]
    jle .no
    mov ax, [bp+4]
    add ax, 16
    cmp ax, cx
    jle .no

    mov al, 1
    jmp .exit
.no:
    xor al, al
.exit:
    pop dx
    pop cx
    pop bx
    pop bp
    ret 4
; verified jump cutoff and left camera wall clamping
