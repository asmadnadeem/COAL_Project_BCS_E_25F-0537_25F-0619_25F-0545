; module 11, 12, 13, 14, 15: enemies, blocks, score, hud and states

; subroutine to add points to 32-bit score using add/adc
; inputs on stack: [bp+4]=points
addscore:
    push bp
    mov bp, sp
    push ax

    mov ax, [bp+4]
    add [score_lo], ax
    adc word [score_hi], 0

    cmp word [score_hi], 0x000f
    jl .done
    jg .clamp
    cmp word [score_lo], 0x423f
    jbe .done
.clamp:
    mov word [score_hi], 0x000f
    mov word [score_lo], 0x423f
.done:
    pop ax
    pop bp
    ret 2

; subroutine to add 1 coin (+200 pts, 1-up at 100 coins)
addcoin:
    push ax
    push 200
    call addscore
    inc byte [coins]
    cmp byte [coins], 100
    jl .done
    mov byte [coins], 0
    cmp byte [lives], 99
    jge .done
    inc byte [lives]
.done:
    pop ax
    ret

; subroutine to print 16-bit number with N digits using division by 10
; inputs on stack: [bp+12]=x, [bp+10]=y, [bp+8]=num, [bp+6]=digits, [bp+4]=col
printnum:
    push bp
    mov bp, sp
    push ax
    push bx
    push cx
    push dx

    mov ax, [bp+8]
    mov cx, [bp+6]
    mov bx, 10
.nextdigit:
    xor dx, dx
    div bx
    add dl, 0x30
    push dx
    loop .nextdigit

    mov cx, [bp+6]
    mov bx, [bp+12]
.nextpos:
    pop ax
    push bx
    push word [bp+10]
    push ax
    push word [bp+4]
    call printchar
    add bx, 8
    loop .nextpos

    pop dx
    pop cx
    pop bx
    pop ax
    pop bp
    ret 10

; subroutine to print 6-digit 32-bit score
; inputs on stack: [bp+8]=x, [bp+6]=y, [bp+4]=color
printscore:
    push bp
    mov bp, sp
    push ax
    push bx
    push dx

    mov ax, [score_lo]
    mov dx, [score_hi]
    mov bx, 1000
    div bx

    push word [bp+8]
    push word [bp+6]
    push ax
    push 3
    push word [bp+4]
    call printnum

    mov ax, [bp+8]
    add ax, 24
    push ax
    push word [bp+6]
    push dx
    push 3
    push word [bp+4]
    call printnum

    pop dx
    pop bx
    pop ax
    pop bp
    ret 6

; subroutine to draw top hud bar
drawhud:
    push ax

    push 8
    push 0
    push str_hud
    push COL_ORANGE
    call printstr

    push 8
    push 8
    push COL_WHITE
    call printscore

    push 72
    push 8
    push 'x'
    push COL_WHITE
    call printchar

    push 80
    push 8
    xor ah, ah
    mov al, [coins]
    push ax
    push 2
    push COL_WHITE
    call printnum

    push 128
    push 8
    push str_world
    push COL_WHITE
    call printstr

    push 176
    push 8
    push word [game_time]
    push 3
    push COL_WHITE
    call printnum

    push 224
    push 8
    push 'x'
    push COL_WHITE
    call printchar

    push 232
    push 8
    xor ah, ah
    mov al, [lives]
    push ax
    push 2
    push COL_WHITE
    call printnum

    push 280
    push 8
    push spr_heart1
    push 0
    call drawsprite

    push 292
    push 8
    cmp byte [mario_hp], 2
    je .hfull
    push spr_heart0
    jmp .dh2
.hfull:
    push spr_heart1
.dh2:
    push 0
    call drawsprite

    pop ax
    ret

; subroutine to handle block hit from below
; inputs on stack: [bp+6]=px, [bp+4]=py
hitblock:
    push bp
    mov bp, sp
    push ax
    push bx
    push cx

    mov bx, [bp+6]
    mov cx, [bp+4]
    push bx
    push cx
    call gettile

    cmp al, TILE_BRICK
    jne .qcoin
    cmp byte [mario_hp], 2
    jne .done
    push bx
    push cx
    push TILE_SKY
    call settile
    push 50
    call addscore
    jmp .done

.qcoin:
    cmp al, TILE_Q_COIN
    jne .qmush
    push bx
    push cx
    push TILE_EMPTY
    call settile
    call addcoin
    jmp .done

.qmush:
    cmp al, TILE_Q_MUSH
    jne .done
    push bx
    push cx
    push TILE_EMPTY
    call settile
    mov byte [mush_active], 1
    and bx, 0xfff0
    mov [mush_x], bx
    and cx, 0xfff0
    sub cx, 16
    mov [mush_y], cx
    mov byte [mush_dir], 1

.done:
    pop cx
    pop bx
    pop ax
    pop bp
    ret 4

; subroutine to check map coins and flagpole contact
check_items:
    push ax
    push bx
    push cx

    mov bx, [mario_x]
    add bx, 8
    mov cx, [mario_y]
    add cx, 8

    push bx
    push cx
    call gettile
    cmp al, TILE_COIN
    jne .f1
    push bx
    push cx
    push TILE_SKY
    call settile
    call addcoin
.f1:
    cmp al, TILE_FLAG
    je .win

    mov cx, [mario_y]
    add cx, 14
    cmp byte [mario_form], 1
    jne .low
    add cx, 14
.low:
    push bx
    push cx
    call gettile
    cmp al, TILE_COIN
    jne .f2
    push bx
    push cx
    push TILE_SKY
    call settile
    call addcoin
.f2:
    cmp al, TILE_FLAG
    jne .done

.win:
    mov cx, [mario_y]
    add cx, 15
    cmp byte [mario_form], 1
    jne .row
    add cx, 16
.row:
    shr cx, 4
    cmp cx, 3
    jle .p5000
    cmp cx, 4
    je .p2000
    cmp cx, 5
    je .p800
    cmp cx, 7
    jle .p400
    push 100
    jmp .addf
.p5000:
    push 5000
    jmp .addf
.p2000:
    push 2000
    jmp .addf
.p800:
    push 800
    jmp .addf
.p400:
    push 400
.addf:
    call addscore
    mov byte [game_state], ST_WINSEQ
    mov word [state_timer], 55

.done:
    pop cx
    pop bx
    pop ax
    ret

; subroutine to update mushroom movement and collection
updatemush:
    cmp byte [mush_active], 1
    je .act
    ret
.act:
    push ax
    push bx
    push cx

    mov ax, [mush_x]
    cmp byte [mush_dir], 1
    je .mr
    dec ax
    jmp .setx
.mr:
    inc ax
.setx:
    mov [mush_x], ax

    mov bx, [camera_x]
    sub bx, 32
    cmp ax, bx
    jl .rem

    mov cx, [mush_y]
    add cx, 8
    mov bx, ax
    cmp byte [mush_dir], 1
    jne .wchk
    add bx, 15
.wchk:
    push bx
    push cx
    call gettile
    call issolid
    jz .mgrav
    xor byte [mush_dir], 1

.mgrav:
    mov ax, [mush_y]
    add ax, 2
    mov [mush_y], ax
    cmp ax, 192
    jge .rem

    mov bx, [mush_x]
    add bx, 8
    mov cx, ax
    add cx, 16
    push bx
    push cx
    call gettile
    call issolid
    jz .mcol
    and cx, 0xfff0
    sub cx, 16
    mov [mush_y], cx

.mcol:
    push word [mush_x]
    push word [mush_y]
    call check_overlap
    cmp al, 0
    je .done

    mov byte [mush_active], 0
    push 1000
    call addscore
    cmp byte [mario_hp], 1
    jne .done
    mov byte [mario_hp], 2
    mov byte [mario_form], 1
    sub word [mario_y], 16
    jmp .done

.rem:
    mov byte [mush_active], 0
.done:
    pop cx
    pop bx
    pop ax
    ret

; subroutine to award stomp chain points
stomp_pts:
    push ax
    push bx
    mov bx, [stomp_chain]
    cmp bx, 10
    jge .life
    shl bx, 1
    mov ax, [stomp_table + bx]
    push ax
    call addscore
    jmp .inc
.life:
    cmp byte [lives], 99
    jge .inc
    inc byte [lives]
.inc:
    inc word [stomp_chain]
    pop bx
    pop ax
    ret

; subroutine to hurt mario on side enemy contact
hurtmario:
    cmp byte [invuln_timer], 0
    jg .done
    cmp byte [mario_hp], 2
    jne .die
    mov byte [mario_hp], 1
    mov byte [mario_form], 0
    add word [mario_y], 16
    mov byte [invuln_timer], 36
    ret
.die:
    mov byte [pit_death], 0
    call start_death
.done:
    ret

; subroutine to update enemies and shell logic
updateenemies:
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    mov si, enemies
    mov cx, MAX_ENEMIES

.eloop:
    push cx
    mov al, [si + 1]
    cmp al, 0
    jne .chk_wait
    jmp .next_e

.chk_wait:
    cmp al, 1
    jne .chk_flat
    mov ax, [si + 2]
    mov bx, [camera_x]
    add bx, 336
    cmp ax, bx
    jle .activate
    jmp .next_e
.activate:
    mov byte [si + 1], 2

.chk_flat:
    cmp byte [si + 1], 3
    jne .chk_tmr
    dec byte [si + 7]
    jnz .skip_flat
    mov byte [si + 1], 0
.skip_flat:
    jmp .next_e

.chk_tmr:
    cmp byte [si + 7], 0
    je .emove
    dec byte [si + 7]

.emove:
    mov al, [si + 1]
    cmp al, 4
    je .egrav
    mov dx, 1
    cmp al, 5
    jne .set_dx
    mov dx, 3
.set_dx:
    mov ax, [si + 2]
    cmp byte [si + 6], 1
    je .eright
    sub ax, dx
    jmp .esetx
.eright:
    add ax, dx
.esetx:
    mov [si + 2], ax

    mov bx, [camera_x]
    sub bx, 32
    cmp ax, bx
    jge .ewall
    jmp .kill_e

.ewall:
    mov bx, ax
    cmp byte [si + 6], 1
    jne .ewl
    add bx, 15
.ewl:
    mov dx, [si + 4]
    add dx, 8
    push bx
    push dx
    call gettile
    call issolid
    jz .egrav
    xor byte [si + 6], 1

.egrav:
    mov ax, [si + 4]
    add ax, 2
    mov [si + 4], ax
    cmp ax, 192
    jl .efloor
    jmp .kill_e

.efloor:
    mov bx, [si + 2]
    add bx, 8
    mov dx, ax
    add dx, 16
    push bx
    push dx
    call gettile
    call issolid
    jz .shell_hit

    and dx, 0xfff0
    sub dx, 16
    mov [si + 4], dx

    ; koopa turns at platform edges
    cmp byte [si + 0], 2
    jne .shell_hit
    cmp byte [si + 1], 2
    jne .shell_hit
    mov bx, [si + 2]
    cmp byte [si + 6], 1
    jne .edgel
    add bx, 16
    jmp .tedge
.edgel:
    dec bx
.tedge:
    mov dx, [si + 4]
    add dx, 18
    push bx
    push dx
    call gettile
    call issolid
    jnz .shell_hit
    xor byte [si + 6], 1

.shell_hit:
    cmp byte [si + 1], 5
    jne .m_col
    mov di, enemies
    mov cx, MAX_ENEMIES
.sloop:
    cmp di, si
    je .next_s
    cmp byte [di + 1], 2
    jne .next_s
    mov ax, [si + 2]
    sub ax, [di + 2]
    cmp ax, -12
    jl .next_s
    cmp ax, 12
    jg .next_s
    mov byte [di + 1], 0
    push 500
    call addscore
.next_s:
    add di, ENEMY_SIZE
    loop .sloop

.m_col:
    push word [si + 2]
    push word [si + 4]
    call check_overlap
    cmp al, 0
    je .next_e

    cmp byte [si + 1], 4
    jne .tstomp
    mov byte [si + 1], 5
    mov byte [si + 7], 8
    push 400
    call addscore
    mov ax, [mario_x]
    cmp ax, [si + 2]
    jg .kickl
    mov byte [si + 6], 1
    jmp .next_e
.kickl:
    mov byte [si + 6], 0
    jmp .next_e

.tstomp:
    cmp word [mario_vy], 0
    jle .side
    mov ax, [mario_prev_y]
    add ax, 16
    cmp byte [mario_form], 1
    jne .cstomp
    add ax, 16
.cstomp:
    mov bx, [si + 4]
    add bx, 10
    cmp ax, bx
    jg .side

    call stomp_pts
    mov word [mario_vy], STOMP_BOUNCE
    cmp byte [key_state + KEY_SPACE], 1
    jne .set_st
    mov word [mario_vy], JUMP_START
.set_st:
    cmp byte [si + 0], 1
    jne .skoopa
    mov byte [si + 1], 3
    mov byte [si + 7], 18
    jmp .next_e
.skoopa:
    mov byte [si + 1], 4
    mov byte [si + 7], 8
    jmp .next_e

.side:
    cmp byte [si + 7], 0
    jg .next_e
    call hurtmario
    jmp .next_e

.kill_e:
    mov byte [si + 1], 0

.next_e:
    pop cx
    add si, ENEMY_SIZE
    dec cx
    jz .edone
    jmp .eloop

.edone:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; subroutine to draw mushroom, enemies and mario
drawall:
    push ax
    push bx
    push cx
    push dx
    push si

    cmp byte [mush_active], 1
    jne .denemies
    mov ax, [mush_x]
    sub ax, [camera_x]
    push ax
    push word [mush_y]
    push spr_mush
    push 0
    call drawsprite

.denemies:
    mov si, enemies
    mov cx, MAX_ENEMIES
.dloop:
    mov al, [si + 1]
    cmp al, 2
    jl .next_d

    mov bx, [si + 2]
    sub bx, [camera_x]
    cmp bx, -16
    jle .next_d
    cmp bx, 320
    jge .next_d

    push bx
    push word [si + 4]
    cmp al, 3
    jne .dshell
    push spr_goomba_f
    jmp .dcall
.dshell:
    cmp al, 4
    jge .ushell
    cmp byte [si + 0], 1
    jne .ukoopa
    push spr_goomba
    jmp .dcall
.ukoopa:
    push spr_koopa
    jmp .dcall
.ushell:
    push spr_shell
.dcall:
    xor ax, ax
    mov al, [si + 6]
    push ax
    call drawsprite

.next_d:
    add si, ENEMY_SIZE
    loop .dloop

    cmp byte [invuln_timer], 0
    je .dmario
    test word [frame_num], 1
    jnz .done

.dmario:
    mov ax, [mario_x]
    sub ax, [camera_x]
    push ax
    push word [mario_y]
    cmp byte [mario_pose], 0
    je .pstand
    push spr_mario_r
    jmp .mflg
.pstand:
    push spr_mario_s
.mflg:
    xor ax, ax
    mov al, [mario_dir]
    cmp byte [mario_form], 1
    jne .mcall
    or al, 2
.mcall:
    push ax
    call drawsprite

.done:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; subroutine to reset level state for a life
resetlevel:
    push es
    push cx
    push si
    push di

    call resetmap

    cld
    push ds
    pop es
    mov si, orig_enemies
    mov di, enemies
    mov cx, 128
    rep movsb

    mov word [camera_x], 0
    mov word [game_time], 300
    mov byte [sec_ticks], 0
    mov word [mario_x], 32
    mov byte [mario_xf], 0
    mov word [mario_y], 144
    mov byte [mario_yf], 0
    mov word [mario_vx], 0
    mov word [mario_vy], 0
    mov byte [on_ground], 1
    mov byte [mario_form], 0
    mov byte [mario_hp], 1
    mov byte [invuln_timer], 0
    mov word [stomp_chain], 0
    mov byte [mario_dir], 0
    mov byte [mario_pose], 0
    mov byte [mush_active], 0

    pop di
    pop si
    pop cx
    pop es
    ret

; subroutine to start a brand new game
newgame:
    mov word [score_lo], 0
    mov word [score_hi], 0
    mov byte [coins], 0
    mov byte [lives], 3
    call resetlevel
    ret

; subroutine to trigger dying state
start_death:
    mov byte [game_state], ST_DIE
    mov word [state_timer], 28
    mov byte [mario_pose], 2
    cmp byte [pit_death], 1
    je .pit
    mov word [mario_vy], 0xfc00
    ret
.pit:
    mov word [mario_vy], 0x0200
    ret

; state 0: title screen
state_title:
    call clrscr

    push 0
    push 0
    push 320
    push 16
    push COL_BROWN
    call fillrect
    push 0
    push 168
    push 320
    push 32
    push COL_BROWN
    call fillrect

    push 116
    push 40
    push str_title1
    push COL_RED
    call printstr

    push 116
    push 56
    push str_title2
    push COL_WHITE
    call printstr

    push 100
    push 84
    push 120
    push 44
    push COL_BLACK
    call fillrect

    push 124
    push 94
    push str_start
    push COL_YELLOW
    call printstr

    push 124
    push 110
    push str_exit
    push COL_WHITE
    call printstr

    push 110
    cmp byte [menu_sel], 0
    jne .selex
    push 94
    jmp .darr
.selex:
    push 110
.darr:
    push str_arrow
    push COL_YELLOW
    call printstr

    push 48
    push 152
    push spr_mario_s
    push 0
    call drawsprite

    push 256
    push 152
    push spr_goomba
    push 0
    call drawsprite

    push 44
    push 180
    push str_group
    push COL_WHITE
    call printstr

    cmp byte [key_state + KEY_UP], 1
    jne .cdown
    mov byte [key_state + KEY_UP], 0
    mov byte [menu_sel], 0
.cdown:
    cmp byte [key_state + KEY_DOWN], 1
    jne .cesc
    mov byte [key_state + KEY_DOWN], 0
    mov byte [menu_sel], 1
.cesc:
    cmp byte [key_state + KEY_ESC], 1
    jne .cent
    mov byte [key_state + KEY_ESC], 0
    mov byte [game_state], ST_EXIT
    ret
.cent:
    cmp byte [key_state + KEY_ENTER], 1
    jne .done
    mov byte [key_state + KEY_ENTER], 0
    cmp byte [menu_sel], 1
    je .quit
    call newgame
    mov byte [game_state], ST_PLAY
    ret
.quit:
    mov byte [game_state], ST_EXIT
.done:
    ret

; state 1: playing state
state_play:
    cmp byte [key_state + KEY_P], 1
    jne .cesc
    mov byte [key_state + KEY_P], 0
    mov byte [game_state], ST_PAUSE
    ret
.cesc:
    cmp byte [key_state + KEY_ESC], 1
    jne .cdbg_t
    mov byte [key_state + KEY_ESC], 0
    mov byte [game_state], ST_TITLE
    ret
.cdbg_t:
    cmp byte [key_state + KEY_T], 1
    jne .cdbg_c
    mov byte [key_state + KEY_T], 0
    mov word [game_time], 5
.cdbg_c:
    cmp byte [key_state + KEY_C], 1
    jne .upd
    mov byte [key_state + KEY_C], 0
    mov byte [coins], 99

.upd:
    call movemario
    call updatemush
    call updateenemies
    call check_items
    cmp byte [game_state], ST_PLAY
    jne .draw

    cmp byte [invuln_timer], 0
    je .clk
    dec byte [invuln_timer]
.clk:
    inc byte [sec_ticks]
    cmp byte [sec_ticks], 18
    jl .chk_pit
    mov byte [sec_ticks], 0
    cmp word [game_time], 0
    je .chk_pit
    dec word [game_time]

.chk_pit:
    cmp word [mario_y], 192
    jl .chk_tm
    mov byte [pit_death], 1
    call start_death
    jmp .draw
.chk_tm:
    cmp word [game_time], 0
    jne .cam
    mov byte [pit_death], 0
    call start_death
    jmp .draw

.cam:
    call updatecam

.draw:
    call clrscr
    call drawmap
    call drawall
    call drawhud
    ret

; state 2: paused state
state_pause:
    call clrscr
    call drawmap
    call drawall
    call drawhud

    push 88
    push 76
    push 144
    push 40
    push COL_BLACK
    call fillrect

    push 136
    push 84
    push str_paused
    push COL_YELLOW
    call printstr

    push 92
    push 100
    push str_resume
    push COL_WHITE
    call printstr

    cmp byte [key_state + KEY_P], 1
    jne .cesc
    mov byte [key_state + KEY_P], 0
    mov byte [game_state], ST_PLAY
    ret
.cesc:
    cmp byte [key_state + KEY_ESC], 1
    jne .done
    mov byte [key_state + KEY_ESC], 0
    mov byte [game_state], ST_TITLE
.done:
    ret

; state 3: dying animation state
state_die:
    mov ax, [mario_vy]
    add [mario_yf], al
    mov al, ah
    cbw
    adc [mario_y], ax
    add word [mario_vy], GRAVITY

    call clrscr
    call drawmap
    call drawall
    call drawhud

    dec word [state_timer]
    jnz .done

    dec byte [lives]
    cmp byte [lives], 0
    je .gover
    mov byte [game_state], ST_LIFELOST
    mov word [state_timer], 36
    ret
.gover:
    mov byte [game_state], ST_GAMEOVER
.done:
    ret

; state 4: life lost screen
state_lifelost:
    push 0
    push 0
    push 320
    push 200
    push COL_BLACK
    call fillrect
    call drawhud

    push 124
    push 64
    push str_w11
    push COL_WHITE
    call printstr

    push 124
    push 92
    push spr_mario_s
    push 0
    call drawsprite

    push 156
    push 96
    push 'x'
    push COL_WHITE
    call printchar

    push 172
    push 96
    xor ah, ah
    mov al, [lives]
    push ax
    push 2
    push COL_WHITE
    call printnum

    push 120
    push 132
    push str_livesleft
    push COL_ORANGE
    call printstr

    dec word [state_timer]
    jnz .done
    call resetlevel
    mov byte [game_state], ST_PLAY
.done:
    ret

; state 5: flagpole win sequence
state_winseq:
    cmp word [state_timer], 28
    jg .slide
    inc word [mario_x]
    mov byte [mario_pose], 1
    jmp .draw
.slide:
    mov bx, 128
    cmp byte [mario_form], 1
    jne .cbase
    mov bx, 112
.cbase:
    cmp [mario_y], bx
    jge .draw
    add word [mario_y], 2
.draw:
    call clrscr
    call drawmap
    call drawall
    call drawhud

    dec word [state_timer]
    jnz .done

    mov ax, [game_time]
    mov bx, 50
    mul bx
    mov [time_bonus], ax
    push ax
    call addscore
    mov byte [game_state], ST_LVLCOMP
.done:
    ret

; state 6: level complete screen
state_lvlcomp:
    push 0
    push 0
    push 320
    push 200
    push COL_BLACK
    call fillrect

    push 100
    push 40
    push str_lvlcomp
    push COL_YELLOW
    call printstr

    push 72
    push 68
    push str_lcoins
    push COL_WHITE
    call printstr
    push 184
    push 68
    xor ah, ah
    mov al, [coins]
    push ax
    push 2
    push COL_WHITE
    call printnum

    push 72
    push 88
    push str_ltleft
    push COL_WHITE
    call printstr
    push 184
    push 88
    push word [game_time]
    push 3
    push COL_WHITE
    call printnum

    push 72
    push 108
    push str_ltbon
    push COL_WHITE
    call printstr
    push 184
    push 108
    push word [time_bonus]
    push 5
    push COL_WHITE
    call printnum

    push 72
    push 128
    push str_lfinal
    push COL_YELLOW
    call printstr
    push 184
    push 128
    push COL_YELLOW
    call printscore

    push 68
    push 160
    push str_enter
    push COL_LGREEN
    call printstr

    cmp byte [key_state + KEY_ENTER], 1
    jne .done
    mov byte [key_state + KEY_ENTER], 0
    mov byte [game_state], ST_TITLE
.done:
    ret

; state 7: game over screen
state_gameover:
    push 0
    push 0
    push 320
    push 200
    push COL_BLACK
    call fillrect

    push 124
    push 68
    push str_gameover
    push COL_RED
    call printstr

    push 88
    push 104
    push str_lfinal
    push COL_WHITE
    call printstr
    push 184
    push 104
    push COL_YELLOW
    call printscore

    push 68
    push 140
    push str_enter
    push COL_LGREEN
    call printstr

    cmp byte [key_state + KEY_ENTER], 1
    jne .done
    mov byte [key_state + KEY_ENTER], 0
    mov byte [game_state], ST_TITLE
.done:
    ret
