# Low-level notes

## DOS COM execution

DOS loads a COM image at offset `0100h` of its program segment. `CS`, `DS`, `ES`, and `SS` initially describe the program's PSP environment, but this demo explicitly installs `ES` per frame before framebuffer stores — `A000h` or `B000h`, whichever of the two VGA pages is being rendered (see "Frame presentation"). `ORG 100h` tells NASM to calculate labels for that load convention; it does not emit a header.

## VGA framebuffer

Mode 13h is packed-pixel VGA: 320*200 = 64,000 byte pixels. `ES:DI` is therefore a natural streaming destination. `STOSB` writes AL to `ES:[DI]` and advances DI when the direction flag is clear. DOS normally enters applications with DF clear; production code that must tolerate arbitrary callers can issue `CLD`, at a one-byte size cost.

## Palette DAC

Writing zero to `3C8h` selects DAC entry zero. Subsequent writes to `3C9h` are consumed as R,G,B triplets and automatically advance the palette index. The generated palette intentionally uses modular six-bit ramps rather than storing 768 bytes of palette data.

## Retrace

Input Status Register 1 is available at `3DAh`; bit 3 reflects vertical retrace. The showcase first waits until outside retrace and then until retrace begins. This gives one unambiguous edge per rendered frame. It is synchronization, not a guarantee that rendering itself fits one refresh interval.

## Sizecoding trade-offs

A 256-byte intro optimizes encoded bytes rather than conventional software structure. Registers carry several meanings over their lifetime; arithmetic overflow is useful; tables and abstractions are expensive; direct hardware access replaces APIs. Such code is intentionally unlike maintainable application code.

## CPU baseline

The sources declare a 386+ target because the compact arithmetic uses later x86 instruction forms. They remain 16-bit real-mode programs; 386+ refers to the instruction set, not 32-bit protected mode.


## Frame presentation

The showcase does not blit. It double-buffers in real VGA memory and flips the
display with the CRTC, so a frame is presented by writing two port values rather
than by copying 64,000 bytes.

**The 128K window.** Mode 13h normally maps only 64K (`A0000h-AFFFFh`) into the
CPU aperture. Graphics Controller Miscellaneous Register (port `3CEh`, index 6,
written as read-modify-write) bits 3:2 are the Memory Map Select field; clearing
both selects `A0000h-BFFFFh`, so segments `A000h` *and* `B000h` both address real
VGA memory — two independent 64,000-byte pages. The code masks with `0F3h`, which
clears exactly those two bits and preserves Graphics Mode (bit 0) and Chain
Odd/Even (bit 1).

**The flip.** In mode 13h a scanline is 320 bytes, and the CRTC advances one
scanline per line by `2 x offset x memory-address-size`, with `offset`
(CRTC index `13h`) programmed to 40 and the address size 4 — i.e. 320 bytes per
line. The Start Address (CRTC indices `0Ch`/`0Dh`) counts 4-byte units, so page 1
— byte 65536 of the window — is start address `4000h`. The whole frame therefore
spans `65536 + 199 x 320 = 129216` bytes, comfortably inside the 128K window, which
is exactly why this works in planar mode where a 64000-byte page alone would not
have fit twice. Each frame renders entirely into whichever page is not currently
displayed (`vga_page`), then `present:` waits for retrace and writes the new start
address (`show_page`). Nothing is allocated from DOS, and there is no software
backbuffer or `REP MOVSW` copy anywhere in the program.

Caveat: the FreeVGA hardware notes report that some cards mirror the first 64K
twice across the 128K window rather than decoding a true second 64K. The demo has
no fallback for that case; on such hardware page 1 would alias page 0.

Timing: `wait_vsync` is called *before* the flip, so the CRTC update normally
lands inside vertical blank. It is not guaranteed to be tear-free on every
combination of CPU and card — `palette_tick`'s 768 DAC writes and `music_tick`'s
note step both sit between the retrace poll and the flip, and on a slow machine
that window outlasts vertical blank. The release therefore does not claim
universal tear-free output.

Scene changes use a palette-domain fade envelope. The renderer therefore pays no second full-frame blend pass: DAC output is clamped toward black for 32 frames before/after each 512-frame boundary while the procedural effect clock remains continuous.

## Register-lifetime audit

`main:` loads `ES` with the segment of the page being rendered once per frame, and
`DI` with zero. Individual effects may freely reuse AX/BX/CX/DX/SI because `STOSB`
addresses `ES:DI`; BX is not a persistent framebuffer pointer, and there is no
`DS` switch in the presentation path because the VGA aperture is addressed through
`ES` alone. Every field scene uses a 320 x 200 loop and therefore emits exactly
64,000 `STOSB` writes before overlays. BP is the frame clock: it is written only
by the single `inc bp` in `present:` and is preserved by every `PUSHA` routine
(`raster_line`'s per-line state, `scroll_draw`, `draw_line`,
`cube_rotate_project`), so no effect can desynchronise the clock.

## Presentation choreography

Version 5.0 combines two transition mechanisms. `palette_tick` performs the inexpensive DAC-domain fade, while `transition_wipe` covers symmetric top/bottom scanline regions (100 down to 55 lines) during the first and last 16 frames of each 512-frame scene. `scene_marker` renders eighteen tiny progress blocks directly into the page. `scroll_draw` runs last of the overlays, after `transition_wipe`, so the bottom scroller is never covered by the scene-cut shutter bars. All four overlays execute after the scene renderer and before the retrace/presentation path, so they cannot leave stale pixels between scenes.

## Scene sequencing

`cur_scene` is a 0..17 byte counter, incremented once per frame in `present:` and
wrapped at `SCENE_COUNT`, so the 18-scene sequence recurs exactly and `main:`
dispatches on a byte load instead of a divide. It is deliberately *not* derived as
`(frame >> SCENE_SHIFT) mod SCENE_COUNT`: the frame clock is 16-bit, so it yields
only 128 groups of 512 frames, and `128 mod 18` is not 0 — that form replayed
scenes 0 and 1 at the wrap and never recurred the intended cycle. Keeping one
shared counter also means `scene_marker` and `music_tick` can never disagree
about the show's position: both follow a single `inc byte [cur_scene]` in
`present:`, placed before `music_tick` steps the sequencer so an act's pitch
change lands on the frame before its first scene is drawn.

## Perspective projection (scene_cube)

Unlike the field scenes, `scene_cube` needs genuine 3D math. Two rotations (Y axis,
then X axis) are applied per vertex using one shared 256-entry sine table; cosine
is read from the same table at a 64-step (quarter-turn) offset rather than keeping
a second table. Each rotation stage is a standard 2D rotation matrix in fixed point:
multiply by the sine/cosine byte (range -63..63), sum, then `SAR` by 6 to undo the
implicit x64 scale. Products stay well within a signed 16-bit range throughout,
since a rotation can't increase a vector's magnitude beyond its original length.

Projection is a true perspective divide, not orthographic: `screen = centre +
(rotated * SCALE) / (depth + EYE_DIST)`, using `CWD`/`IDIV` for the signed 16-bit
division. `EYE_DIST=160` keeps the divisor comfortably positive (vertices stay
within roughly +-70 along any axis after rotation, so depth+160 never approaches
zero) regardless of the current rotation angle. Each vertex's post-rotation depth
is also cached (`proj_z`) so each of the 12 edges can pick a bright-vs-dim colour
from the average depth of its two endpoints, giving simple depth cueing without
implementing real hidden-line removal.

Edges are drawn with a from-scratch Bresenham line routine (the `dx+dy` err-term
variant), operating entirely through memory-resident state rather than registers,
since the routine has more live values (current x/y, both deltas, both step
signs, the error term) than the six general-purpose 16-bit registers can hold at
once without juggling. It bounds-checks every pixel before plotting, so an
out-of-range projected point can never corrupt memory outside the active VGA page
-- a deliberate defensive measure after the `scene_feedback` framebuffer-overrun
bug found during this project's audit. `e2 = 2*err` is computed once and reused
for both the x-step and y-step tests; recomputing it between the two (which an
earlier version did) can stop the walk from ever landing on the target pixel,
which is the only condition the loop tests to terminate.

## Starfield depth (scene_starfield)

Each of the 32 stars derives a Z depth every frame from `(frame*3 + index*37)`
divided by 240, giving a phase of 0..239 and therefore `Z = 255 - phase` — a true
16..255 ramp from near to far, recycling on its own with no per-star state. The
divisor and dividend are both 16-bit, and the frame-derived term reaches 65535, so
the quotient can actually reach 273: the accumulator is not a multiple of the
240-frame period, and 65535/240 = 273. The code therefore reduces the quotient
back into 0..239 with a compare and one conditional subtract (273 < 2*240, so one
pass always suffices).

This clamp is not cosmetic. Left out, the phase runs past 239, Z goes negative and
then reaches exactly zero, and the two `IDIV word [star_z]` projection divides
fault with `#DE` — no handler is installed, so the program dies. 291 frames per
65536-frame cycle contained a zero divisor; the first is frame 63709, i.e. 221
frames into a starfield scene. Note the same `IDIV`-by-unclamped-divisor hazard
that `cube_rotate_project` guards against by clamping depth to at least 40.

## Reserved DAC indices

`palette_tick`'s main loop animates all 256 DAC entries from one continuous
formula every frame, which looks good for the procedural fields but gives no
index a guaranteed-stable colour. Indices 1-7 are overridden immediately after
that loop runs, every frame, to fixed values: 1=black, 2=white, 3=dim grey, and
4-7 a small fixed rainbow. The text scroller and scene_cube's wireframe use only
these reserved indices, so they stay legible regardless of what the animated
palette is doing elsewhere. This was added after visually confirming in DOSBox
that the scroller/cube, when using plain animated indices, could lose contrast
whenever the animation happened to converge those indices to similar tones.
