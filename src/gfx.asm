; module 2, 3, 4, 5: graphics, tiles, sprites and frame buffer

; subroutine to clear off-screen buffer using rep stosw
; inputs: none, outputs: none, preserves all registers
clrscr:
    push es
    push ax
    push cx
    push di

    cld
    mov es, [buf_seg]
    xor di, di

    xor ax, ax
    mov cx, 2560
    rep stosw

    mov ah, COL_SKY
    mov al, COL_SKY
    mov cx, 28160
    rep stosw

    xor ax, ax
    mov cx, 1280
    rep stosw

    pop di
    pop cx
    pop ax
    pop es
    ret

; subroutine to copy off-screen buffer to 0xa000 video memory
; inputs: none, outputs: none, preserves all registers
copybuf:
    push ds
    push es
    push ax
    push cx
    push si
    push di

    cld
    mov ds, [buf_seg]
    mov ax, 0xa000
    mov es, ax
    xor si, si
    xor di, di
    mov cx, 32000
    rep movsw

    pop di
    pop si
    pop cx
    pop ax
    pop es
    pop ds
    ret

; subroutine to put pixel at (x, y)
; inputs on stack: [bp+8]=x, [bp+6]=y, [bp+4]=color
putpixel:
    push bp
    mov bp, sp
    push es
    push ax
    push bx
    push di

    mov ax, [bp+8]
    cmp ax, 0
    jl .exit
    cmp ax, 320
    jge .exit

    mov bx, [bp+6]
    cmp bx, 0
    jl .exit
    cmp bx, 200
    jge .exit

    mov di, bx
    shl di, 8
    shl bx, 6
    add di, bx
    add di, ax

    mov es, [buf_seg]
    mov al, [bp+4]
    mov [es:di], al

.exit:
    pop di
    pop bx
    pop ax
    pop es
    pop bp
    ret 6

; subroutine to fill rectangle
; inputs on stack: [bp+12]=x, [bp+10]=y, [bp+8]=w, [bp+6]=h, [bp+4]=color
fillrect:
    push bp
    mov bp, sp
    push ax
    push bx
    push cx
    push dx

    mov dx, [bp+10]
    mov cx, [bp+6]
    cmp cx, 0
    jle .exit

.rloop:
    push cx
    mov bx, [bp+12]
    mov cx, [bp+8]
.cloop:
    push bx
    push dx
    push word [bp+4]
    call putpixel
    inc bx
    loop .cloop

    pop cx
    inc dx
    loop .rloop

.exit:
    pop dx
    pop cx
    pop bx
    pop ax
    pop bp
    ret 10

; subroutine to print 8x8 rom character
; inputs on stack: [bp+10]=x, [bp+8]=y, [bp+6]=char, [bp+4]=color
printchar:
    push bp
    mov bp, sp
    push ds
    push ax
    push bx
    push cx
    push dx
    push si

    mov ax, 0xf000
    mov ds, ax
    mov si, 0xfa6e
    mov bl, [bp+6]
    xor bh, bh
    shl bx, 3
    add si, bx

    mov dx, [bp+8]
    mov cx, 8
.row:
    push cx
    lodsb
    mov ah, al
    mov bx, [bp+10]
    mov cx, 8
.col:
    shl ah, 1
    jnc .skip
    push ds
    push cs
    pop ds
    push bx
    push dx
    push word [bp+4]
    call putpixel
    pop ds
.skip:
    inc bx
    dec cl
    jnz .col

    pop cx
    inc dx
    loop .row

    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    pop ds
    pop bp
    ret 8

; subroutine to print null-terminated string
; inputs on stack: [bp+10]=x, [bp+8]=y, [bp+6]=addr, [bp+4]=color
printstr:
    push bp
    mov bp, sp
    push ax
    push bx
    push si

    mov bx, [bp+10]
    mov si, [bp+6]
.next:
    lodsb
    cmp al, 0
    je .done
    push bx
    push word [bp+8]
    xor ah, ah
    push ax
    push word [bp+4]
    call printchar
    add bx, 8
    jmp .next
.done:
    pop si
    pop bx
    pop ax
    pop bp
    ret 8

; subroutine to copy orig_map to work_map using rep movsb
; inputs: none, outputs: none, preserves registers
resetmap:
    push es
    push cx
    push si
    push di

    cld
    push ds
    pop es
    mov si, orig_map
    mov di, work_map
    mov cx, MAP_SIZE
    rep movsb

    pop di
    pop si
    pop cx
    pop es
    ret

; subroutine to get tile code at world pixel (px, py)
; inputs on stack: [bp+6]=px, [bp+4]=py; output: AL=tile code
gettile:
    push bp
    mov bp, sp
    push bx
    push dx

    mov ax, [bp+6]
    cmp ax, 0
    jl .out
    cmp ax, WORLD_W
    jge .out

    mov bx, [bp+4]
    cmp bx, 0
    jl .out
    cmp bx, 192
    jge .out

    shr ax, 4
    shr bx, 4
    mov dx, ax
    mov al, 60
    mul bl
    add ax, dx
    mov bx, ax
    mov al, [work_map + bx]
    jmp .exit

.out:
    xor al, al
.exit:
    pop dx
    pop bx
    pop bp
    ret 4

; subroutine to set tile code in work_map at world pixel (px, py)
; inputs on stack: [bp+8]=px, [bp+6]=py, [bp+4]=tile_code
settile:
    push bp
    mov bp, sp
    push ax
    push bx
    push dx

    mov ax, [bp+8]
    shr ax, 4
    mov dx, ax
    mov bx, [bp+6]
    shr bx, 4
    mov al, 60
    mul bl
    add ax, dx
    mov bx, ax
    mov al, [bp+4]
    mov [work_map + bx], al

    pop dx
    pop bx
    pop ax
    pop bp
    ret 6

; subroutine to draw a single 16x16 tile
; inputs on stack: [bp+8]=sx, [bp+6]=sy, [bp+4]=code
drawtile:
    push bp
    mov bp, sp
    push ax
    push bx
    push cx

    mov al, [bp+4]
    cmp al, TILE_SKY
    jne .not_sky
    jmp .exit
.not_sky:
    mov bx, [bp+8]
    mov cx, [bp+6]

    cmp al, TILE_GROUND
    jne .t_brick
    push bx
    push cx
    push 16
    push 16
    push COL_BROWN
    call fillrect
    push bx
    push cx
    push 16
    push 3
    push COL_GREEN
    call fillrect
    jmp .exit

.t_brick:
    cmp al, TILE_BRICK
    jne .t_q
    push bx
    push cx
    push 16
    push 16
    push COL_BROWN
    call fillrect
    push bx
    mov ax, cx
    add ax, 7
    push ax
    push 16
    push 2
    push COL_BLACK
    call fillrect
    jmp .exit

.t_q:
    cmp al, TILE_Q_COIN
    je .do_q
    cmp al, TILE_Q_MUSH
    jne .t_empty
.do_q:
    push bx
    push cx
    push 16
    push 16
    push COL_ORANGE
    call fillrect
    mov ax, bx
    add ax, 4
    push ax
    mov ax, cx
    add ax, 4
    push ax
    push '?'
    push COL_WHITE
    call printchar
    jmp .exit

.t_empty:
    cmp al, TILE_EMPTY
    jne .t_pipe
    push bx
    push cx
    push 16
    push 16
    push COL_DGREY
    call fillrect
    jmp .exit

.t_pipe:
    cmp al, TILE_PIPE_TL
    jl .t_stair
    cmp al, TILE_PIPE_BR
    jg .t_stair
    push bx
    push cx
    push 16
    push 16
    push COL_GREEN
    call fillrect
    mov ax, bx
    add ax, 3
    push ax
    push cx
    push 4
    push 16
    push COL_LGREEN
    call fillrect
    jmp .exit

.t_stair:
    cmp al, TILE_STAIR
    jne .t_coin
    push bx
    push cx
    push 16
    push 16
    push COL_ORANGE
    call fillrect
    jmp .exit

.t_coin:
    cmp al, TILE_COIN
    jne .t_flag
    mov ax, bx
    add ax, 5
    push ax
    mov ax, cx
    add ax, 3
    push ax
    push 6
    push 10
    push COL_YELLOW
    call fillrect
    jmp .exit

.t_flag:
    cmp al, TILE_FLAG
    jne .exit
    mov ax, bx
    add ax, 7
    push ax
    push cx
    push 2
    push 16
    push COL_WHITE
    call fillrect
    cmp cx, 32
    jne .exit
    push bx
    push cx
    push 8
    push 8
    push COL_LGREEN
    call fillrect

.exit:
    pop cx
    pop bx
    pop ax
    pop bp
    ret 6

; subroutine to draw visible 21 columns of map
; inputs: none, outputs: none, preserves registers
drawmap:
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    mov ax, [camera_x]
    mov si, ax
    shr si, 4

    and ax, 0x000f
    neg ax
    mov di, ax

    mov cx, 21
.cloop:
    cmp si, MAP_COLS
    jge .done

    push cx
    mov dx, 1
.rloop:
    cmp dx, MAP_ROWS
    jge .nextc

    mov ax, 60
    mul dl
    add ax, si
    mov bx, ax
    mov al, [work_map + bx]
    xor ah, ah

    push di
    mov bx, dx
    shl bx, 4
    push bx
    push ax
    call drawtile

    inc dx
    jmp .rloop

.nextc:
    pop cx
    inc si
    add di, 16
    loop .cloop

.done:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; subroutine to draw 16x16 or 16x32 sprite with mirroring and clipping
; inputs on stack: [bp+10]=sx, [bp+8]=sy, [bp+6]=addr, [bp+4]=flags
drawsprite:
    push bp
    mov bp, sp
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    mov si, [bp+6]
    mov dx, [bp+8]
    mov cx, 16

.rloop:
    push cx
    xor di, di
.cloop:
    mov al, [si]
    cmp al, 0
    je .skip

    mov bx, [bp+10]
    test word [bp+4], 1
    jz .nomir
    add bx, 15
    sub bx, di
    jmp .plot
.nomir:
    add bx, di

.plot:
    push bx
    push dx
    xor ah, ah
    push ax
    call putpixel

    test word [bp+4], 2
    jz .skip
    push bx
    mov ax, dx
    inc ax
    push ax
    mov al, [si]
    xor ah, ah
    push ax
    call putpixel

.skip:
    inc si
    inc di
    cmp di, 16
    jl .cloop

    inc dx
    test word [bp+4], 2
    jz .nextr
    inc dx
.nextr:
    pop cx
    loop .rloop

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    pop bp
    ret 8
