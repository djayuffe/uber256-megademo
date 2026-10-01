; UBER DOS SHOWCASE 5.0 - polished procedural VGA demo
; NASM syntax, DOS .COM, 386+, VGA, PC speaker. No external assets.
BITS 16
ORG 100h

%define SCENE_SHIFT 9             ; 512 frames/scene (~7.3 s at 70 Hz)
%define SCENE_COUNT 18            ; 18 primary scenes (16 fields + cube + starfield)
%define SCROLL_BASE_Y 182         ; bottom text-scroller baseline row
%define SCROLL_BG 1                ; fixed black (see palette_tick reserved DAC entries)
; Scroller foreground cycles across fixed DAC indices 4..7 (a small rainbow,
; see palette_tick) rather than one fixed colour -- see scroll_draw.
%define CUBE_BG 1                 ; fixed black background fill
%define CUBE_FG 2                 ; fixed white, near-edge wireframe colour
%define CUBE_FG_DIM 3             ; fixed dim grey, far-edge wireframe colour
%define CUBE_EYE_DIST 160         ; perspective-divide distance from the eye
%define CUBE_PROJ_SCALE 110       ; perspective projection scale factor
%define STAR_COUNT 32             ; stars in scene_starfield
%define STAR_SCALE 20             ; starfield perspective projection scale

start:
    ; A .COM program owns ALL free conventional memory at launch (its PSP
    ; block spans to the top of the DOS arena). Without shrinking that block
    ; first, the later 64,000-byte AH=48h allocation below always fails with
    ; "insufficient memory", since DOS has nothing left to give out.
    mov ax,cs
    mov es,ax
    mov bx,512                    ; 512 paragraphs = 8192 bytes: comfortably
    mov ah,4Ah                    ; covers code+data+stack (font, scroller,
    int 21h                       ; cube tables) with room to spare. SETBLOCK
                                   ; shrinks our own memory block so the AH=48h
                                   ; call below has free memory to allocate from.
    mov ax,cs
    mov ss,ax
    mov sp,stack_top              ; switch onto our own stack inside that block
    push cs
    pop ds
    mov ah,0Fh
    int 10h
    mov [old_mode],al
    mov ax,13h
    int 10h
    ; True hardware double buffering: widen the VGA CPU window from the
    ; BIOS mode-13h default (64K @ A0000h) to 128K @ A0000h (Graphics
    ; Controller Misc Register, Memory Map Select = 00), so segments A000h
    ; and B000h both address real VGA memory -- two independent 64,000-byte
    ; pages. Each frame renders entirely into the currently-hidden page,
    ; then present: flips the CRTC start address to display it: a real
    ; page flip, not a software backbuffer-to-A000h copy.
    mov dx,3CEh
    mov al,6
    out dx,al
    inc dx
    in al,dx
    and al,0F3h                   ; Memory Map Select = 00 (128K @ A0000h)
    out dx,al
    mov byte [vga_page],0         ; page we render into next (0=A000h,1=B000h)
    in al,21h
    mov [pic_mask],al
    or al,2                       ; mask IRQ1 so BIOS int 9 cannot race
    out 21h,al                    ; our own port-60h/64h polling for Esc
    xor bp,bp
    call palette_tick
    call speaker_on

main:
    mov al,[vga_page]              ; render into the currently-hidden page
    cmp al,0
    je .page0
    mov ax,0B000h
    jmp .haveseg
.page0:
    mov ax,0A000h
.haveseg:
    mov es,ax
    xor di,di
    ; Scene index = (frame >> SCENE_SHIFT) mod SCENE_COUNT. SCENE_COUNT is not
    ; a power of two (17 scenes), so this uses DIV instead of an AND mask;
    ; the remainder (DL) is cached in cur_scene so scene_marker and
    ; music_tick read the same value instead of recomputing it separately.
    mov ax,bp
    mov cl,SCENE_SHIFT
    shr ax,cl
    xor dx,dx
    mov bx,SCENE_COUNT
    div bx
    mov [cur_scene],dl
    mov al,dl
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
    cmp al,15
    je scene_cube
    cmp al,16
    je scene_starfield
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

; 16: rotating wireframe cube. The only non-full-screen-field scene: it
; clears the backbuffer to a flat colour first, then projects and draws a
; true 3D object (two-axis rotation, orthographic projection, Bresenham
; line draw) instead of a per-pixel procedural texture.
scene_cube:
    mov ax,CUBE_BG
    mov ah,al
    mov cx,32000
    rep stosw

    mov ax,bp
    shr ax,1
    and ax,255
    mov [cube_angle_y],ax
    mov ax,bp
    shr ax,2
    and ax,255
    mov [cube_angle_x],ax

    xor bx,bx                      ; bx = vertex byte offset (3 words/vertex)
    xor si,si                      ; si = proj_x/proj_y byte offset (1 word/vertex)
.cv_loop:
    mov ax,[cube_verts+bx]
    mov [cube_px],ax
    mov ax,[cube_verts+bx+2]
    mov [cube_py],ax
    mov ax,[cube_verts+bx+4]
    mov [cube_pz],ax
    call cube_rotate_project
    mov ax,[cube_sx]
    mov [proj_x+si],ax
    mov ax,[cube_sy]
    mov [proj_y+si],ax
    mov ax,[cube_rz2]
    mov [proj_z+si],ax             ; depth, for this edge's brightness pick
    add bx,6
    add si,2
    cmp bx,8*6
    jb .cv_loop

    xor si,si
.ce_loop:
    mov al,[cube_edges+si]
    xor ah,ah
    shl ax,1
    mov bx,ax
    mov ax,[proj_x+bx]
    mov [line_x0],ax
    mov ax,[proj_y+bx]
    mov [line_y0],ax
    mov ax,[proj_z+bx]
    mov dx,ax                      ; dx = vertex-0 depth
    mov al,[cube_edges+si+1]
    xor ah,ah
    shl ax,1
    mov bx,ax
    mov ax,[proj_x+bx]
    mov [line_x1],ax
    mov ax,[proj_y+bx]
    mov [line_y1],ax
    add dx,[proj_z+bx]             ; dx = sum of both endpoints' depth
    mov byte [line_color],CUBE_FG
    cmp dx,0                       ; average depth < 0 => nearer the eye
    jl .near
    mov byte [line_color],CUBE_FG_DIM
.near:
    call draw_line
    add si,2
    cmp si,12*2
    jb .ce_loop
    jmp overlay

; 17: 3D starfield. Each star has a genuine Z depth, computed fresh every
; frame as a function of the frame clock and star index (no persistent
; per-star state needed): Z counts down from far to near and wraps back to
; far, so stars continuously stream toward the viewer. Perspective-divides
; by Z exactly like scene_cube's projection, just for points instead of
; wireframe edges, and brightens as a star gets closer.
scene_starfield:
    mov ax,CUBE_BG
    mov ah,al
    mov cx,32000
    rep stosw

    mov word [star_idx],0
    xor si,si                      ; si = star index * 2 (word table offset)
.st_loop:
    mov ax,bp
    mov cx,3
    mul cx                         ; ax = (frame*3) mod 65536 -- truncation
                                    ; just means one harmless seam every
                                    ; 65536 frames (~15 min), never visible
    mov cx,[star_idx]
    imul cx,37                     ; stagger each star's phase
    add ax,cx
    xor dx,dx
    mov cx,240
    div cx                         ; dx = phase 0..239
    mov ax,255
    sub ax,dx                      ; ax = Z: 255 (far) down to 16 (near),
    mov [star_z],ax                ; wraps back to far when phase resets

    mov ax,[star_base_x+si]
    mov cx,STAR_SCALE
    imul ax,cx
    cwd
    idiv word [star_z]
    add ax,160
    mov [star_sx],ax

    mov ax,[star_base_y+si]
    mov cx,STAR_SCALE
    imul ax,cx
    cwd
    idiv word [star_z]
    add ax,100
    mov [star_sy],ax

    mov byte [star_color],CUBE_FG_DIM
    mov ax,[star_z]
    cmp ax,80
    jg .plot
    mov byte [star_color],CUBE_FG
.plot:
    mov ax,[star_sy]
    cmp ax,0
    jl .st_skip
    cmp ax,199
    jg .st_skip
    mov bx,[star_sx]
    cmp bx,0
    jl .st_skip
    cmp bx,319
    jg .st_skip
    mov cx,320
    mul cx
    add ax,bx
    mov di,ax
    mov al,[star_color]
    stosb
.st_skip:
    add si,2
    mov ax,[star_idx]
    inc ax
    mov [star_idx],ax
    cmp ax,STAR_COUNT
    jb .st_loop
    jmp overlay

; 18: finale combines time, coordinates and coarse radial energy.
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
    call scroll_draw              ; bottom sine-wave text scroller, drawn
                                   ; after the transition wipe so it's never
                                   ; covered by the scene-cut shutter bars

present:
    call wait_vsync
    call palette_tick
    ; Flip: show the page we just finished rendering into (show_page),
    ; and flip vga_page so next frame renders into the other, now-hidden
    ; page. wait_vsync above already caught the start of retrace, so this
    ; CRTC update lands inside vertical blank, same as the old blit did.
    mov al,[vga_page]
    mov [show_page],al
    xor al,1
    mov [vga_page],al
    mov al,[show_page]
    cmp al,0
    je .show0
    mov bx,4000h                  ; page1 (B000h) = byte offset 65536,
    jmp .haveaddr                 ; /4 for chain-4 start-address units
.show0:
    xor bx,bx                     ; page0 (A000h) = byte offset 0
.haveaddr:
    mov dx,3D4h
    mov al,0Ch
    out dx,al
    inc dx
    mov al,bh
    out dx,al
    dec dx
    mov al,0Dh
    out dx,al
    inc dx
    mov al,bl
    out dx,al
    inc bp
    call music_tick
    call key_escape
    jnc main

exit:
    call speaker_off
    mov al,[pic_mask]
    out 21h,al                    ; restore BIOS IRQ1 keyboard servicing
    xor ah,ah
    mov al,[old_mode]
    int 10h
    mov ax,4C00h
    int 21h

; AX = y. ES still points at backbuffer here. Draws a soft 3-scanline glow
; (dim/bright/dim) instead of one flat line, a classic fatter raster bar.
raster_line:
    cmp ax,199
    ja .done
    push ax
    push bx
    push cx
    push di
    mov [raster_cy],ax             ; centre y (mul below clobbers dx, so this
                                    ; can't just live in a register)
    cmp ax,0
    je .no_above
    dec ax
    mov bx,320
    mul bx
    mov di,ax
    mov cx,320
    mov al,232
    rep stosb
.no_above:
    mov ax,[raster_cy]
    mov bx,320
    mul bx
    mov di,ax
    mov cx,320
    mov al,248
    rep stosb

    mov ax,[raster_cy]
    cmp ax,199
    je .no_below
    inc ax
    mov bx,320
    mul bx
    mov di,ax
    mov cx,320
    mov al,232
    rep stosb
.no_below:
    pop di
    pop cx
    pop bx
    pop ax
.done: ret


; Scene identity strip: SCENE_COUNT small blocks at the top, current scene
; highlighted. Deliberately tiny: 17 blocks * 8x8 pixels ~= 1088 stores/frame.
scene_marker:
    push ax
    push bx
    push cx
    push dx
    push di
    mov dl,[cur_scene]
    xor dh,dh
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
    cmp bx,SCENE_COUNT
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
    ; Reserve DAC indices 1 (black) and 2 (white) as fixed, high-contrast
    ; colours that the animated loop above never gets the last word on.
    ; Without this, the scroller/cube UI colours are just two more indices
    ; in the same one continuous animated formula as everything else, so
    ; they can (and did, visibly) drift to similar tones and lose contrast.
    mov dx,3C8h
    mov al,1
    out dx,al                    ; select index 1
    inc dx                        ; dx=3C9h, the data port
    xor al,al
    out dx,al
    out dx,al
    out dx,al                    ; index 1 = pure black (0,0,0)
    mov dx,3C8h
    mov al,2
    out dx,al                    ; select index 2
    inc dx
    mov al,63
    out dx,al
    out dx,al
    out dx,al                    ; index 2 = pure white (63,63,63)
    mov dx,3C8h
    mov al,3
    out dx,al                    ; select index 3
    inc dx
    mov al,24
    out dx,al
    out dx,al
    out dx,al                    ; index 3 = fixed dim grey, for depth cueing
    ; indices 4..7: a small fixed rainbow for the scroller (red, yellow,
    ; green, cyan), so its colour-cycle doesn't fight the animated palette.
    mov dx,3C8h
    mov al,4
    out dx,al
    inc dx
    mov al,63
    out dx,al
    xor al,al
    out dx,al
    xor al,al
    out dx,al                    ; index 4 = red
    mov dx,3C8h
    mov al,5
    out dx,al
    inc dx
    mov al,63
    out dx,al
    mov al,63
    out dx,al
    xor al,al
    out dx,al                    ; index 5 = yellow
    mov dx,3C8h
    mov al,6
    out dx,al
    inc dx
    xor al,al
    out dx,al
    mov al,50
    out dx,al
    xor al,al
    out dx,al                    ; index 6 = green
    mov dx,3C8h
    mov al,7
    out dx,al
    inc dx
    xor al,al
    out dx,al
    mov al,55
    out dx,al
    mov al,63
    out dx,al                    ; index 7 = cyan
    ret
.limit:
    cmp al,[pal_limit]
    jbe .ok
    mov al,[pal_limit]
.ok: ret

; Bottom sine-wave text scroller. Column-major: for each of the 320 screen
; columns, finds which glyph column it currently shows (scrollpos + x, into
; the precomputed scroll_msg glyph-index strip), looks the glyph bitmap up
; in font_data, and stamps its 8 rows with a per-column sine-table vertical
; offset for the classic wavy-scroller look. Advances scrollpos afterward.
scroll_draw:
    pusha
    mov word [scroll_x],0
.col:
    mov cx,[scroll_x]
    mov ax,[scrollpos]
    add ax,cx
    cmp ax,SCROLL_MSG_LEN*8
    jb .nowrap
    sub ax,SCROLL_MSG_LEN*8
.nowrap:
    mov bx,ax
    shr bx,3                       ; bx = character index
    and ax,7                       ; ax = bit index within glyph (0..7)
    mov dx,ax
    mov al,[scroll_msg+bx]
    push ax                        ; save glyph index (bx is about to change)
    mov ax,bp
    shr ax,4
    add ax,bx                      ; colour cycles both along the message
    and ax,3                       ; and over time, for a travelling-rainbow
    add ax,4                       ; look. Indices 4..7: see palette_tick.
    mov [scroll_fg_now],al
    pop ax
    xor ah,ah
    shl ax,3                       ; ax = glyph_index*8 = font_data offset
    mov si,ax
    add si,font_data
    mov cx,dx                      ; cx = bit index -> shift count
    mov bl,80h
    shr bl,cl                      ; bl = this column's bit mask in a glyph row
    mov ax,bp
    add ax,[scroll_x]
    and ax,255
    mov di,ax
    movsx ax,byte [sintab+di]
    sar ax,4                       ; wave amplitude ~ -4..4 px
    add ax,SCROLL_BASE_Y
    mov dx,ax                      ; dx = this column's base Y
    xor cx,cx                      ; cx = glyph row 0..7
.row:
    mov al,[si]                    ; si walks the glyph's 8 row bytes
    test al,bl
    jz .bgpix
    mov al,[scroll_fg_now]
    jmp .havecolor
.bgpix:
    mov al,SCROLL_BG
.havecolor:
    push ax                        ; save pixel colour
    mov ax,dx
    add ax,cx
    cmp ax,0
    jl .skip
    cmp ax,199
    jg .skip
    push dx                        ; save base Y (mul below clobbers dx)
    push bx                        ; save glyph bitmask (mul below needs bx)
    mov bx,320
    mul bx
    add ax,[scroll_x]
    mov di,ax
    pop bx
    pop dx
    pop ax
    stosb
    jmp .rownext
.skip:
    pop ax
.rownext:
    inc si                         ; next glyph row byte
    inc cx
    cmp cx,8
    jb .row
    mov ax,[scroll_x]
    inc ax
    mov [scroll_x],ax
    cmp ax,320
    jb .col
    ; advance scroll position, two frames per pixel for a readable speed
    test bp,1
    jnz .noadv
    mov ax,[scrollpos]
    inc ax
    cmp ax,SCROLL_MSG_LEN*8
    jb .advstore
    xor ax,ax
.advstore:
    mov [scrollpos],ax
.noadv:
    popa
    ret

; Rotate one 3D point (cube_px,cube_py,cube_pz) by cube_angle_y (around the
; Y axis) then cube_angle_x (around the X axis), using the shared sintab
; (cos(a) = sin((a+64)&255), a quarter-turn ahead in the same table), then
; project it orthographically to screen space in (cube_sx,cube_sy).
cube_rotate_project:
    pusha
    mov bx,[cube_angle_y]
    movsx ax,byte [sintab+bx]
    mov [cube_t1],ax                ; sinY
    mov si,bx
    add si,64
    and si,255
    movsx ax,byte [sintab+si]
    mov [cube_t2],ax                ; cosY

    mov ax,[cube_px]
    imul ax,[cube_t2]
    mov bx,ax
    mov ax,[cube_pz]
    imul ax,[cube_t1]
    sub bx,ax
    sar bx,6
    mov [cube_rx],bx                ; x*cosY - z*sinY

    mov ax,[cube_px]
    imul ax,[cube_t1]
    mov bx,ax
    mov ax,[cube_pz]
    imul ax,[cube_t2]
    add bx,ax
    sar bx,6
    mov [cube_rz],bx                ; x*sinY + z*cosY

    mov ax,[cube_py]
    mov [cube_ry],ax

    mov bx,[cube_angle_x]
    movsx ax,byte [sintab+bx]
    mov [cube_t1],ax                ; sinX
    mov si,bx
    add si,64
    and si,255
    movsx ax,byte [sintab+si]
    mov [cube_t2],ax                ; cosX

    mov ax,[cube_ry]
    imul ax,[cube_t2]
    mov bx,ax
    mov ax,[cube_rz]
    imul ax,[cube_t1]
    sub bx,ax
    sar bx,6
    mov [cube_ry2],bx                ; y*cosX - z*sinX

    mov ax,[cube_ry]
    imul ax,[cube_t1]
    mov bx,ax
    mov ax,[cube_rz]
    imul ax,[cube_t2]
    add bx,ax
    sar bx,6
    mov [cube_rz2],bx                ; y*sinX + z*cosX (final depth)

    ; True perspective projection (not orthographic): divide by distance
    ; from the eye, so edges nearer the viewer project larger. cube_rz2 is
    ; bounded to roughly +-70 by the rotation (it can't exceed the original
    ; vertex's vector length), and CUBE_EYE_DIST=160 keeps the denominator
    ; comfortably positive (90..230) for every vertex -- never zero.
    mov ax,[cube_rz2]
    add ax,CUBE_EYE_DIST
    mov [cube_depth],ax
    mov ax,[cube_rx]
    imul ax,CUBE_PROJ_SCALE
    cwd
    idiv word [cube_depth]
    add ax,160
    mov [cube_sx],ax
    mov ax,[cube_ry2]
    imul ax,CUBE_PROJ_SCALE
    cwd
    idiv word [cube_depth]
    add ax,100
    mov [cube_sy],ax
    popa
    ret

; General-purpose Bresenham line draw between (line_x0,line_y0) and
; (line_x1,line_y1) in line_color, with per-pixel bounds checks so an
; out-of-range projected point can never write outside the backbuffer.
draw_line:
    pusha
    mov ax,[line_x1]
    sub ax,[line_x0]
    mov word [line_sx],1
    cmp ax,0
    jge .no_negx
    neg ax
    mov word [line_sx],-1
.no_negx:
    mov [line_dx],ax

    mov ax,[line_y1]
    sub ax,[line_y0]
    mov word [line_sy],1
    cmp ax,0
    jge .no_negy
    neg ax
    mov word [line_sy],-1
.no_negy:
    neg ax
    mov [line_dy],ax                ; -abs(y1-y0)

    mov ax,[line_dx]
    add ax,[line_dy]
    mov [line_err],ax

    mov ax,[line_x0]
    mov [line_cx],ax
    mov ax,[line_y0]
    mov [line_cy],ax
.loop:
    mov ax,[line_cy]
    cmp ax,0
    jl .noplot
    cmp ax,199
    jg .noplot
    mov bx,[line_cx]
    cmp bx,0
    jl .noplot
    cmp bx,319
    jg .noplot
    mov cx,320
    mul cx
    add ax,bx
    mov di,ax
    mov al,[line_color]
    stosb
.noplot:
    mov ax,[line_cx]
    cmp ax,[line_x1]
    jne .step
    mov ax,[line_cy]
    cmp ax,[line_y1]
    jne .step
    jmp .done
.step:
    mov ax,[line_err]
    mov bx,ax
    shl bx,1
    cmp bx,[line_dy]
    jl .skipx
    mov ax,[line_err]
    add ax,[line_dy]
    mov [line_err],ax
    mov ax,[line_cx]
    add ax,[line_sx]
    mov [line_cx],ax
.skipx:
    mov bx,[line_err]
    shl bx,1
    cmp bx,[line_dx]
    jg .skipy
    mov ax,[line_err]
    add ax,[line_dx]
    mov [line_err],ax
    mov ax,[line_cy]
    add ax,[line_sy]
    mov [line_cy],ax
.skipy:
    jmp .loop
.done:
    popa
    ret

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

; 32-step A-minor-pentatonic phrase (a 16-step call, then a complementary
; 16-step response) with rests, update every 8 frames (~8.75 Hz at VGA
; 70 Hz). A 0 entry in `notes` is a rest: the speaker is muted rather than
; reprogrammed, so the pattern has actual rhythm instead of one continuous
; drone. Transposed by show act (cur_scene/8, the same shared value main:
; already computed) by HALVING the PIT divisor per octave rather than a
; raw subtraction -- divisor halving is always exactly one octave
; regardless of the starting note, so every transposed step stays in tune
; instead of drifting by an inconsistent interval.
music_tick:
    ; Two frames before each new step, mute briefly: a short, clean silence
    ; before the next retrigger reads as a real note attack instead of the
    ; PIT just sliding frequency under one continuously-gated speaker.
    mov ax,bp
    and ax,7
    cmp ax,6
    jne .checkbeat
    call speaker_off
    ret
.checkbeat:
    mov ax,bp
    test al,7
    jnz .done
    shr ax,3
    and ax,31
    shl ax,1
    mov si,ax
    mov ax,[notes+si]
    cmp ax,0
    jne .has_note
    call speaker_off           ; rest: mute until the next audible step
    jmp .done
.has_note:
    mov cl,[cur_scene]
    shr cl,3                   ; 0..2: which third of the show we're in
    cmp cl,2
    jbe .shiftok
    mov cl,2
.shiftok:
    shr ax,cl                  ; each unit = one octave up
    call speaker_on             ; re-arm the gate in case a rest muted it
    mov bx,ax
    mov al,0B6h
    out 43h,al
    mov ax,bx
    out 42h,al
    mov al,ah
    out 42h,al
.done: ret

; A-minor pentatonic, PIT divisors for A3,C4,D4,E4,G4,A4,C5,D5,E5,G5 (0=rest).
; First 16 steps are the "call" phrase, last 16 a complementary descending
; "response" that resolves back onto A4 so the 32-step loop feels like one
; phrase instead of two independent halves stitched together.
notes dw 2712,2280,1810,0,2032,2280,2712,0
      dw 3044,2712,2280,2032,1810,0,2280,1522
      dw 1522,1810,2032,0,2280,2032,1810,0
      dw 3044,1810,2280,2712,3044,0,2280,2712
old_mode db 3
vga_page db 0                     ; which page we render into next
show_page db 0                    ; which page present: just flipped to
pal_limit db 63
pic_mask db 0
cur_scene db 0                    ; scene index main: computed this frame,
                                   ; shared with scene_marker/music_tick so
                                   ; they can't drift out of sync with it

; --- bottom sine-wave text scroller state ---
scrollpos dw 0
scroll_x dw 0
scroll_fg_now db 4
raster_cy dw 0

; --- rotating wireframe cube scene state ---
cube_angle_y dw 0
cube_angle_x dw 0
cube_px dw 0
cube_py dw 0
cube_pz dw 0
cube_t1 dw 0
cube_t2 dw 0
cube_rx dw 0
cube_ry dw 0
cube_rz dw 0
cube_ry2 dw 0
cube_rz2 dw 0
cube_sx dw 0
cube_sy dw 0
cube_depth dw 0
proj_x times 8 dw 0
proj_y times 8 dw 0
proj_z times 8 dw 0

; --- 3D starfield scene state ---
star_idx dw 0
star_z dw 0
star_sx dw 0
star_sy dw 0
star_color db 0
star_base_x dw -93,-10,-36,-98,129,66,-135,-39,108,-137,-49,129,-38,-8,-69,66
            dw -8,-40,-98,44,33,-15,85,-87,-110,0,35,-52,-115,-34,-110,-99
star_base_y dw -89,-33,-60,78,-73,-87,-72,-36,59,48,88,12,19,-94,83,-8
            dw -56,-9,-72,-71,-7,-84,42,1,46,65,52,85,-84,-21,-36,2

cube_verts: dw -40,-40,-40
            dw  40,-40,-40
            dw  40, 40,-40
            dw -40, 40,-40
            dw -40,-40, 40
            dw  40,-40, 40
            dw  40, 40, 40
            dw -40, 40, 40
cube_edges: db 0,1, 1,2, 2,3, 3,0, 4,5, 5,6, 6,7, 7,4, 0,4, 1,5, 2,6, 3,7

; --- general-purpose line-draw state (Bresenham, used by scene_cube) ---
line_x0 dw 0
line_y0 dw 0
line_x1 dw 0
line_y1 dw 0
line_cx dw 0
line_cy dw 0
line_dx dw 0
line_dy dw 0
line_sx dw 0
line_sy dw 0
line_err dw 0
line_color db 0

align 16
stack_bottom: times 256 db 0      ; our own small stack, kept by the SETBLOCK
stack_top:

; ---- font 5x7 bitmap, CHARSET order, 8 bytes/glyph (8th row blank) ----
; charset: ' ABCDEFGHILMNOPRSTUVWXY256/,-'  (29 glyphs)
font_data:
    db 0,0,0,0,0,0,0,0,112,136,136,248,136,136,136,0,240,136,136,240
    db 136,136,240,0,120,128,128,128,128,128,120,0,240,136,136,136,136,136,240,0
    db 248,128,128,240,128,128,248,0,248,128,128,240,128,128,128,0,120,128,128,184
    db 136,136,120,0,136,136,136,248,136,136,136,0,248,32,32,32,32,32,248,0
    db 128,128,128,128,128,128,248,0,136,216,168,136,136,136,136,0,136,200,168,152
    db 136,136,136,0,112,136,136,136,136,136,112,0,240,136,136,240,128,128,128,0
    db 240,136,136,240,160,144,136,0,120,128,128,112,8,8,240,0,248,32,32,32
    db 32,32,32,0,136,136,136,136,136,136,112,0,136,136,136,136,136,80,32,0
    db 136,136,136,168,168,216,136,0,136,136,80,32,80,136,136,0,136,136,80,32
    db 32,32,32,0,112,136,8,16,32,64,248,0,248,128,240,8,8,136,112,0
    db 112,128,128,240,136,136,112,0,8,16,32,32,64,128,128,0,0,0,0,0
    db 32,32,64,0,0,0,0,248,0,0,0,0

; ---- scroller message, 155 glyph indices into font_data ----
scroll_msg:
    db 18,2,5,15,23,24,25,0,26,0,18,2,5,15,16,8,13,20,0,28
    db 0,1,0,6,18,10,10,22,0,14,15,13,3,5,4,18,15,1,10,0
    db 4,13,16,0,19,7,1,0,4,5,11,13,0,28,0,12,13,0,1,16
    db 16,5,17,16,27,0,12,13,0,5,21,3,18,16,5,16,0,28,0,16
    db 9,21,17,5,5,12,0,16,3,5,12,5,16,0,14,10,18,16,0,1
    db 0,15,13,17,1,17,9,12,7,0,3,18,2,5,0,28,0,3,13,4
    db 5,0,9,16,0,17,8,5,0,1,15,17,0,28,0,14,15,5,16,16
    db 0,5,16,3,0,17,13,0,5,21,9,17,0,28,0
SCROLL_MSG_LEN equ 155

; ---- sin table: 256 entries, sin(a)*63 as signed byte; cos(a) = sin((a+64)&255) ----
sintab:
    db 0,2,3,5,6,8,9,11,12,14,15,17,18,20,21,23,24,26,27,28
    db 30,31,32,34,35,36,38,39,40,41,42,43,45,46,47,48,49,50,51,52
    db 52,53,54,55,56,56,57,58,58,59,59,60,60,61,61,61,62,62,62,63
    db 63,63,63,63,63,63,63,63,63,63,62,62,62,61,61,61,60,60,59,59
    db 58,58,57,56,56,55,54,53,52,52,51,50,49,48,47,46,45,43,42,41
    db 40,39,38,36,35,34,32,31,30,28,27,26,24,23,21,20,18,17,15,14
    db 12,11,9,8,6,5,3,2,0,254,253,251,250,248,247,245,244,242,241,239
    db 238,236,235,233,232,230,229,228,226,225,224,222,221,220,218,217,216,215,214,213
    db 211,210,209,208,207,206,205,204,204,203,202,201,200,200,199,198,198,197,197,196
    db 196,195,195,195,194,194,194,193,193,193,193,193,193,193,193,193,193,193,194,194
    db 194,195,195,195,196,196,197,197,198,198,199,200,200,201,202,203,204,204,205,206
    db 207,208,209,210,211,213,214,215,216,217,218,220,221,222,224,225,226,228,229,230
    db 232,233,235,236,238,239,241,242,244,245,247,248,250,251,253,254
