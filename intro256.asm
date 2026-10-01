; UBER256 - tiny authentic DOS/VGA intro
; NASM: nasm -f bin intro256.asm -o UBER256.COM
; Target: DOS / DOSBox, VGA, 386+
BITS 16
ORG 100h

start:
    mov ax,13h
    int 10h
    push word 0A000h
    pop es
    xor bx,bx                    ; frame/phase

frame:
    xor di,di
    mov dx,200                   ; y
.y:
    mov cx,320                   ; x
.x:
    ; compact interference field: x/y/frame + multiplicative texture
    mov ax,cx
    xor ax,dx
    add ax,bx
    imul ax,dx
    shr ax,3
    xor al,cl
    add al,bl
    stosb
    loop .x
    dec dx
    jnz .y

    inc bx
    in al,60h
    dec al                       ; Esc scancode 1 => zero
    jnz frame

    mov ax,3
    int 10h
    ret
