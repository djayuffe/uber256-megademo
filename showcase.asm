; UBER DOS SHOWCASE 5.0 - polished procedural VGA demo
; NASM syntax, DOS .COM, 386+, VGA, PC speaker. No external assets.
BITS 16
ORG 100h

%define SCENE_SHIFT 9             ; 512 frames/scene (~7.3 s at 70 Hz)
%define SCENE_MASK  15            ; 16 primary scenes

start:
    push cs
    pop ds
    mov ah,0Fh
    int 10h
    mov [old_mode],al
    mov ah,48h
    mov bx,4000                   ; 64000 bytes
    int 21h
    jc nomem
    mov [backseg],ax
    mov ax,13h
    int 10h
    in al,21h
    mov [pic_mask],al
    or al,2                       ; mask IRQ1 so BIOS int 9 cannot race
    out 21h,al                    ; our own port-60h/64h polling for Esc
    xor bp,bp
    call palette_tick
    call speaker_on

main:
    mov ax,[backseg]
    mov es,ax
    xor di,di
    mov ax,bp
    mov cl,SCENE_SHIFT
    shr ax,cl
    and al,SCENE_MASK
    cmp al,0
    je scene_plasma
    cmp al,1
    je scene_tunnel
    cmp al,2
    je scene_xor
    cmp al,3
    je scene_moire
    cmp al,4
    je scene_checker
    cmp al,5
    je scene_ripples
    cmp al,6
    je scene_twister
    cmp al,7
    je scene_feedback
    cmp al,8
    je scene_copper
    cmp al,9
    je scene_diamond
    cmp al,10
    je scene_lattice
    cmp al,11
    je scene_warp
    cmp al,12
    je scene_scanwave
    cmp al,13
    je scene_bitplane
    cmp al,14
    je scene_vortex
    jmp scene_finale

; 1: interference plasma - cheap arithmetic, continuously phase animated.
scene_plasma:
    xor dx,dx
.py: xor cx,cx
.px:
    mov ax,cx
    add ax,bp
    xor ax,dx
    mov bx,dx
    shl bx,1
    add ax,bx
    xor al,ah
    add al,cl
    rol al,1
    stosb
    inc cx
    cmp cx,320
    jb .px
    inc dx
    cmp dx,200
    jb .py
    jmp overlay

; 2: perspective-ish radial tunnel. Heavy scene, intentionally isolated.
scene_tunnel:
    xor dx,dx
.ty: xor cx,cx
.tx:
    mov ax,cx
    sub ax,160
    mov si,ax
    imul ax,ax
    mov bx,dx
    sub bx,100
    imul bx,bx
    add ax,bx
    shr ax,6
    xor si,dx
    add si,bp
    shr si,2
    mov bx,si
    add al,bl
    stosb
    inc cx
    cmp cx,320
    jb .tx
    inc dx
    cmp dx,200
    jb .ty
    jmp overlay

; 3: x*y XOR interference.
scene_xor:
    xor dx,dx
.xy: xor cx,cx
.xx:
    mov ax,cx
    imul ax,dx
    shr ax,3
    xor ax,cx
    xor ax,dx
    add ax,bp
    rol al,1
    stosb
    inc cx
    cmp cx,320
    jb .xx
    inc dx
    cmp dx,200
    jb .xy
    jmp overlay

; 4: concentric moire rings.
scene_moire:
    xor dx,dx
.my: xor cx,cx
.mx:
    mov ax,cx
    sub ax,160
    mov bx,dx
    sub bx,100
    imul ax,ax
    imul bx,bx
    add ax,bx
    shr ax,5
    add ax,bp
    xor al,dl
    stosb
    inc cx
    cmp cx,320
    jb .mx
    inc dx
    cmp dx,200
    jb .my
    jmp overlay

; 5: zooming checker / floor-grid illusion. No multiply in inner loop.
scene_checker:
    xor dx,dx
.cy: xor cx,cx
.cx:
    mov ax,cx
    add ax,bp
    shr ax,3
    mov bx,dx
    mov si,bp
    shr si,1
    add bx,si
    shr bx,3
    xor ax,bx
    test al,1
    jz .dark
    mov al,210
    jmp .store
.dark:
    mov al,28
.store:
    add al,dl
    stosb
    inc cx
    cmp cx,320
    jb .cx
    inc dx
    cmp dx,200
    jb .cy
    jmp overlay

; 6: dual-source ripple interference using Manhattan distance: fast and fluid.
scene_ripples:
    xor dx,dx
.ry: xor cx,cx
.rx:
    mov ax,cx
    sub ax,96
    jns .a1
    neg ax
.a1: mov bx,dx
    sub bx,72
    jns .a2
    neg bx
.a2: add ax,bx
    mov si,cx
    sub si,232
    jns .b1
    neg si
.b1: mov bx,dx
    sub bx,128
    jns .b2
    neg bx
.b2: add si,bx
    sub ax,si
    add ax,bp
    rol al,2
    stosb
    inc cx
    cmp cx,320
    jb .rx
    inc dx
    cmp dx,200
    jb .ry
    jmp overlay

; 7: twisting vertical ribbons. Phase changes per scanline and frame.
scene_twister:
    xor dx,dx
.wy: xor cx,cx
.wx:
    mov ax,dx
    shl ax,1
    add ax,bp
    xor al,ah
    mov bl,al
    mov ax,cx
    add al,bl
    and al,63
    cmp al,16
    jb .hot
    cmp al,48
    ja .hot
    mov al,40
    jmp .ws
.hot:
    mov al,230
.ws:
    add al,dl
    stosb
    inc cx
    cmp cx,320
    jb .wx
    inc dx
    cmp dx,200
    jb .wy
    jmp overlay

; 8: self-referential-looking cellular field. Deterministic, no previous-frame dependency.
scene_feedback:
    xor dx,dx
.fy: xor cx,cx
.fx:
    mov ax,cx
    xor ax,dx
    add ax,bp
    mov bx,cx
    shr bx,2
    xor ax,bx
    mov bx,dx
    shl bx,2
    add ax,bx
    rol al,cl
    xor al,ah
    stosb
    inc cx
    cmp cx,320
    jb .fx
    inc dx
    cmp dx,200
    jb .fy
    jmp overlay

; 9: copper-wave field. Horizontal phase bands with cheap scanline recurrence.
scene_copper:
    xor dx,dx
.cy: xor cx,cx
    mov ax,dx
    add ax,bp
    rol al,1
    mov si,ax
.cx:
    mov ax,cx
    shr ax,2
    add ax,si
    xor al,dl
    add al,dh
    stosb
    inc cx
    cmp cx,320
    jb .cx
    inc dx
    cmp dx,200
    jb .cy
    jmp overlay

; 10: expanding diamond / Manhattan rings. No multiply in inner loop.
scene_diamond:
    xor dx,dx
.dy: xor cx,cx
.dx:
    mov ax,cx
    sub ax,160
    jns .dxa
    neg ax
.dxa:
    mov si,dx
    sub si,100
    jns .dya
    neg si
.dya:
    add ax,si
    shl ax,2
    add ax,bp
    xor al,ah
    stosb
    inc cx
    cmp cx,320
    jb .dx
    inc dx
    cmp dx,200
    jb .dy
    jmp overlay

; 11: animated lattice / diagonal interference.
scene_lattice:
    xor dx,dx
.ly: xor cx,cx
.lx:
    mov ax,cx
    add ax,dx
    add ax,bp
    and al,31
    mov si,ax
    mov ax,cx
    sub ax,dx
    sub ax,bp
    and al,31
    xor ax,si
    shl al,3
    stosb
    inc cx
    cmp cx,320
    jb .lx
    inc dx
    cmp dx,200
    jb .ly
    jmp overlay

; 12: horizontal warp bands.
scene_warp:
    xor dx,dx
.way: xor cx,cx
    mov ax,dx
    add ax,bp
    xor al,ah
    cbw
    mov si,ax
.wax:
    mov ax,cx
    add ax,si
    xor ax,dx
    rol al,2
    add ax,bp
    stosb
    inc cx
    cmp cx,320
    jb .wax
    inc dx
    cmp dx,200
    jb .way
    jmp overlay

; 13: scanwave / CRT-like moving bands.
scene_scanwave:
    xor dx,dx
.swy: xor cx,cx
.swx:
    mov ax,dx
    shl ax,2
    add ax,bp
    xor al,ah
    mov si,ax
    mov ax,cx
    shr ax,1
    xor ax,si
    test dl,1
    jz .swe
    shr al,1
.swe:
    add al,32
    stosb
    inc cx
    cmp cx,320
    jb .swx
    inc dx
    cmp dx,200
    jb .swy
    jmp overlay

; 14: bitplane interference, intentionally digital and CRTC-like.
scene_bitplane:
    xor dx,dx
.bpy: xor cx,cx
.bpx:
    mov ax,cx
    xor ax,dx
    add ax,bp
    mov si,cx
    and si,dx
    xor ax,si
    rol al,1
    and al,0F8h
    add al,dl
    stosb
    inc cx
    cmp cx,320
    jb .bpx
    inc dx
    cmp dx,200
    jb .bpy
    jmp overlay

; 15: vortex-ish signed-coordinate mixer without division.
scene_vortex:
    xor dx,dx
.vy: xor cx,cx
.vx:
    mov ax,cx
    sub ax,160
    mov si,dx
    sub si,100
    xor ax,si
    rol ax,1
    add ax,cx
    sub ax,dx
    add ax,bp
    xor al,ah
    stosb
    inc cx
    cmp cx,320
    jb .vx
    inc dx
    cmp dx,200
    jb .vy
    jmp overlay

; 16: finale combines time, coordinates and coarse radial energy.
scene_finale:
    xor dx,dx
.fy: xor cx,cx
.fx:
    mov ax,cx
    sub ax,160
    mov si,ax
    jns .fax
    neg si
.fax:
    mov ax,dx
    sub ax,100
    jns .fay
    neg ax
.fay:
    add ax,si
    shl ax,1
    xor ax,cx
    add ax,dx
    add ax,bp
    rol al,1
    stosb
    inc cx
    cmp cx,320
    jb .fx
    inc dx
    cmp dx,200
    jb .fy
    jmp overlay


overlay:
    ; Three smooth raster bars, positions phase-locked to global frame clock.
    mov ax,bp
    and ax,127
    add ax,30
    call raster_line
    mov ax,bp
    shr ax,1
    and ax,63
    add ax,92
    call raster_line
    mov ax,bp
    shr ax,2
    and ax,31
    add ax,150
    call raster_line
    call scene_marker
    call transition_wipe

present:
    call wait_vsync
    call palette_tick
    push ds
    mov ax,[backseg]
    mov ds,ax
    xor si,si
    mov ax,0A000h
    mov es,ax
    xor di,di
    mov cx,32000
    rep movsw
    pop ds
    inc bp
    call music_tick
    call key_escape
    jnc main

exit:
    call speaker_off
    mov al,[pic_mask]
    out 21h,al                    ; restore BIOS IRQ1 keyboard servicing
    mov ax,[backseg]
    mov es,ax
    mov ah,49h
    int 21h
    xor ah,ah
    mov al,[old_mode]
    int 10h
    mov ax,4C00h
    int 21h

nomem:
    mov dx,msg_nomem
    mov ah,9
    int 21h
    mov ax,4C01h
    int 21h

; AX = y. ES still points at backbuffer here.
raster_line:
    cmp ax,199
    ja .done
    push ax
    push bx
    push cx
    push di
    mov bx,320
    mul bx
    mov di,ax
    mov cx,320
    mov al,248
    rep stosb
    pop di
    pop cx
    pop bx
    pop ax
.done: ret


; Scene identity strip: 16 small blocks at the top, current scene highlighted.
; Deliberately tiny: 16 blocks * 8x8 pixels = 1024 stores/frame.
scene_marker:
    push ax
    push bx
    push cx
    push dx
    push di
    mov ax,bp
    mov cl,SCENE_SHIFT
    shr ax,cl
    and ax,SCENE_MASK
    mov dx,ax
    xor bx,bx
.sm_next:
    mov ax,bx
    shl ax,3
    add ax,4
    mov di,ax
    mov cx,8
    mov al,32
    cmp bx,dx
    jne .sm_color
    mov al,252
.sm_color:
    push cx
    mov cx,8
    rep stosb
    pop cx
    add di,312
    loop .sm_color
    inc bx
    cmp bx,16
    jb .sm_next
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; Cheap transition shutter. During the first/last 16 frames of a scene,
; black bars close/open symmetrically. Palette fade remains the primary blend.
transition_wipe:
    push ax
    push bx
    push cx
    push dx
    push di
    mov ax,bp
    and ax,511
    cmp ax,16
    jb .tw_have
    cmp ax,496
    jb .tw_done
    mov bx,512
    sub bx,ax
    mov ax,bx
.tw_have:
    ; AX=0..15. Convert to number of covered scanlines, 96..6.
    mov bx,ax
    shl ax,1
    add ax,bx
    mov bx,100
    sub bx,ax
    cmp bx,0
    jle .tw_done
    mov dx,bx
    xor di,di
.tw_top:
    mov cx,320
    xor al,al
    rep stosb
    dec dx
    jnz .tw_top
    mov ax,bx
    mov dx,200
    sub dx,ax
    mov ax,dx
    mov cx,320
    mul cx
    mov di,ax
    mov dx,bx
.tw_bottom:
    mov cx,320
    xor al,al
    rep stosb
    dec dx
    jnz .tw_bottom
.tw_done:
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

wait_vsync:
    mov dx,3DAh
.w0: in al,dx
    test al,8
    jnz .w0
.w1: in al,dx
    test al,8
    jz .w1
    ret

; Palette morphing: scene number changes channel relationships, frame changes phase.
palette_tick:
    ; Scene-local triangular brightness envelope.  The first/last 32 frames
    ; fade through black, hiding the hard procedural scene switch cheaply.
    mov ax,bp
    and ax,511
    cmp ax,32
    jb .fade_in
    cmp ax,480
    jae .fade_out
    mov byte [pal_limit],63
    jmp .pal_begin
.fade_in:
    shl ax,1
    mov [pal_limit],al
    jmp .pal_begin
.fade_out:
    mov bx,512
    sub bx,ax
    shl bx,1
    mov [pal_limit],bl
.pal_begin:
    mov dx,3C8h
    xor al,al
    out dx,al
    inc dx
    xor cx,cx                    ; CL = exact palette index 0..255
.pt:
    mov ax,cx
    add ax,bp
    mov bx,bp
    shr bx,11                    ; act/scene family drives palette identity
    shl bx,2
    add ax,bx
    and al,63
    call .limit
    out dx,al

    mov ax,cx
    shr al,1
    add ax,bp
    mov bx,bp
    shr bx,SCENE_SHIFT
    xor ax,bx
    and al,63
    call .limit
    out dx,al

    mov ax,cx
    not al
    add ax,bp
    mov bx,bp
    shr bx,SCENE_SHIFT-2
    add ax,bx
    and al,63
    call .limit
    out dx,al

    inc cl
    jnz .pt
    ret
.limit:
    cmp al,[pal_limit]
    jbe .ok
    mov al,[pal_limit]
.ok: ret

key_escape:
    in al,64h
    test al,1
    jz .no
    in al,60h
    cmp al,1
    je .yes
.no: clc
    ret
.yes: stc
    ret

speaker_on:
    in al,61h
    or al,3
    out 61h,al
    ret
speaker_off:
    in al,61h
    and al,0FCh
    out 61h,al
    ret

; 16-step melody/bass pulse. Update every 8 frames (~8.75 Hz at VGA 70 Hz).
music_tick:
    mov ax,bp
    test al,7
    jnz .done
    shr ax,3
    and ax,15
    shl ax,1
    mov si,ax
    mov ax,[notes+si]
    ; Scene-dependent harmonic movement: small divisor offsets keep the
    ; arpeggio evolving through the 16-scene show without extra tables.
    mov dx,bp
    mov cl,SCENE_SHIFT
    shr dx,cl
    and dx,15
    shl dx,4
    sub ax,dx
    cmp ax,900
    ja .note_ok
    add ax,1024
.note_ok:
    mov bx,ax
    mov al,0B6h
    out 43h,al
    mov ax,bx
    out 42h,al
    mov al,ah
    out 42h,al
.done: ret

notes dw 2712,2416,2032,1810,2032,2416,3043,2280
      dw 3619,3043,2712,2280,2416,2032,1810,1521
old_mode db 3
backseg dw 0
pal_limit db 63
pic_mask db 0
msg_nomem db 'UBERSHOW: not enough conventional memory.$'
