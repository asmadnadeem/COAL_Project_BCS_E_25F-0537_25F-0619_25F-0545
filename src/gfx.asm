; module 2 and 5: video memory, buffer and text routines

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
